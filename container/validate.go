package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	compute "cloud.google.com/go/compute/apiv1"
	computepb "cloud.google.com/go/compute/apiv1/computepb"
)

type Handler struct {
	computeClient *compute.InstancesClient
}

type AuditLog struct {
	ProtoPayload struct {
		ServiceName  string `json:"serviceName"`
		MethodName   string `json:"methodName"`
		ResourceName string `json:"resourceName"`
	} `json:"protoPayload"`
}

// TODO: Implement instance validation logic
func (h *Handler) validateInstance(compute *computepb.Instance) bool {
	fmt.Printf("%+v\n", compute)
	return true
}

func (h *Handler) handleAuditLog(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var logEntry AuditLog
	if err := json.NewDecoder(r.Body).Decode(&logEntry); err != nil {
		log.Printf("Failed to decode request: %v", err)
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	if logEntry.ProtoPayload.ServiceName == "compute.googleapis.com" && logEntry.ProtoPayload.MethodName == "v1.compute.instances.insert" {
		instanceReq := getInstanceRequestFromResourceName(logEntry.ProtoPayload.ResourceName)
		if instanceReq == nil {
			log.Printf("Failed to get instance details from resource name: %s", logEntry.ProtoPayload.ResourceName)
			http.Error(w, "Invalid request", http.StatusBadRequest)
			return
		}

		instance, err := h.computeClient.Get(ctx, instanceReq)
		if err != nil {
			log.Printf("Failed to get instance: %v", err)
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
	}

	w.WriteHeader(http.StatusOK)
	if _, err := w.Write([]byte("OK")); err != nil {
		log.Printf("Failed to write response: %v", err)
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
	computeClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatalf("failed to create compute client: %v", err)
	}

	handler := &Handler{
		computeClient: computeClient,
	}

	http.HandleFunc("/", handler.handleAuditLog)
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
