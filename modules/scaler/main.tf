locals {
  dev_scaler_image  = "us-east1-docker.pkg.dev/upwindsecurity/images-dev/cloudscanner/scaler:latest"
  prod_scaler_image = "us-east1-docker.pkg.dev/upwindsecurity/images/cloudscanner/scaler:latest"
}

provider "google" {
  project        = var.project
  access_token   = var.access_token
  default_labels = merge(var.default_labels, var.labels)
}

# One scaler for every scanner config in the project. It has no UPWIND_CONFIG_ID or
# GCP_MIG_REGION: their absence is what makes the scaler list the project's configs
# and scale them all.
resource "google_cloud_run_v2_job" "scaler" {
  name                = var.name
  location            = var.region
  deletion_protection = false

  template {
    template {
      containers {
        image = (var.public_uri_domain == "upwind.io") ? local.prod_scaler_image : local.dev_scaler_image

        # Explicitly setting resource limits to the lowest values possible
        resources {
          limits = {
            memory = "512Mi"
            cpu    = "1"
          }
        }

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project
        }

        env {
          name  = "UPWIND_IO"
          value = var.public_uri_domain
        }

        env {
          name  = "UPWIND_INFRA_REGION"
          value = var.upwind_infra_region
        }

        env {
          name  = "UPWIND_ONBOARDING_VERSION"
          value = "1"
        }

        env {
          name = "UPWIND_AUTH_CLIENT_ID"
          value_source {
            secret_key_ref {
              secret = var.client_id_secret
              # Defaults to "latest", which is resolved at each job execution, so a
              # rotated credential is picked up automatically without a terraform apply.
              # Pinning a numeric version here would leave the scaler on a stale
              # (possibly disabled) version after rotation, causing ObtainToken 401s.
              version = var.scanner_secret_version
            }
          }
        }

        env {
          name = "UPWIND_AUTH_CLIENT_SECRET"
          value_source {
            secret_key_ref {
              secret  = var.client_secret_secret
              version = var.scanner_secret_version
            }
          }
        }
      }

      # Direct VPC egress is off by default: Cloud Run holds its egress addresses in the
      # subnet for 1-2 hours after the job is deleted, which blocks destroying the network,
      # and it slows the job's startup. It is only needed to satisfy the
      # constraints/run.allowedVPCEgress org policy some customers enforce, which rejects
      # Cloud Run resources with no explicit egress setting.
      dynamic "vpc_access" {
        for_each = var.scaler_vpc_egress_enabled ? [1] : []
        content {
          network_interfaces {
            network    = google_compute_network.scaler[0].id
            subnetwork = google_compute_subnetwork.scaler[0].id
          }
          egress = "PRIVATE_RANGES_ONLY"
        }
      }

      # Setting the max tries to 1 as the retries will be performed by the Job scheduler
      max_retries = 1
      # Setting the max time for a task to 5 minutes
      timeout = "300s"

      service_account = var.service_account_email
    }

    # Set concurrency so that only one instance runs at a time
    parallelism = 1
    task_count  = 1
  }

  # Cloud Run can check the service account's access to the secrets when the job is created.
  depends_on = [google_secret_manager_secret_iam_member.accessor]
}

resource "google_cloud_scheduler_job" "scaler" {
  name     = "${var.name}-scheduler"
  region   = var.region
  schedule = "*/10 * * * *" # Every 10 minutes

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project}/locations/${google_cloud_run_v2_job.scaler.location}/jobs/${google_cloud_run_v2_job.scaler.name}:run"

    oauth_token {
      service_account_email = var.service_account_email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [google_cloud_run_v2_job_iam_member.invoker]
}

resource "google_cloud_run_v2_job_iam_member" "invoker" {
  count = var.grant_invoker ? 1 : 0

  name     = google_cloud_run_v2_job.scaler.name
  location = google_cloud_run_v2_job.scaler.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = var.grant_secret_access ? toset([var.client_id_secret, var.client_secret_secret]) : toset([])

  project   = var.project
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}
