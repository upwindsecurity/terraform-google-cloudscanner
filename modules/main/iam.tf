data "google_service_account" "cloudscanner_sa" {
  account_id = var.cloudscanner_sa_email
}

data "google_service_account" "cloudscanner_scaler_sa" {
  account_id = var.cloudscanner_scaler_sa_email
}

data "google_project" "scanner" {
  count      = local.grant_subnet_network_user ? 1 : 0
  project_id = local.project
}

# A Shared VPC subnet lives in the host project, so the scanner project's agents
# need networkUser on it to create the VMs (and the scaler's Direct VPC egress) there.
resource "google_compute_subnetwork_iam_member" "cloudscanner_network_user" {
  count      = local.grant_subnet_network_user ? 1 : 0
  project    = local.network_project
  region     = var.region
  subnetwork = var.custom_subnet
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${data.google_project.scanner[0].number}@cloudservices.gserviceaccount.com"
}

resource "google_compute_subnetwork_iam_member" "scaler_network_user" {
  count      = local.grant_subnet_network_user && var.scaler_vpc_egress_enabled ? 1 : 0
  project    = local.network_project
  region     = var.region
  subnetwork = var.custom_subnet
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.scanner[0].number}@serverless-robot-prod.iam.gserviceaccount.com"
}
