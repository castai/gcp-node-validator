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

resource "google_storage_bucket" "main" {
  name                     = "${var.name_prefix}-vm-validator"
  location                 = "US"
  force_destroy            = true
  public_access_prevention = "enforced"
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

resource "google_project_iam_member" "artifactregistry_reader" {
  project = data.google_project.project.id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.main.email}"
}

resource "google_project_iam_custom_role" "instance_validator" {
  role_id     = "${var.name_prefix}CastInstanceValidator"
  title       = "CAST AI Instance Validator"
  description = "Custom role to validate CAST AI instances"
  permissions = compact([
    "compute.instances.get",
    "compute.instanceGroupManagers.get",
    "compute.instanceTemplates.get",
    "container.clusters.get",
    "storage.objects.list",
    "storage.objects.get",
    var.delete_mode ? "compute.instances.delete" : null,
  ])
}

# Grant permission to act on Compute Engine resources
resource "google_project_iam_member" "instance_validator" {
  project = data.google_project.project.id
  role    = google_project_iam_custom_role.instance_validator.id
  member  = "serviceAccount:${google_service_account.main.email}"
}

# Deploy Cloud Run service
resource "google_cloud_run_v2_service" "default" {
  name     = "${var.name_prefix}-vm-validator"
  location = var.region

  deletion_protection = false

  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    containers {
      image = var.validator_image
      env {
        name  = "APP_PROJECTID"
        value = data.google_project.project.project_id
      }
      env {
        name  = "APP_WHITELISTBUCKET_NAME"
        value = google_storage_bucket.main.name
      }
      env {
        name  = "APP_DELETEINVALID"
        value = tostring(var.delete_mode)
      }
      env {
        name  = "APP_CLUSTERIDS"
        value = join(",", var.cast_cluster_ids)
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

resource "google_logging_metric" "invalid_instances" {
  name        = "${var.name_prefix}-invalid-instances"
  description = "Count of instances that failed metadata script validation"
  filter      = <<EOF
resource.type = cloud_run_revision
  AND resource.labels.service_name = ${google_cloud_run_v2_service.default.name}
  AND "instance is invalid"
EOF

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_logging_metric" "valid_instances" {
  name        = "${var.name_prefix}-valid-instances"
  description = "Count of instances that succeeded metadata script validation"
  filter      = <<EOF
resource.type = cloud_run_revision
  AND resource.labels.service_name = ${google_cloud_run_v2_service.default.name}
  AND "instance is valid"
EOF

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "invalid_instances" {
  display_name = "Invalid CAST Instance Alert Policy"
  combiner     = "OR"

  severity              = var.alert_severity
  notification_channels = var.alert_notification_channels

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }

  conditions {
    display_name = "Invalid instance log"
    condition_matched_log {
      filter = <<EOF
resource.type = cloud_run_revision
  AND resource.labels.service_name = ${google_cloud_run_v2_service.default.name}
  AND "instance is invalid"
EOF
    }
  }
}

