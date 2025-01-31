package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	compute "cloud.google.com/go/compute/apiv1"
	computepb "cloud.google.com/go/compute/apiv1/computepb"
	"github.com/cenkalti/backoff/v5"
	"github.com/sirupsen/logrus"
)

type Handler struct {
	logger        logrus.FieldLogger
	projectID     string
	computeClient *compute.InstancesClient
}

type AuditLog struct {
	ProtoPayload struct {
		ServiceName  string `json:"serviceName"`
		MethodName   string `json:"methodName"`
		ResourceName string `json:"resourceName"`
	} `json:"protoPayload"`
	Resource struct {
		Type string `json:"type"`
	} `json:"resource"`
}

// TODO: Implement instance validation logic
func (h *Handler) validateInstance(compute *computepb.Instance) bool {
	fmt.Printf("%+v\n", compute)
	return true
}

func (h *Handler) handleAuditLog(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var logEntry AuditLog

	payload, err := io.ReadAll(r.Body)
	if err != nil {
		h.logger.WithError(err).Errorf("failed to read request body")
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	fmt.Printf("Payload: %s\n", string(payload))

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

	instanceReq := getInstanceRequestFromResourceName(logEntry.ProtoPayload.ResourceName)
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

	instance, err := backoff.Retry(ctx, func() (*computepb.Instance, error) {
		return h.computeClient.Get(ctx, instanceReq)
	}, backoff.WithBackOff(backoff.NewConstantBackOff(4*time.Second)), backoff.WithMaxElapsedTime(60*time.Second))
	if err != nil {
		log.WithError(err).Errorf("failed to get instance")
		http.Error(w, "Failed to get instance", http.StatusInternalServerError)
		return
	}

	valid := h.validateInstance(instance)

	if valid {
		log.Printf("Instance %s is valid", *instance.Name)
	} else {
		log.Printf("Instance %s is invalid", *instance.Name)
		//if err := deleteInstance(instanceName, project, zone); err != nil {
		//	log.Printf("Failed to delete instance: %v", err)
		//	http.Error(w, "Failed to delete instance", http.StatusInternalServerError)
		//	return
		//}
	}

	w.WriteHeader(http.StatusOK)
	if _, err := w.Write([]byte("OK")); err != nil {
		log.WithError(err).Errorf("failed to write response")
		return
	}
}

func getInstanceRequestFromResourceName(resourceName string) *computepb.GetInstanceRequest {
	parts := strings.Split(resourceName, "/")
	if len(parts) != 6 {
		return nil
	}
	project := parts[1]
	zone := parts[3]
	instanceName := parts[5]

	return &computepb.GetInstanceRequest{
		Project:  project,
		Zone:     zone,
		Instance: instanceName,
	}
}

func main() {
	ctx := context.Background()
	log := logrus.New()

	computeClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatalf("failed to create compute client: %v", err)
	}

	handler := &Handler{
		logger:        log,
		computeClient: computeClient,
		projectID:     os.Getenv("PROJECT_ID"),
	}

	http.HandleFunc("/", handler.handleAuditLog)
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
