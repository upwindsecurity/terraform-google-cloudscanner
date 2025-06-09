# Basic Cloud Scanner Example

This example demonstrates a basic deployment of the Upwind Cloud Scanner module with minimal configuration.

## Features

- Single Cloud Scanner instance group
- Default VPC network configuration
- Standard machine type and disk configuration
- IAP SSH access enabled
- Automatic scaling disabled (fixed size: 1)

## Usage

1. Set your required variables:

```bash
export TF_VAR_upwind_organization_id="org_your_org_id"
export TF_VAR_scanner_id="ucsc-your-scanner-id"
export TF_VAR_cloudscanner_sa_email="cloudscanner-sa@your-project.iam.gserviceaccount.com"
export TF_VAR_cloudscanner_scaler_sa_email="cloudscanner-scaler-sa@your-project.iam.gserviceaccount.com"
export TF_VAR_upwind_orchestrator_project="your-google-cloud-project-id"
```

1. Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

## Requirements

- Service accounts must be pre-created with appropriate permissions
- Secret Manager secrets must contain the scanner credentials
- Required IAM roles must be created for the service accounts

## Resources Created

- Cloud Scanner instance group manager (1 instance)
- Instance templates with blue/green deployment support
- Cloud Run scaler function
- Cloud Scheduler job for periodic scaling
- Default VPC network and subnet (if custom network not specified)
- Cloud NAT for outbound internet access

This configuration is suitable for development and testing environments.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloudscanner_basic"></a> [cloudscanner\_basic](#module\_cloudscanner\_basic) | ../../modules/main | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudscanner_sa_email"></a> [cloudscanner\_sa\_email](#input\_cloudscanner\_sa\_email) | The cloudscanner service account email to use | `string` | n/a | yes |
| <a name="input_cloudscanner_scaler_sa_email"></a> [cloudscanner\_scaler\_sa\_email](#input\_cloudscanner\_scaler\_sa\_email) | The cloudscanner scaler service account email to use | `string` | n/a | yes |
| <a name="input_scanner_id"></a> [scanner\_id](#input\_scanner\_id) | The Upwind Scanner ID | `string` | n/a | yes |
| <a name="input_upwind_orchestrator_project"></a> [upwind\_orchestrator\_project](#input\_upwind\_orchestrator\_project) | The main Google Cloud project where the resources are created | `string` | n/a | yes |
| <a name="input_upwind_organization_id"></a> [upwind\_organization\_id](#input\_upwind\_organization\_id) | The Upwind Organization ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudscanner_asg_name"></a> [cloudscanner\_asg\_name](#output\_cloudscanner\_asg\_name) | The name of the Cloud Scanner Auto Scaling Group |
<!-- END_TF_DOCS -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloudscanner_basic"></a> [cloudscanner\_basic](#module\_cloudscanner\_basic) | ../../modules/main | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudscanner_sa_email"></a> [cloudscanner\_sa\_email](#input\_cloudscanner\_sa\_email) | The cloudscanner service account email to use | `string` | n/a | yes |
| <a name="input_cloudscanner_scaler_sa_email"></a> [cloudscanner\_scaler\_sa\_email](#input\_cloudscanner\_scaler\_sa\_email) | The cloudscanner scaler service account email to use | `string` | n/a | yes |
| <a name="input_scanner_id"></a> [scanner\_id](#input\_scanner\_id) | The Upwind Scanner ID | `string` | n/a | yes |
| <a name="input_upwind_orchestrator_project"></a> [upwind\_orchestrator\_project](#input\_upwind\_orchestrator\_project) | The main Google Cloud project where the resources are created | `string` | n/a | yes |
| <a name="input_upwind_organization_id"></a> [upwind\_organization\_id](#input\_upwind\_organization\_id) | The Upwind Organization ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudscanner_asg_name"></a> [cloudscanner\_asg\_name](#output\_cloudscanner\_asg\_name) | The name of the Cloud Scanner Auto Scaling Group |
<!-- END_TF_DOCS -->
