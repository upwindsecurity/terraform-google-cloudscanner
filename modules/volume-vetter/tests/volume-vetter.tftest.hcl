mock_provider "google" {}

variables {
  project               = "proj-a"
  name                  = "upwind-volume-vetter-abcde"
  service_account_email = "upwind-abcde@hub.iam.gserviceaccount.com"
  sign_key              = "projects/proj-a/locations/global/keyRings/upwind-cloudscanner/cryptoKeys/scan-volume-sign"
  customer_sa           = "imcneice-poc-sa@customer.iam.gserviceaccount.com"
  client_id_secret      = "upwind-scanner-client-id-abcde"
  client_secret_secret  = "upwind-scanner-client-secret-abcde"
}

run "defaults" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.vetter.template[0].service_account == "upwind-abcde@hub.iam.gserviceaccount.com"
    error_message = "The vetter must run as the given service account."
  }

  assert {
    condition     = endswith(google_cloud_run_v2_service.vetter.template[0].containers[0].image, "/images/cloudscanner/saasvolumevetter:latest")
    error_message = "upwind.io must use the prod image."
  }

  assert {
    condition = (
      { for e in google_cloud_run_v2_service.vetter.template[0].containers[0].env : e.name => e.value if e.value != null } ==
      {
        SIGN_KEY      = "projects/proj-a/locations/global/keyRings/upwind-cloudscanner/cryptoKeys/scan-volume-sign",
        CUSTOMER_SA   = "imcneice-poc-sa@customer.iam.gserviceaccount.com",
        DRY_RUN       = "true",
        UPWIND_REGION = "us"
      }
    )
    error_message = "The vetter must get the signing key, customer SA, log-shipping region, and start in dry-run."
  }

  assert {
    condition = length([
      for e in google_cloud_run_v2_service.vetter.template[0].containers[0].env :
      e if e.name == "UPWIND_AUTH_CLIENT_ID" && e.value_source[0].secret_key_ref[0].secret == "upwind-scanner-client-id-abcde"
    ]) == 1
    error_message = "The Upwind client id must be sourced from its Secret Manager secret."
  }

  assert {
    condition     = google_eventarc_trigger.disks_insert.location == "global"
    error_message = "The trigger must be global so disk creations in any region are caught."
  }

  assert {
    condition     = length([for c in google_eventarc_trigger.disks_insert.matching_criteria : c if c.attribute == "methodName" && c.value == "v1.compute.disks.insert"]) == 1
    error_message = "The trigger must match compute.disks.insert audit logs."
  }

  assert {
    condition     = google_eventarc_trigger.disks_insert.destination[0].cloud_run_service[0].service == "upwind-volume-vetter-abcde" && google_eventarc_trigger.disks_insert.destination[0].cloud_run_service[0].region == "us-central1"
    error_message = "The trigger must target the vetter service in its region."
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.invoker) == 0 && length(google_project_iam_member.event_receiver) == 0 && length(google_cloud_run_v2_service.vetter.template[0].vpc_access) == 0
    error_message = "No grants and no VPC egress by default."
  }
}

run "dev_delete_mode" {
  command = plan

  variables {
    public_uri_domain = "upwind.dev"
    dry_run           = false
  }

  assert {
    condition     = endswith(google_cloud_run_v2_service.vetter.template[0].containers[0].image, "/images-dev/cloudscanner/saasvolumevetter:latest")
    error_message = "upwind.dev must use the dev image."
  }

  assert {
    condition     = length([for e in google_cloud_run_v2_service.vetter.template[0].containers[0].env : e if e.name == "DRY_RUN" && e.value == "false"]) == 1
    error_message = "dry_run = false must reach the service so it deletes."
  }

  assert {
    condition     = length([for e in google_cloud_run_v2_service.vetter.template[0].containers[0].env : e if e.name == "UPWIND_REGION" && e.value == "dev-us"]) == 1
    error_message = "A dev deploy must ship logs to the dev region."
  }
}

run "grants_and_egress" {
  command = plan

  variables {
    grant_invoker        = true
    grant_event_receiver = true
    vpc_egress = {
      network    = "projects/proj-a/global/networks/upwind-scaler"
      subnetwork = "projects/proj-a/regions/us-central1/subnetworks/upwind-scaler"
    }
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_member.invoker[0].role == "roles/run.invoker" && google_cloud_run_v2_service_iam_member.invoker[0].member == "serviceAccount:upwind-abcde@hub.iam.gserviceaccount.com"
    error_message = "The invoker grant must give the service account run.invoker on the vetter service."
  }

  assert {
    condition     = google_project_iam_member.event_receiver[0].role == "roles/eventarc.eventReceiver" && google_project_iam_member.event_receiver[0].member == "serviceAccount:upwind-abcde@hub.iam.gserviceaccount.com"
    error_message = "The event-receiver grant must give the service account eventarc.eventReceiver on the project."
  }

  assert {
    condition     = google_cloud_run_v2_service.vetter.template[0].vpc_access[0].egress == "PRIVATE_RANGES_ONLY"
    error_message = "VPC egress must route private ranges only."
  }
}

run "name_trailing_hyphen_refused" {
  command = plan

  variables {
    name = "upwind-volume-vetter-"
  }

  expect_failures = [var.name]
}
