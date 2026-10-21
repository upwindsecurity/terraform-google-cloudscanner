mock_provider "google" {}

variables {
  project               = "proj-a"
  name                  = "upwind-scaler-abcde"
  service_account_email = "upwind-scaler-abcde@proj-a.iam.gserviceaccount.com"
  client_id_secret      = "upwind-scanner-client-id-abcde"
  client_secret_secret  = "upwind-scanner-client-secret-abcde"
  access_token          = "x"
}

run "defaults" {
  command = plan

  # The scaler runs in project mode only when neither of these is set.
  assert {
    condition = alltrue([
      for e in google_cloud_run_v2_job.scaler.template[0].template[0].containers[0].env :
      !contains(["UPWIND_CONFIG_ID", "GCP_MIG_REGION"], e.name)
    ])
    error_message = "The job must not set UPWIND_CONFIG_ID or GCP_MIG_REGION."
  }

  assert {
    condition     = length(google_cloud_run_v2_job.scaler.template[0].template[0].vpc_access) == 0
    error_message = "VPC egress must be off by default."
  }

  assert {
    condition     = google_cloud_scheduler_job.scaler.http_target[0].uri == "https://run.googleapis.com/v2/projects/proj-a/locations/us-central1/jobs/upwind-scaler-abcde:run"
    error_message = "The Scheduler job must run the scaler job."
  }

  assert {
    condition     = endswith(google_cloud_run_v2_job.scaler.template[0].template[0].containers[0].image, "/images/cloudscanner/scaler:latest")
    error_message = "upwind.io must use the prod image."
  }

  # A customer deploy token may not be allowed to set IAM policy, so no grants by default.
  assert {
    condition     = length(google_cloud_run_v2_job_iam_member.invoker) == 0 && length(google_secret_manager_secret_iam_member.accessor) == 0
    error_message = "No IAM bindings by default."
  }

  assert {
    condition     = length(google_compute_network.scaler) == 0 && length(google_compute_subnetwork.scaler) == 0
    error_message = "No network by default."
  }
}

run "dev_image" {
  command = plan

  variables {
    public_uri_domain = "upwind.dev"
  }

  assert {
    condition     = endswith(google_cloud_run_v2_job.scaler.template[0].template[0].containers[0].image, "/images-dev/cloudscanner/scaler:latest")
    error_message = "upwind.dev must use the dev image."
  }
}

run "vpc_egress" {
  command = plan

  variables {
    scaler_vpc_egress_enabled = true
  }

  assert {
    condition     = google_cloud_run_v2_job.scaler.template[0].template[0].vpc_access[0].egress == "PRIVATE_RANGES_ONLY"
    error_message = "VPC egress must route private ranges only."
  }

  assert {
    condition     = endswith(google_compute_subnetwork.scaler[0].ip_cidr_range, "/26") && google_compute_subnetwork.scaler[0].region == "us-central1"
    error_message = "The scaler subnet must be a /26 in the job's region."
  }
}

run "saas_grants" {
  command = plan

  variables {
    grant_invoker       = true
    grant_secret_access = true
  }

  assert {
    condition     = google_cloud_run_v2_job_iam_member.invoker[0].role == "roles/run.invoker" && google_cloud_run_v2_job_iam_member.invoker[0].member == "serviceAccount:upwind-scaler-abcde@proj-a.iam.gserviceaccount.com"
    error_message = "The invoker grant must give the scaler service account run.invoker on the job."
  }

  assert {
    condition = (
      toset([for m in google_secret_manager_secret_iam_member.accessor : m.secret_id]) == toset(["upwind-scanner-client-id-abcde", "upwind-scanner-client-secret-abcde"]) &&
      alltrue([for m in google_secret_manager_secret_iam_member.accessor : m.role == "roles/secretmanager.secretAccessor"])
    )
    error_message = "The secret grant must give secretAccessor on exactly the two secrets."
  }
}

run "name_63_chars_accepted" {
  command = plan

  variables {
    name = "a${join("", [for i in range(62) : "b"])}"
  }
}

run "name_64_chars_refused" {
  command = plan

  variables {
    name = "a${join("", [for i in range(63) : "b"])}"
  }

  expect_failures = [var.name]
}

run "name_trailing_hyphen_refused" {
  command = plan

  variables {
    name = "upwind-scaler-"
  }

  expect_failures = [var.name]
}

run "name_uppercase_refused" {
  command = plan

  variables {
    name = "Upwind-scaler"
  }

  expect_failures = [var.name]
}
