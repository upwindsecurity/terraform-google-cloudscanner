locals {
  dev_cleaner_image  = "us-east1-docker.pkg.dev/upwindsecurity/images-dev/cloudscanner/gcpcleaner:latest"
  prod_cleaner_image = "us-east1-docker.pkg.dev/upwindsecurity/images/cloudscanner/gcpcleaner:latest"

  # The cleaner takes a go-common region name, in which dev regions are prefixed.
  upwind_region = var.public_uri_domain == "upwind.dev" ? "dev-${var.upwind_infra_region}" : var.upwind_infra_region

  scheduler_service_account_email = coalesce(var.scheduler_service_account_email, var.service_account_email)

  vpc_egress = var.cleaner_vpc_egress_enabled ? {
    network    = google_compute_network.cleaner[0].id
    subnetwork = google_compute_subnetwork.cleaner[0].id
  } : var.vpc_egress
}

provider "google" {
  project        = var.project
  access_token   = var.access_token
  default_labels = merge(var.default_labels, var.labels)
}

# Deletes the scan disks GCP SaaS scans leave in this project, and the snapshots they leave in the customer's projects.
resource "google_cloud_run_v2_job" "cleaner" {
  name                = var.name
  location            = var.region
  deletion_protection = false

  # Only needed to satisfy the constraints/run.allowedBinaryAuthorizationPolicies org policy.
  dynamic "binary_authorization" {
    for_each = var.binary_authorization_policy == "" ? [] : [1]
    content {
      use_default = var.binary_authorization_policy == "default" ? true : null
      policy      = var.binary_authorization_policy == "default" ? null : var.binary_authorization_policy
    }
  }

  template {
    template {
      containers {
        image = (var.public_uri_domain == "upwind.io") ? local.prod_cleaner_image : local.dev_cleaner_image

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
          name  = "UPWIND_REGION"
          value = local.upwind_region
        }

        env {
          name  = "DRY_RUN"
          value = tostring(var.dry_run)
        }

        env {
          name  = "CUSTOMER_CREDENTIALS"
          value = var.customer_credentials
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

      dynamic "vpc_access" {
        for_each = local.vpc_egress == null ? [] : [local.vpc_egress]
        content {
          network_interfaces {
            network    = vpc_access.value.network
            subnetwork = vpc_access.value.subnetwork
          }
          egress = "PRIVATE_RANGES_ONLY"
        }
      }

      # Retries come from the next scheduled run.
      max_retries = 0
      # Above the cleaner's own 240s run budget, so it can stop new deletes and log its summary first.
      timeout = "300s"

      service_account = var.service_account_email
    }

    parallelism = 1
    task_count  = 1
  }
}

resource "google_cloud_scheduler_job" "cleaner" {
  name     = "${var.name}-scheduler"
  region   = var.region
  schedule = "0 * * * *" # Hourly: nothing is old enough to delete any sooner

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project}/locations/${google_cloud_run_v2_job.cleaner.location}/jobs/${google_cloud_run_v2_job.cleaner.name}:run"

    oauth_token {
      service_account_email = local.scheduler_service_account_email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [google_cloud_run_v2_job_iam_member.invoker]
}

resource "google_cloud_run_v2_job_iam_member" "invoker" {
  count = var.grant_invoker ? 1 : 0

  name     = google_cloud_run_v2_job.cleaner.name
  location = google_cloud_run_v2_job.cleaner.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.scheduler_service_account_email}"
}
