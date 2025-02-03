variable "project" {
  description = "The project ID to deploy resources to"
}

variable "region" {
  description = "The region to deploy resources to"
}

variable "name_prefix" {
  description = "A prefix to add to resource names"
}

variable "validator_image" {
  description = "The image to use for the validator Cloud Run service"
}

terraform {
  required_providers {
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

data "google_project" "project" {
}

resource "google_service_account" "main" {
  account_id = "${var.name_prefix}-vm-validator-sa"
}

# Grant permission to receive Eventarc events
resource "google_project_iam_member" "eventreceiver" {
  project = data.google_project.project.id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.main.email}"
}

# Grant permission to invoke Cloud Run services
resource "google_project_iam_member" "runinvoker" {
  project = data.google_project.project.id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.main.email}"
}

# Grant permission to act on Compute Engine resources
resource "google_project_iam_member" "compute_admin" {
  project = data.google_project.project.id
  # TODO: user custom role with get and delete instance permissions
  role   = "roles/compute.admin"
  member = "serviceAccount:${google_service_account.main.email}"
}

# Deploy Cloud Run service
resource "google_cloud_run_v2_service" "default" {
  name     = "${var.name_prefix}-vm-validator"
  location = var.region

  deletion_protection = false

  template {
    containers {
      image = var.validator_image
      env {
        name  = "PROJECT_ID"
        value = data.google_project.project.project_id
      }
    }
    service_account = google_service_account.main.email
  }
}


resource "google_eventarc_trigger" "instance_insert" {
  name     = "${var.name_prefix}-instance-insert"
  location = "global"

  # Capture created VM instances
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.audit.log.v1.written"
  }

  matching_criteria {
    attribute = "serviceName"
    value     = "compute.googleapis.com"
  }

  matching_criteria {
    attribute = "methodName"
    value     = "v1.compute.instances.insert"
  }

  # Send events to Cloud Run
  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.default.name
      region  = google_cloud_run_v2_service.default.location
    }
  }

  service_account = google_service_account.main.email
}

