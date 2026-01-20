module "cloudscanner_basic" {
  source = "../../modules/main"

  # Required Upwind variables
  upwind_organization_id = var.upwind_organization_id
  scanner_id             = var.scanner_id

  # Required Google Cloud variables
  access_token                 = var.access_token
  cloudscanner_sa_email        = var.cloudscanner_sa_email
  cloudscanner_scaler_sa_email = var.cloudscanner_scaler_sa_email
  upwind_orchestrator_project  = var.upwind_orchestrator_project

  # Optional configuration - using defaults for basic setup
  region             = "us-central1"
  availability_zones = ["us-central1-a", "us-central1-b", "us-central1-c"]
  machine_type       = "e2-highmem-2"
  target_size        = 1

  # Basic networking - will create default VPC
  enable_iap_ssh = true
}
