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
    condition     = endswith(google_cloud_run_v2_job.cleaner.template[0].template[0].containers[0].image, "/images/cloudscanner/gcpcleaner:latest")
    error_message = "upwind.io must use the prod image."
  }

  assert {
    condition = (
      { for e in google_cloud_run_v2_job.cleaner.template[0].template[0].containers[0].env : e.name => e.value if e.value != null } ==
      { GCP_PROJECT_ID = "proj-a", UPWIND_REGION = "us", DRY_RUN = "false", CUSTOMER_CREDENTIALS = "wif" }
    )
    error_message = "The cleaner must get the project and the region, delete by default, and reach customer projects through WIF by default."
  }

  assert {
    condition     = google_cloud_scheduler_job.cleaner.http_target[0].uri == "https://run.googleapis.com/v2/projects/proj-a/locations/us-central1/jobs/upwind-cleaner-abcde:run"
    error_message = "The Scheduler job must run the cleaner job."
  }

  assert {
    condition     = google_cloud_scheduler_job.cleaner.http_target[0].oauth_token[0].service_account_email == "upwind-abcde@hub.iam.gserviceaccount.com"
    error_message = "The Scheduler job must start the cleaner as its service account by default."
  }

  assert {
    condition     = length(google_cloud_run_v2_job_iam_member.invoker) == 0 && length(google_cloud_run_v2_job.cleaner.template[0].template[0].vpc_access) == 0
    error_message = "No invoker grant and no VPC egress by default."
  }

  assert {
    condition     = length(google_compute_network.cleaner) == 0 && length(google_cloud_run_v2_job.cleaner.binary_authorization) == 0
    error_message = "No network of its own and no Binary Authorization policy by default."
  }
}

run "dev_dry_run" {
  command = plan

  variables {
    public_uri_domain    = "upwind.dev"
    upwind_infra_region  = "eu"
    dry_run              = true
    customer_credentials = "adc"
  }

  assert {
    condition     = endswith(google_cloud_run_v2_job.cleaner.template[0].template[0].containers[0].image, "/images-dev/cloudscanner/gcpcleaner:latest")
    error_message = "upwind.dev must use the dev image."
  }

  assert {
    condition = (
      { for e in google_cloud_run_v2_job.cleaner.template[0].template[0].containers[0].env : e.name => e.value if e.value != null } ==
      { GCP_PROJECT_ID = "proj-a", UPWIND_REGION = "dev-eu", DRY_RUN = "true", CUSTOMER_CREDENTIALS = "adc" }
    )
    error_message = "A dev deploy must name the dev region, and dry_run and customer_credentials must reach the job."
  }
}

run "grants_and_egress" {
  command = plan

  variables {
    grant_invoker                   = true
    scheduler_service_account_email = "upwind-scaler-abcde@orch.iam.gserviceaccount.com"
    vpc_egress = {
      network    = "projects/proj-a/global/networks/upwind-scaler"
      subnetwork = "projects/proj-a/regions/us-central1/subnetworks/upwind-scaler"
    }
  }

  assert {
    condition     = google_cloud_run_v2_job_iam_member.invoker[0].role == "roles/run.invoker" && google_cloud_run_v2_job_iam_member.invoker[0].member == "serviceAccount:upwind-scaler-abcde@orch.iam.gserviceaccount.com"
    error_message = "The invoker grant must give the scheduler's service account run.invoker on the job."
  }

  assert {
    condition     = google_cloud_scheduler_job.cleaner.http_target[0].oauth_token[0].service_account_email == "upwind-scaler-abcde@orch.iam.gserviceaccount.com" && google_cloud_run_v2_job.cleaner.template[0].template[0].service_account == "upwind-abcde@hub.iam.gserviceaccount.com"
    error_message = "The Scheduler job must start the cleaner as scheduler_service_account_email, and the cleaner keep running as service_account_email."
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

run "customer_credentials_refused" {
  command = plan

  variables {
    customer_credentials = "key"
  }

  expect_failures = [var.customer_credentials]
}

run "own_network_egress" {
  command = apply

  variables {
    cleaner_vpc_egress_enabled = true
  }

  assert {
    condition = (
      google_cloud_run_v2_job.cleaner.template[0].template[0].vpc_access[0].network_interfaces[0].network == google_compute_network.cleaner[0].id &&
      google_cloud_run_v2_job.cleaner.template[0].template[0].vpc_access[0].network_interfaces[0].subnetwork == google_compute_subnetwork.cleaner[0].id &&
      google_cloud_run_v2_job.cleaner.template[0].template[0].vpc_access[0].egress == "PRIVATE_RANGES_ONLY"
    )
    error_message = "cleaner_vpc_egress_enabled must attach the job to its own network, private ranges only."
  }

  assert {
    condition     = google_compute_subnetwork.cleaner[0].region == "us-central1"
    error_message = "The cleaner's subnetwork must be in the job's region."
  }
}

run "both_egress_refused" {
  command = plan

  variables {
    cleaner_vpc_egress_enabled = true
    vpc_egress = {
      network    = "projects/proj-a/global/networks/upwind-scaler"
      subnetwork = "projects/proj-a/regions/us-central1/subnetworks/upwind-scaler"
    }
  }

  expect_failures = [var.cleaner_vpc_egress_enabled]
}

run "binary_authorization_default_policy" {
  command = plan

  variables {
    binary_authorization_policy = "default"
  }

  assert {
    condition     = google_cloud_run_v2_job.cleaner.binary_authorization[0].use_default == true && google_cloud_run_v2_job.cleaner.binary_authorization[0].policy == null
    error_message = "\"default\" must use the project's default Binary Authorization policy."
  }
}

run "binary_authorization_named_policy" {
  command = plan

  variables {
    binary_authorization_policy = "projects/proj-a/platforms/cloudRun/policies/upwind"
  }

  assert {
    condition     = google_cloud_run_v2_job.cleaner.binary_authorization[0].policy == "projects/proj-a/platforms/cloudRun/policies/upwind" && google_cloud_run_v2_job.cleaner.binary_authorization[0].use_default == null
    error_message = "A named policy must reach the job."
  }
}

run "binary_authorization_policy_refused" {
  command = plan

  variables {
    binary_authorization_policy = "upwind"
  }

  expect_failures = [var.binary_authorization_policy]
}

run "own_network_all_traffic" {
  command = apply

  variables {
    cleaner_vpc_egress_enabled = true
    cleaner_vpc_egress         = "ALL_TRAFFIC"
  }

  assert {
    condition     = google_cloud_run_v2_job.cleaner.template[0].template[0].vpc_access[0].egress == "ALL_TRAFFIC"
    error_message = "cleaner_vpc_egress must set the job's egress."
  }

  assert {
    condition     = google_compute_router_nat.cleaner[0].router == google_compute_router.cleaner[0].name
    error_message = "All-traffic egress on the cleaner's own network needs a NAT."
  }
}
