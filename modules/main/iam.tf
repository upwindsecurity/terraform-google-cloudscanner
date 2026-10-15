data "google_service_account" "cloudscanner_sa" {
  account_id = var.cloudscanner_sa_email
}

data "google_service_account" "cloudscanner_scaler_sa" {
  account_id = var.cloudscanner_scaler_sa_email
}
