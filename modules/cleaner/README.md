# Upwind Cloud Scanner Cleaner Module for Google Cloud

This Terraform module deploys the Upwind GCP SaaS cleaner for one scanner project. It deletes the scan disks GCP SaaS
scans leave behind in the project, and the snapshots they leave in the customer's projects. Apply it once per scanner
project, alongside `modules/scaler`, running as the same service account with the same Upwind client secrets.

The module creates:

- Cloud Run job that runs the cleaner
- Cloud Scheduler job that runs it hourly
- IAM binding for the service account on the job (optional)

## Usage

```hcl
module "cloudscanner_cleaner" {
  source = "../../modules/cleaner"

  project               = "my-scanner-project"
  name                  = "upwind-cleaner-abcde"
  service_account_email = "upwind-abcde@my-hub-project.iam.gserviceaccount.com"
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
| [google_cloud_run_v2_job.cleaner](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_job) | resource |
| [google_cloud_run_v2_job_iam_member.invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_job_iam_member) | resource |
| [google_cloud_scheduler_job.cleaner](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_scheduler_job) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_token"></a> [access\_token](#input\_access\_token) | An OAuth access token to authenticate with Google Cloud. Leave unset to use the provider's ambient credentials (Application Default Credentials, e.g. from `gcloud auth application-default login` or a CI workload identity). | `string` | `null` | no |
| <a name="input_client_id_secret"></a> [client\_id\_secret](#input\_client\_id\_secret) | Secret Manager secret id, in var.project, holding the Upwind client id. | `string` | n/a | yes |
| <a name="input_client_secret_secret"></a> [client\_secret\_secret](#input\_client\_secret\_secret) | Secret Manager secret id, in var.project, holding the Upwind client secret. | `string` | n/a | yes |
| <a name="input_default_labels"></a> [default\_labels](#input\_default\_labels) | Default labels applied to all resources (can be overridden) | `map(string)` | <pre>{<br/>  "component": "upwind",<br/>  "managed_by": "terraform"<br/>}</pre> | no |
| <a name="input_dry_run"></a> [dry\_run](#input\_dry\_run) | Report what would be deleted and delete nothing. | `bool` | `false` | no |
| <a name="input_grant_invoker"></a> [grant\_invoker](#input\_grant\_invoker) | Grant the service account roles/run.invoker on the cleaner job, so Cloud Scheduler can start it. Leave false where the service account already has it. | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | A map of labels to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the cleaner Cloud Run job. The Scheduler job is named <name>-scheduler. | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | The scanner project the cleaner runs in and cleans. | `string` | n/a | yes |
| <a name="input_public_uri_domain"></a> [public\_uri\_domain](#input\_public\_uri\_domain) | The public URI domain. | `string` | `"upwind.io"` | no |
| <a name="input_region"></a> [region](#input\_region) | The region for the cleaner job and its Scheduler job. | `string` | `"us-central1"` | no |
| <a name="input_secret_version"></a> [secret\_version](#input\_secret\_version) | Secret Manager version for the client id/secret. Defaults to "latest", so a rotated credential is picked up on the next run with no apply. | `string` | `"latest"` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | The service account the cleaner runs as, and that Cloud Scheduler uses to start it: the customer's hub account. | `string` | n/a | yes |
| <a name="input_upwind_infra_region"></a> [upwind\_infra\_region](#input\_upwind\_infra\_region) | The Upwind infrastructure region the cleaner reports to. | `string` | `"us"` | no |
| <a name="input_vpc_egress"></a> [vpc\_egress](#input\_vpc\_egress) | Network and subnetwork ids for Direct VPC egress (private ranges only), where a GCP org policy (constraints/run.allowedVPCEgress) requires Cloud Run resources to declare an egress setting. Null for no VPC egress. | <pre>object({<br/>    network    = string<br/>    subnetwork = string<br/>  })</pre> | `null` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
