package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"slices"
	"strings"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/castai/gcp-node-validator/container/validate"
	"github.com/samber/lo"
	"github.com/sirupsen/logrus"
)

const (
	castClusterIDLabel = "cast-cluster-id"
	clusterNameLabel   = "goog-k8s-cluster-name"
)

type AuditLog struct {
	ProtoPayload struct {
		ServiceName  string `json:"serviceName"`
		MethodName   string `json:"methodName"`
		ResourceName string `json:"resourceName"`
	} `json:"protoPayload"`
	Resource struct {
		Type   string `json:"type"`
		Labels struct {
			ProjectID string `json:"project_id"`
		} `json:"labels"`
	} `json:"resource"`
}

type Handler struct {
	logger        logrus.FieldLogger
	projectID     string
	computeClient *compute.InstancesClient

	clusterIDs    []string
	deleteInvalid bool

	validator *validate.InstanceValidator
}

func NewHandler(projectID string, validator *validate.InstanceValidator, computeClient *compute.InstancesClient, clusterIDs []string, deleteInvalid bool) *Handler {
	return &Handler{
		logger:        logrus.New(),
		projectID:     projectID,
		computeClient: computeClient,
		clusterIDs:    clusterIDs,
		deleteInvalid: deleteInvalid,
		validator:     validator,
	}
}

func (h *Handler) HandleAuditLog(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var logEntry AuditLog

	payload, err := io.ReadAll(r.Body)
	if err != nil {
		h.logger.WithError(err).Errorf("failed to read request body")
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	h.logger.WithField("payload", string(payload)).Debug("received audit log")

	if err := json.Unmarshal(payload, &logEntry); err != nil {
		h.logger.WithError(err).Errorf("failed to unmarshal payload")
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	if logEntry.ProtoPayload.ServiceName != "compute.googleapis.com" || logEntry.ProtoPayload.MethodName != "v1.compute.instances.insert" {
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			h.logger.WithError(err).Errorf("failed to write response")
			return
		}
		return
	}

	log := h.logger.WithField("resourceName", logEntry.ProtoPayload.ResourceName)
	defer func() {
		log.Infof("request processed")
	}()

	instanceReq := getInstanceRequestFromResourceName(&logEntry)
	if instanceReq == nil {
		log.Errorf("failed to get instance request from resource name")
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	log.Infof("instance request: %+v", instanceReq)

	// GKE Autopilot are also present in the audit logs, but are not part of user project
	if instanceReq.Project != h.projectID {
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			log.WithError(err).Errorf("failed to write response")
			return
		}
		return
	}

	// GKE Autopilot nodes have gk3- prefix, so ignore them
	if strings.HasPrefix(instanceReq.Instance, "gk3-") {
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			log.WithError(err).Errorf("failed to write response")
			return
		}
		return
	}

	instance, err := h.computeClient.Get(ctx, instanceReq)
	if err != nil {
		log.WithError(err).Errorf("failed to get instance")
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			log.WithError(err).Errorf("failed to write response")
			return
		}
		return
	}

	if !h.considerInstance(instance, log) {
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write([]byte("OK")); err != nil {
			log.WithError(err).Errorf("failed to write response")
			return
		}
		return
	}

	valid := h.validateInstance(ctx, instance)

	if valid {
		log.Info("instance is valid")
	} else {
		log.Info("instance is invalid")
		if err := h.handleInvalidInstance(ctx, log, instanceReq.Project, instanceReq.Zone, instanceReq.Instance); err != nil {
			log.WithError(err).Errorf("failed to handle invalid instance")
			if _, err := w.Write([]byte("OK")); err != nil {
				log.WithError(err).Errorf("failed to write response")
				return
			}
		}
	}

	w.WriteHeader(http.StatusOK)
	if _, err := w.Write([]byte("OK")); err != nil {
		log.WithError(err).Errorf("failed to write response")
		return
	}
}

func (h *Handler) considerInstance(instance *computepb.Instance, log *logrus.Entry) bool {
	if _, found := instance.Labels["cast-managed-by"]; !found {
		log.Info("instance is not managed by CAST, skip instance")
		return false
	}

	if len(h.clusterIDs) > 0 {
		clusterID, found := instance.Labels[castClusterIDLabel]

		if !found {
			log.Info("missing CAST cluster id, skip instance")
			return false

		}

		if !slices.Contains(h.clusterIDs, clusterID) {
			log.Info("instance not part of monitored clusters, skip instance")
			return false
		}
	}

	return true
}

func (h *Handler) validateInstance(ctx context.Context, i *computepb.Instance) bool {
	if err := h.validator.Validate(ctx, i); err != nil {
		log := h.logger.WithError(err).WithFields(logrus.Fields{
			"instanceName":     lo.FromPtr(i.Name),
			"instanceSelfLink": lo.FromPtr(i.SelfLink),
			"clusterName":      i.Labels[clusterNameLabel],
			"castClusterID":    i.Labels[castClusterIDLabel],
		})

		valErr := &validate.ValidationError{}
		if errors.As(err, &valErr) {
			log.WithField("unknownCommands", valErr.UnknownCommands).Errorf("instance validation failed")
			return false
		}

		log.WithError(err).Errorf("failed to validate instance, skipping instance")
	}
	return true
}

func (h *Handler) handleInvalidInstance(ctx context.Context, log *logrus.Entry, project, zone, name string) error {
	if h.deleteInvalid {
		if err := h.deleteInstance(ctx, project, zone, name); err != nil {
			return fmt.Errorf("failed to delete instance: %w", err)
		}
		log.Info("instance deleted")
	}

	return nil
}

func (h *Handler) deleteInstance(ctx context.Context, project, zone, name string) error {
	req := &computepb.DeleteInstanceRequest{
		Project:  project,
		Zone:     zone,
		Instance: name,
	}

	_, err := h.computeClient.Delete(ctx, req)
	if err != nil {
		return err
	}

	return nil
}

func getInstanceRequestFromResourceName(log *AuditLog) *computepb.GetInstanceRequest {
	parts := strings.Split(log.ProtoPayload.ResourceName, "/")
	if len(parts) != 6 {
		return nil
	}
	project := log.Resource.Labels.ProjectID
	zone := parts[3]
	instanceName := parts[5]

	return &computepb.GetInstanceRequest{
		Project:  project,
		Zone:     zone,
		Instance: instanceName,
	}
}
