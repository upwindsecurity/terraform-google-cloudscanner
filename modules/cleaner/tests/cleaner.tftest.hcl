mock_provider "google" {}

variables {
  project               = "proj-a"
  name                  = "upwind-cleaner-abcde"
  service_account_email = "upwind-abcde@hub.iam.gserviceaccount.com"
  client_id_secret      = "upwind-scanner-client-id-abcde"
  client_secret_secret  = "upwind-scanner-client-secret-abcde"
}

run "defaults" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_job.cleaner.template[0].template[0].service_account == "upwind-abcde@hub.iam.gserviceaccount.com"
    error_message = "The cleaner must run as the given service account."
  }

  assert {
    condition     = endswith(google_cloud_run_v2_job.cleaner.template[0].template[0].containers[0].image, "/images/cloudscanner/saascleaner:latest")
    error_message = "upwind.io must use the prod image."
  }

  assert {
    condition = (
      { for e in google_cloud_run_v2_job.cleaner.template[0].template[0].containers[0].env : e.name => e.value if e.value != null } ==
      { GCP_PROJECT_ID = "proj-a", UPWIND_REGION = "us", DRY_RUN = "false" }
    )
    error_message = "The cleaner must get the project and the region, and delete by default."
  }

  assert {
    condition     = google_cloud_scheduler_job.cleaner.http_target[0].uri == "https://run.googleapis.com/v2/projects/proj-a/locations/us-central1/jobs/upwind-cleaner-abcde:run"
    error_message = "The Scheduler job must run the cleaner job."
  }

  assert {
    condition     = length(google_cloud_run_v2_job_iam_member.invoker) == 0 && length(google_cloud_run_v2_job.cleaner.template[0].template[0].vpc_access) == 0
    error_message = "No invoker grant and no VPC egress by default."
  }
}

run "dev_dry_run" {
  command = plan

  variables {
    public_uri_domain   = "upwind.dev"
    upwind_infra_region = "eu"
    dry_run             = true
  }

  assert {
    condition     = endswith(google_cloud_run_v2_job.cleaner.template[0].template[0].containers[0].image, "/images-dev/cloudscanner/saascleaner:latest")
    error_message = "upwind.dev must use the dev image."
  }

  assert {
    condition = (
      { for e in google_cloud_run_v2_job.cleaner.template[0].template[0].containers[0].env : e.name => e.value if e.value != null } ==
      { GCP_PROJECT_ID = "proj-a", UPWIND_REGION = "dev-eu", DRY_RUN = "true" }
    )
    error_message = "A dev deploy must name the dev region, and dry_run = true must reach the job."
  }
}

run "grants_and_egress" {
  command = plan

  variables {
    grant_invoker = true
    vpc_egress = {
      network    = "projects/proj-a/global/networks/upwind-scaler"
      subnetwork = "projects/proj-a/regions/us-central1/subnetworks/upwind-scaler"
    }
  }

  assert {
    condition     = google_cloud_run_v2_job_iam_member.invoker[0].role == "roles/run.invoker" && google_cloud_run_v2_job_iam_member.invoker[0].member == "serviceAccount:upwind-abcde@hub.iam.gserviceaccount.com"
    error_message = "The invoker grant must give the service account run.invoker on the job."
  }

  assert {
    condition     = google_cloud_run_v2_job.cleaner.template[0].template[0].vpc_access[0].egress == "PRIVATE_RANGES_ONLY"
    error_message = "VPC egress must route private ranges only."
  }
}

run "name_trailing_hyphen_refused" {
  command = plan

  variables {
    name = "upwind-cleaner-"
  }

  expect_failures = [var.name]
}
