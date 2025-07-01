locals {
  dev_scaler_image  = "us-east1-docker.pkg.dev/upwindsecurity/images-dev/cloudscanner/scaler:latest"
  prod_scaler_image = "us-east1-docker.pkg.dev/upwindsecurity/images/cloudscanner/scaler:latest"
  project           = var.upwind_orchestrator_project
  # Sanitize the org_id to be used in resource names
  # SA names can't have underscores and have a small limit on length...
  # Additionally they have to end with a lowercase letter or number......
  org_id_sanitized = replace(lower(var.upwind_organization_id), "org_", "")
  org_id_truncated = substr(local.org_id_sanitized, max(0, length(local.org_id_sanitized) - 5), 5)
  # Get the optional resource suffix
  # Split the email at "@" and take the first part
  username_part = split("@", var.cloudscanner_sa_email)[0]
  # Split the username by "-" character
  parts = split("-", local.username_part)
  # Check if there are at least 4 parts (meaning we have the optional suffix)
  has_suffix = length(local.parts) >= 4
  # Extract the last part before the @ if it exists, otherwise empty string
  custom_suffix          = local.has_suffix ? local.parts[length(local.parts) - 1] : ""
  resource_suffix_hyphen = format("%s%s", local.org_id_truncated, local.custom_suffix == "" ? "" : "-${local.custom_suffix}")

  # The main service account for the Cloud Scanner
  cloudscanner_sa = data.google_service_account.cloudscanner_sa
  # The service account for the Cloud Scanner scaler function
  cloudscanner_scaler_sa = data.google_service_account.cloudscanner_scaler_sa
  # The network for the Cloud Scanner
  network = var.custom_network != "" ? data.google_compute_network.custom_network[0].self_link : google_compute_network.cloudscanner_network[0].self_link
  subnet = var.custom_network != "" ? (
    var.custom_subnet != "" ? data.google_compute_subnetwork.custom_subnet[0].self_link : ""
  ) : google_compute_subnetwork.cloudscanner_subnetwork[0].self_link
}

provider "google" {
  project      = local.project
  access_token = var.access_token
}

resource "null_resource" "always_run" {
  triggers = {
    always_run = var.public_uri_domain
  }
}

# Create the instances templates. We're using a blue/green deployment approach for the intstance templates that allows the scaler
# to apply changes to the instance templates as need. Instance templates cannot be modified once created, hence the scaler will use
## a blue/green deployment approach replacing and alternating between the templates as necessary.
resource "google_compute_region_instance_template" "cloudscanner_inst_templates" {
  count        = 2
  project      = local.project
  name_prefix  = "upwind-tpl-${var.scanner_id}-"
  machine_type = var.machine_type
  region       = var.region

  # Label is used for IsNotCloudScannerInstance
  labels = {
    upwind-component = "cloudscanner"
  }

  # add tags for SSH
  tags = var.enable_iap_ssh ? ["ssh-enabled"] : []

  metadata_startup_script = <<-EOF
    #!/bin/bash

    # Retrieve credentials from Secret Manager
    echo "Getting upwind credentials from Secret Manager for ${var.scanner_id}..."
    export UPWIND_CLIENT_ID=$(gcloud secrets versions access latest --secret=${data.google_secret_manager_secret.scanner_client_id.secret_id})
    export UPWIND_CLIENT_SECRET=$(gcloud secrets versions access latest --secret=${data.google_secret_manager_secret.scanner_client_secret.secret_id})
    export UPWIND_INFRA_REGION=${var.upwind_infra_region}
    export GCP_REGION=${var.region}
    export GCP_CLOUDSCANNER_SA_EMAIL=${local.cloudscanner_sa.email}
    export GCP_CLOUDSCANNER_SCALER_SA_EMAIL=${local.cloudscanner_scaler_sa.email}

    export UPWIND_CLOUDSCANNER_ID=${var.scanner_id}

    echo "Getting Cloud Scanner install script for ${var.scanner_id} ..."
    curl -L https://get.${var.public_uri_domain}/cloudscanner.sh -O
    chmod +x cloudscanner.sh
    echo "Executing Cloud Scanner install for ${var.scanner_id}..."
    UPWIND_IO=${var.public_uri_domain} bash ./cloudscanner.sh
    echo "Cloud Scanner install finished for ${var.scanner_id}..."
  EOF

  metadata = {
    enable-oslogin     = "TRUE"
    serial-port-enable = "TRUE"
  }

  scheduling {
    preemptible                 = true
    automatic_restart           = false
    on_host_maintenance         = "TERMINATE"
    provisioning_model          = "SPOT"
    instance_termination_action = "STOP"
  }

  # Boot disk
  disk {
    source_image = var.boot_image
    disk_size_gb = var.boot_disk_size_gb
    disk_type    = var.boot_disk_type
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = local.network
    subnetwork = local.subnet
  }

  service_account {
    email  = local.cloudscanner_sa.email
    scopes = ["cloud-platform"] # Use this scope to defer auth to IAM SA roles
  }

  lifecycle {
    replace_triggered_by  = [null_resource.always_run]
    create_before_destroy = true
  }
}

# Instance Group Manager
resource "google_compute_region_instance_group_manager" "cloudscanner" {
  project                          = local.project
  name                             = "upwind-cs-asg-${var.scanner_id}"
  base_instance_name               = "upwind-vm-${var.scanner_id}"
  region                           = var.region
  distribution_policy_zones        = var.availability_zones
  distribution_policy_target_shape = "BALANCED"

  update_policy {
    type                         = "OPPORTUNISTIC"
    minimal_action               = "NONE"
    max_unavailable_fixed        = length(var.availability_zones) # must be at least the number of zones
    instance_redistribution_type = "NONE"
  }

  instance_lifecycle_policy {
    default_action_on_failure = "DO_NOTHING"
  }

  version {
    name              = "cloudscanner"
    instance_template = google_compute_region_instance_template.cloudscanner_inst_templates[0].id
  }

  all_instances_config {
    labels = {
      name = "upwind-cs-asg-${var.scanner_id}"
    }
  }

  # Setting the initial target size. The number of VMs to be created when the instance group is created.
  target_size = var.target_size

  lifecycle {
    replace_triggered_by = [null_resource.always_run]
  }
}

# Scaler Function
resource "google_cloud_run_v2_job" "scaler_function" {
  name                = "upwind-scaler-function-${var.scanner_id}"
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
          value = local.project
        }

        env {
          name  = "GCP_MIG_REGION"
          value = google_compute_region_instance_group_manager.cloudscanner.region
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
          name  = "UPWIND_CONFIG_ID"
          value = var.scanner_id
        }

        env {
          name  = "UPWIND_ONBOARDING_VERSION"
          value = "1"
        }

        env {
          name = "UPWIND_AUTH_CLIENT_ID"
          value_source {
            secret_key_ref {
              secret  = data.google_secret_manager_secret.scanner_client_id.secret_id
              version = data.google_secret_manager_secret_version.scanner_client_id_v1.version
            }
          }
        }

        env {
          name = "UPWIND_AUTH_CLIENT_SECRET"
          value_source {
            secret_key_ref {
              secret  = data.google_secret_manager_secret.scanner_client_secret.secret_id
              version = data.google_secret_manager_secret_version.scanner_client_secret_v1.version
            }
          }
        }
      }

      # Setting the max tries to 1 as the retries will be performed by the Job scheduler
      max_retries = 1
      # Setting the max time for a task to 5 minutes
      timeout = "300s"

      service_account = local.cloudscanner_scaler_sa.email
    }

    # Set concurrency so that only one instance runs at a time
    parallelism = 1
    task_count  = 1
  }
}

# Scheduler for running the scaler function
resource "google_cloud_scheduler_job" "scaler_scheduler_job" {
  name     = "upwind-scaler-scheduler-job-${var.scanner_id}"
  region   = var.region
  schedule = var.scaler_function_schedule


  http_target {
    http_method = "POST"
    uri         = "https://${google_cloud_run_v2_job.scaler_function.location}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${local.project}/jobs/${google_cloud_run_v2_job.scaler_function.name}:run"

    oauth_token {
      service_account_email = local.cloudscanner_scaler_sa.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [google_cloud_run_v2_job.scaler_function]
}
