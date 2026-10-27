mock_provider "google" {}
mock_provider "null" {}

variables {
  upwind_organization_id       = "org_abcde"
  scanner_id                   = "ucsc-abc123"
  access_token                 = "x"
  cloudscanner_sa_email        = "upwind-cs-abcde@proj-a.iam.gserviceaccount.com"
  cloudscanner_scaler_sa_email = "upwind-scaler-abcde@proj-a.iam.gserviceaccount.com"
  upwind_orchestrator_project  = "proj-abc"
}

run "supported_region_used" {
  command = plan

  variables {
    region             = "europe-west2"
    availability_zones = ["europe-west2-a"]
  }

  assert {
    condition     = google_cloud_scheduler_job.scaler_scheduler_job[0].region == "europe-west2"
    error_message = "A region Cloud Scheduler supports must host the scanner's own Scheduler job."
  }
}

run "newly_listed_region_used" {
  command = plan

  variables {
    region             = "me-west1"
    availability_zones = ["me-west1-a"]
  }

  assert {
    condition     = google_cloud_scheduler_job.scaler_scheduler_job[0].region == "me-west1"
    error_message = "me-west1 supports Cloud Scheduler and must be used directly."
  }
}

run "unsupported_eu_region_falls_back_in_continent" {
  command = plan

  variables {
    region             = "europe-north1"
    availability_zones = ["europe-north1-a"]
  }

  assert {
    condition     = google_cloud_scheduler_job.scaler_scheduler_job[0].region == "europe-west1"
    error_message = "A European region without Cloud Scheduler must fall back to europe-west1, not the US default."
  }
}

run "unmapped_region_uses_default" {
  command = plan

  variables {
    region             = "africa-south1"
    availability_zones = ["africa-south1-a"]
  }

  assert {
    condition     = google_cloud_scheduler_job.scaler_scheduler_job[0].region == "us-central1"
    error_message = "A region with no Cloud Scheduler and no continent fallback must use default_scheduler_region."
  }
}

run "explicit_override_wins" {
  command = plan

  variables {
    region             = "europe-west2"
    availability_zones = ["europe-west2-a"]
    scheduler_region   = "us-east1"
  }

  assert {
    condition     = google_cloud_scheduler_job.scaler_scheduler_job[0].region == "us-east1"
    error_message = "An explicit scheduler_region must win over the scanner's region."
  }
}
