mock_provider "google" {}
mock_provider "null" {}

variables {
  upwind_organization_id       = "org_abcde"
  scanner_id                   = "ucsc-abc123"
  cloudscanner_sa_email        = "upwind-cs-abcde@proj-a.iam.gserviceaccount.com"
  cloudscanner_scaler_sa_email = "upwind-scaler-abcde@proj-a.iam.gserviceaccount.com"
  upwind_orchestrator_project  = "proj-abc"
}

run "unset_by_default" {
  command = plan

  assert {
    condition     = length(google_cloud_run_v2_job.scaler_function[0].binary_authorization) == 0
    error_message = "The scaler must declare no Binary Authorization policy by default."
  }
}

run "project_default_policy" {
  command = plan

  variables {
    binary_authorization_policy = "default"
  }

  assert {
    condition     = google_cloud_run_v2_job.scaler_function[0].binary_authorization[0].use_default == true && google_cloud_run_v2_job.scaler_function[0].binary_authorization[0].policy == null
    error_message = "\"default\" must set use_default and no named policy."
  }
}

run "named_policy" {
  command = plan

  variables {
    binary_authorization_policy = "projects/proj-abc/platforms/cloudRun/policies/upwind"
  }

  assert {
    condition     = google_cloud_run_v2_job.scaler_function[0].binary_authorization[0].policy == "projects/proj-abc/platforms/cloudRun/policies/upwind" && google_cloud_run_v2_job.scaler_function[0].binary_authorization[0].use_default == null
    error_message = "A named policy must be passed through without use_default."
  }
}

run "invalid_policy_rejected" {
  command = plan

  variables {
    binary_authorization_policy = "allow-everything"
  }

  expect_failures = [var.binary_authorization_policy]
}
