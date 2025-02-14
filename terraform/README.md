## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.18.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloud_run_v2_service.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_eventarc_trigger.instance_insert](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/eventarc_trigger) | resource |
| [google_logging_metric.invalid_instances](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_metric) | resource |
| [google_logging_metric.valid_instances](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_metric) | resource |
| [google_monitoring_alert_policy.invalid_instances](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_project_iam_custom_role.instance_validator](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_member.eventreceiver](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.instance_validator](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.runinvoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_storage_bucket.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alert_notification_channels"></a> [alert\_notification\_channels](#input\_alert\_notification\_channels) | The notification channels to send alerts for invalid instances.<br/>It is a list of strings `projects/PROJECT_ID/notificationChannels/CHANNEL_ID`. | `list(string)` | `[]` | no |
| <a name="input_alert_severity"></a> [alert\_severity](#input\_alert\_severity) | The severity of the alert | `string` | `"WARNING"` | no |
| <a name="input_delete_mode"></a> [delete\_mode](#input\_delete\_mode) | Whether to delete invalid instances. | `bool` | `false` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | A prefix to add to resource names | `any` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | The project ID to deploy resources to | `any` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region to deploy resources to | `any` | n/a | yes |
| <a name="input_validator_image"></a> [validator\_image](#input\_validator\_image) | The image to use for the validator Cloud Run service | `any` | n/a | yes |

## Outputs

No outputs.
