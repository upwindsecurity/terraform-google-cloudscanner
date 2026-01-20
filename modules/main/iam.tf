data "google_service_account" "cloudscanner_sa" {
  project    = local.project
  account_id = split("@", var.cloudscanner_sa_email)[0]
}

data "google_service_account" "cloudscanner_scaler_sa" {
  project    = local.project
  account_id = split("@", var.cloudscanner_scaler_sa_email)[0]
}
