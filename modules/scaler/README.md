# Upwind Cloud Scanner Scaler Module for Google Cloud

This Terraform module deploys the Upwind Cloud Scanner scaler for one Google Cloud project. Apply it once per
project, alongside `modules/main` (with `create_scaler = false`) for each region that has a scanner: one scaler scales every scanner in the project.

The module creates:

- Cloud Run job that scales every Cloud Scanner instance group in the project
- Cloud Scheduler job that runs it periodically
- VPC network and subnet for the job's egress (optional)
- IAM bindings for the scaler service account on the job and the scanner secrets (optional)

## Usage

```hcl
module "cloudscanner_scaler" {
  source = "../../modules/scaler"

  project               = "my-orchestrator-project"
  name                  = "upwind-scaler-abcde"
  service_account_email = "upwind-scaler-abcde@my-orchestrator-project.iam.gserviceaccount.com"
  client_id_secret      = "upwind-scanner-client-id-abcde"
  client_secret_secret  = "upwind-scanner-client-secret-abcde"
  access_token          = var.access_token
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.23.0, < 8.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.23.0, < 8.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloud_run_v2_job.scaler](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_job) | resource |
| [google_cloud_run_v2_job_iam_member.invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_job_iam_member) | resource |
| [google_cloud_scheduler_job.scaler](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_scheduler_job) | resource |
| [google_compute_network.scaler](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.scaler](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_secret_manager_secret_iam_member.accessor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_token"></a> [access\_token](#input\_access\_token) | The access token used to authenticate with Google Cloud. | `string` | n/a | yes |
| <a name="input_client_id_secret"></a> [client\_id\_secret](#input\_client\_id\_secret) | Secret Manager secret id, in var.project, holding the scanner client id. | `string` | n/a | yes |
| <a name="input_client_secret_secret"></a> [client\_secret\_secret](#input\_client\_secret\_secret) | Secret Manager secret id, in var.project, holding the scanner client secret. | `string` | n/a | yes |
| <a name="input_default_labels"></a> [default\_labels](#input\_default\_labels) | Default labels applied to all resources (can be overridden) | `map(string)` | <pre>{<br/>  "component": "upwind",<br/>  "managed_by": "terraform"<br/>}</pre> | no |
| <a name="input_grant_invoker"></a> [grant\_invoker](#input\_grant\_invoker) | Grant the scaler service account roles/run.invoker on the scaler job, so Cloud Scheduler can start it. Leave false where the service account already has it. | `bool` | `false` | no |
| <a name="input_grant_secret_access"></a> [grant\_secret\_access](#input\_grant\_secret\_access) | Grant the scaler service account roles/secretmanager.secretAccessor on the two scanner secrets. Leave false where the service account already has it. | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | A map of labels to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the scaler Cloud Run job. The Scheduler job is named <name>-scheduler. | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | The project the scaler runs in. It scales every scanner config in this project. | `string` | n/a | yes |
| <a name="input_public_uri_domain"></a> [public\_uri\_domain](#input\_public\_uri\_domain) | The public URI domain. | `string` | `"upwind.io"` | no |
| <a name="input_region"></a> [region](#input\_region) | The region for the scaler job and its Scheduler job. | `string` | `"us-central1"` | no |
| <a name="input_scaler_vpc_egress_enabled"></a> [scaler\_vpc\_egress\_enabled](#input\_scaler\_vpc\_egress\_enabled) | Attach the scaler to its own small VPC with Direct VPC egress for private ranges only. Only needed where a GCP org policy (constraints/run.allowedVPCEgress) requires Cloud Run resources to declare an egress setting: it delays the scaler's startup and holds addresses in the subnet for hours after the scaler is deleted, blocking network teardown. | `bool` | `false` | no |
| <a name="input_scanner_secret_version"></a> [scanner\_secret\_version](#input\_scanner\_secret\_version) | Secret Manager version for the scanner client id/secret mounted into the scaler job. Defaults to "latest", so a rotated credential is picked up on the next job execution with no apply. Set to a specific numeric version (e.g. "3") only to deliberately pin. | `string` | `"latest"` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | The service account the scaler runs as, and that Cloud Scheduler uses to start it. | `string` | n/a | yes |
| <a name="input_upwind_infra_region"></a> [upwind\_infra\_region](#input\_upwind\_infra\_region) | The Upwind infrastructure region where the resources are created. | `string` | `"us"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
