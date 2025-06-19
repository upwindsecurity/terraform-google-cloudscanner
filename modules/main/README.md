# Upwind Cloud Scanner Module for Google Cloud

This Terraform module deploys the Upwind Cloud Scanner infrastructure on Google Cloud. The Cloud Scanner
provides comprehensive security scanning and monitoring capabilities for your Google Cloud resources.

The module creates:

- Auto-scaling compute instances for Cloud Scanner workloads
- Cloud Run job for automatic scaling management
- Cloud Scheduler for periodic scaling operations
- VPC network infrastructure (optional)
- IAM roles and service account bindings
- Secret Manager integration for credentials

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.23.0, <= 6.35.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.35.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloud_run_v2_job.scaler_function](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_job) | resource |
| [google_cloud_scheduler_job.scaler_scheduler_job](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_scheduler_job) | resource |
| [google_compute_firewall.cloudscanner_fw_iap_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network.cloudscanner_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_region_instance_group_manager.cloudscanner](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_compute_region_instance_template.cloudscanner_inst_templates](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_template) | resource |
| [google_compute_router.cloudscanner_router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.cloudscanner_router_nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.cloudscanner_subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_project_iam_member.cloudscanner_instance_template_mgmt_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudscanner_instance_template_test_creation_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudscanner_storage_delete_role_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudscanner_snapshot_reader_role_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudscanner_snapshot_writer_role_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [null_resource.always_run](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [google_compute_network.custom_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.custom_subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_secret_manager_secret.scanner_client_id](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret) | data source |
| [google_secret_manager_secret.scanner_client_secret](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret) | data source |
| [google_secret_manager_secret_version.scanner_client_id_v1](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |
| [google_secret_manager_secret_version.scanner_client_secret_v1](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |
| [google_service_account.cloudscanner_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account) | data source |
| [google_service_account.cloudscanner_scaler_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_token"></a> [access\_token](#input\_access\_token) | The access token used to authenticate with Google Cloud. | `string` | | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | The zones within the region that will be used for zone based resources. | `list(any)` | <pre>[<br/>  "us-central1-a",<br/>  "us-central1-b",<br/>  "us-central1-c"<br/>]</pre> | no |
| <a name="input_boot_disk_size_gb"></a> [boot\_disk\_size\_gb](#input\_boot\_disk\_size\_gb) | The disk size in GB to use. | `number` | `20` | no |
| <a name="input_boot_disk_type"></a> [boot\_disk\_type](#input\_boot\_disk\_type) | The disk type to use. | `string` | `"pd-standard"` | no |
| <a name="input_boot_image"></a> [boot\_image](#input\_boot\_image) | The source image to use for instances. | `string` | `"ubuntu-os-cloud/ubuntu-2404-lts-amd64"` | no |
| <a name="input_cloudscanner_sa_email"></a> [cloudscanner\_sa\_email](#input\_cloudscanner\_sa\_email) | The cloudscanner service account email to use. | `string` | n/a | yes |
| <a name="input_cloudscanner_scaler_sa_email"></a> [cloudscanner\_scaler\_sa\_email](#input\_cloudscanner\_scaler\_sa\_email) | The cloudscanner scaler service account email to use. | `string` | n/a | yes |
| <a name="input_custom_network"></a> [custom\_network](#input\_custom\_network) | The name of a custom network to use. | `string` | `""` | no |
| <a name="input_custom_subnet"></a> [custom\_subnet](#input\_custom\_subnet) | The name of a custom subnetwork to use. | `string` | `""` | no |
| <a name="input_enable_iap_ssh"></a> [enable\_iap\_ssh](#input\_enable\_iap\_ssh) | Whether to enable SSH access via IAP | `bool` | `true` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type to use. | `string` | `"e2-highmem-2"` | no |
| <a name="input_min_nat_ports_per_vm"></a> [min\_nat\_ports\_per\_vm](#input\_min\_nat\_ports\_per\_vm) | Minimum number of ports allocated to each VM for NAT service | `number` | `64` | no |
| <a name="input_public_uri_domain"></a> [public\_uri\_domain](#input\_public\_uri\_domain) | The public URI domain. | `string` | `"upwind.io"` | no |
| <a name="input_region"></a> [region](#input\_region) | The region that all resources will be created in. | `string` | `"us-central1"` | no |
| <a name="input_scaler_function_schedule"></a> [scaler\_function\_schedule](#input\_scaler\_function\_schedule) | The schedule to use for the scaler function. | `string` | `"*/10 * * * *"` | no |
| <a name="input_scanner_id"></a> [scanner\_id](#input\_scanner\_id) | The Upwind Scanner ID. | `string` | n/a | yes |
| <a name="input_target_size"></a> [target\_size](#input\_target\_size) | The target size of the autoscaling group. | `number` | `1` | no |
| <a name="input_upwind_orchestrator_project"></a> [upwind\_orchestrator\_project](#input\_upwind\_orchestrator\_project) | The main Google Cloud project where the resources are created. | `string` | n/a | yes |
| <a name="input_upwind_organization_id"></a> [upwind\_organization\_id](#input\_upwind\_organization\_id) | The Upwind Organization ID. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gcp_asg_name"></a> [gcp\_asg\_name](#output\_gcp\_asg\_name) | The name of the Cloud Scanner Instance Manager Group. |
<!-- END_TF_DOCS -->
