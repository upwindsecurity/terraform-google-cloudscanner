mock_provider "google" {}
mock_provider "null" {}

variables {
  upwind_organization_id       = "org_abcde"
  scanner_id                   = "ucsc-abc123"
  cloudscanner_sa_email        = "upwind-cs-abcde@proj-a.iam.gserviceaccount.com"
  cloudscanner_scaler_sa_email = "upwind-scaler-abcde@proj-a.iam.gserviceaccount.com"
  upwind_orchestrator_project  = "proj-abc"
}

run "scaler_created_by_default" {
  command = plan

  assert {
    condition     = length(google_cloud_run_v2_job.scaler_function) == 1 && length(google_cloud_scheduler_job.scaler_scheduler_job) == 1
    error_message = "The per-config scaler must still be created by default."
  }

  assert {
    condition     = google_cloud_run_v2_job.scaler_function[0].name == "upwind-scaler-function-ucsc-abc123"
    error_message = "The per-config scaler job name must not change."
  }
}

run "scaler_skipped_when_disabled" {
  command = plan

  variables {
    create_scaler = false
  }

  assert {
    condition     = length(google_cloud_run_v2_job.scaler_function) == 0 && length(google_cloud_scheduler_job.scaler_scheduler_job) == 0
    error_message = "create_scaler = false must remove the scaler job and its Scheduler job."
  }
}
