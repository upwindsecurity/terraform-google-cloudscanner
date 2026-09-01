data "google_service_account" "cloudscanner_sa" {
  project    = local.project
  account_id = split("@", var.cloudscanner_sa_email)[0]

  lifecycle {
    precondition {
      condition     = split("@", var.cloudscanner_sa_email)[1] == "${local.project}.iam.gserviceaccount.com"
      error_message = "Cloud Scanner preflight failed: cloudscanner_sa_email must belong to upwind_orchestrator_project (${local.project}). Received ${var.cloudscanner_sa_email}."
    }
  }
}

data "google_service_account" "cloudscanner_scaler_sa" {
  project    = local.project
  account_id = split("@", var.cloudscanner_scaler_sa_email)[0]

  lifecycle {
    precondition {
      condition     = split("@", var.cloudscanner_scaler_sa_email)[1] == "${local.project}.iam.gserviceaccount.com"
      error_message = "Cloud Scanner preflight failed: cloudscanner_scaler_sa_email must belong to upwind_orchestrator_project (${local.project}). Received ${var.cloudscanner_scaler_sa_email}."
    }
  }
}
