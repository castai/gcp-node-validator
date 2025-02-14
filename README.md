# GCP Instance Metadata Validator

## Overview

This project validates metadata of CAST Google Compute Instances to ensure they only contain approved (whitelisted) scripts in the user-data.
It is deployed as a CloudRun container and uses EventArc events to trigger the validation process.
The validator checks the user-data against a whitelist stored in a GCS bucket.
When an instance contains invalid metadata, the system logs an event which can be monitored using a log-based metric and alerts.

The whitelisted scripts are taken from:

- GKE Nodepool Instance Template - this whitelists the scripts provided by GKE to bootstrap the node,
- GCS Bucket - this allows users to add custom scripts to the whitelist.

## Deployment

The application can be deployed using the Terraform module in the [`terraform`](./terraform/) directory.

You can use this module in your Terraform configuration by adding the following module block:

```hcl
module "validator" {
  source = "github.com/castai/gcp-node-validator/terraform"

  name_prefix     = "my-validator"
  validator_image = "ghcr.io/castai/node-validator:v0.1.0-8-gdc83ed3"
  project         = "<gcp-project>"
  region          = "<gcp-region>"
}
```

Refer to the [module documentation](./terraform/README.md) for more information and configuration options.

The module will create a GCS bucket, where you must put whitelisted scripts.

## CAST AI scripts

CAST AI requires additional scripts to be ran during node bootstrapping. These scripts are provided in this repository
in the [`castai-whitelist`](./castai-whitelist/) directory.

You need to upload these scripts to the GCS bucket created by the Terraform module.

