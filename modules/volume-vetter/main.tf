locals {
  dev_vetter_image  = "us-east1-docker.pkg.dev/upwindsecurity/images-dev/cloudscanner/saasvolumevetter:latest"
  prod_vetter_image = "us-east1-docker.pkg.dev/upwindsecurity/images/cloudscanner/saasvolumevetter:latest"

  # The vetter ships logs to a go-common region name, in which dev regions are prefixed.
  upwind_region = var.public_uri_domain == "upwind.dev" ? "dev-${var.upwind_infra_region}" : var.upwind_infra_region
}

provider "google" {
  project        = var.project
  access_token   = var.access_token
  default_labels = merge(var.default_labels, var.labels)
}

# Verifies, at creation time, that scan disks created in this SaaS project by the customer's SA carry
# a valid Upwind signature, and deletes any that do not. Event-driven (not scheduled), so it is a
# Cloud Run service behind an Eventarc audit-log trigger rather than a scheduled job like the cleaner.
resource "google_cloud_run_v2_service" "vetter" {
  name                = var.name
  location            = var.region
  deletion_protection = false
  # Eventarc delivers over the internal network; the trigger's SA still authenticates with run.invoker.
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.service_account_email

    containers {
      image = (var.public_uri_domain == "upwind.io") ? local.prod_vetter_image : local.dev_vetter_image

      resources {
        limits = {
          memory = "256Mi"
          cpu    = "1"
        }
      }

      # The KMS cryptoKey the worker signs with; the vetter resolves each token's version public key
      # under it. Empty switches the vetter off (every event becomes a no-op).
      env {
        name  = "SIGN_KEY"
        value = var.sign_key
      }

      # Only creations by this principal are assessed; everything else is ignored.
      env {
        name  = "CUSTOMER_SA"
        value = var.customer_sa
      }

      # Deletes only when explicitly "false"; anything else logs the intended delete and acts on nothing.
      env {
        name  = "DRY_RUN"
        value = tostring(var.dry_run)
      }

      # Log shipping: the vetter sends each event's logs to the CloudScanner server, which re-logs them
      # into Upwind's central logging. The region selects that backend; the credentials scope the logs
      # to the org. Verification stays offline — this is best-effort telemetry.
      env {
        name  = "UPWIND_REGION"
        value = local.upwind_region
      }

      env {
        name = "UPWIND_AUTH_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = var.client_id_secret
            version = var.secret_version
          }
        }
      }

      env {
        name = "UPWIND_AUTH_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = var.client_secret_secret
            version = var.secret_version
          }
        }
      }
    }
  }
}

# A global trigger so disks created in any region of the SaaS project are vetted by the one regional
# service. compute.disks.insert is an Admin Activity audit log, so no Data Access log config is needed.
resource "google_eventarc_trigger" "disks_insert" {
  name            = "${var.name}-disks-insert"
  location        = "global"
  service_account = var.service_account_email

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.audit.log.v1.written"
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "compute.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "v1.compute.disks.insert"
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.vetter.name
      region  = var.region
      path    = "/"
    }
  }

  # The grants the trigger's SA needs before it can receive events and invoke the service.
  depends_on = [
    google_cloud_run_v2_service_iam_member.invoker,
    google_project_iam_member.event_receiver,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count = var.grant_invoker ? 1 : 0

  name     = google_cloud_run_v2_service.vetter.name
  location = google_cloud_run_v2_service.vetter.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "event_receiver" {
  count = var.grant_event_receiver ? 1 : 0

  project = var.project
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${var.service_account_email}"
}
