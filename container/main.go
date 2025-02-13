package main

import (
	"context"
	"fmt"
	"net/http"

	compute "cloud.google.com/go/compute/apiv1"
	container "cloud.google.com/go/container/apiv1"
	"cloud.google.com/go/storage"
	"github.com/castai/gcp-node-validator/container/api"
	"github.com/castai/gcp-node-validator/container/validate"
	"github.com/kelseyhightower/envconfig"
	"github.com/sirupsen/logrus"
)

type Config struct {
	LogLevel      string `default:"info"`
	ProjectID     string `required:"true"`
	DeleteInvalid bool   `default:"false"`
	Port          int    `default:"8080"`

	ClusterIDs      []string `required:"false"`
	WhitelistBucket string   `required:"true"`
}

func main() {
	ctx := context.Background()
	log := logrus.New()

	cfg := &Config{}

	if err := envconfig.Process("APP", cfg); err != nil {
		log.WithError(err).Fatal("failed to process config")
	}

	logLevel, err := logrus.ParseLevel(cfg.LogLevel)
	if err != nil {
		log.Warnf("invalid log level %s, defaulting to info", cfg.LogLevel)
		logLevel = logrus.InfoLevel
	}
	log.SetLevel(logLevel)

	computeClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatalf("failed to create compute client: %v", err)
	}
	defer computeClient.Close()

	clusterManagerClient, err := container.NewClusterManagerRESTClient(ctx)
	if err != nil {
		log.Fatalf("failed to create cluster manager client: %v", err)
	}
	defer clusterManagerClient.Close()

	instanceGroupManagersClient, err := compute.NewInstanceGroupManagersRESTClient(ctx)
	if err != nil {
		log.Fatalf("failed to create instance group managers client: %v", err)
	}
	defer instanceGroupManagersClient.Close()

	instanceTemplateClient, err := compute.NewRegionInstanceTemplatesRESTClient(ctx)
	if err != nil {
		log.Fatalf("failed to create instance templates client: %v", err)
	}
	defer instanceTemplateClient.Close()

	cloudStorageClient, err := storage.NewClient(context.Background())
	if err != nil {
		log.Fatalf("failed to create cloud storage client: %v", err)
	}
	defer cloudStorageClient.Close()

	instanceTemplateWhitelistProvider, err := validate.NewInstanceTemplateWhitelistProvider(
		clusterManagerClient,
		instanceGroupManagersClient,
		instanceTemplateClient,
	)
	if err != nil {
		log.Fatalf("failed to create instance template whitelist provider: %v", err)
	}

	gcsWhitelistProvider, err := validate.NewCloudStorageWhitelistGetter(cfg.WhitelistBucket, cloudStorageClient)
	if err != nil {
		log.Fatalf("failed to create cloud storage whitelist provider: %v", err)
	}

	handler := api.NewHandler(
		cfg.ProjectID,
		validate.NewInstanceValidator(instanceTemplateWhitelistProvider, gcsWhitelistProvider),
		computeClient,
		cfg.ClusterIDs,
		cfg.DeleteInvalid,
	)

	http.HandleFunc("/", handler.HandleAuditLog)
	log.WithField("port", cfg.Port).Infof("listening for requests")
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", cfg.Port), nil))
}
