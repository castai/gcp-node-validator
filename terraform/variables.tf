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

variable "cast_cluster_ids" {
  description = "List of CAST cluster IDs, for which nodes should be validated. If empty, all CAST nodes are validated."
  type        = list(string)
  default     = []
}

variable "alert_notification_channels" {
  description = <<EOF
The notification channels to send alerts for invalid instances.
It is a list of strings `projects/PROJECT_ID/notificationChannels/CHANNEL_ID`.
EOF
  type        = list(string)
  default     = []
}

variable "alert_severity" {
  description = "The severity of the alert"
  type        = string
  default     = "WARNING"
}

variable "delete_mode" {
  description = "Whether to delete invalid instances"
  type        = bool
  default     = false
}
