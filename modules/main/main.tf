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
  # Merge default labels with user-provided labels
  # User labels override defaults if keys conflict
  merged_labels = merge(var.default_labels, var.labels)
}

provider "google" {
  project        = local.project
  access_token   = var.access_token
  default_labels = local.merged_labels
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
    set -e
    set -o pipefail

    # Log file for debugging
    LOGFILE="/var/log/cloudscanner-startup.log"
    mkdir -p /var/log

    # Redirect all output to both log file and serial console
    # Use tee to write to both, and don't fail if serial console is unavailable
    exec > >(tee -a "$LOGFILE" | (cat >> /dev/ttyS0 2>/dev/null || cat))
    exec 2>&1

    echo "=== Starting Cloud Scanner installation for ${var.scanner_id} ==="
    echo "Timestamp: $(date)"
    echo "Log file: $LOGFILE"

    # Retrieve credentials from Secret Manager
    echo "Getting upwind credentials from Secret Manager for ${var.scanner_id}..."
    echo "Secret ID for client_id: ${data.google_secret_manager_secret.scanner_client_id.secret_id}"
    echo "Secret ID for client_secret: ${data.google_secret_manager_secret.scanner_client_secret.secret_id}"
    echo "Project: ${local.project}"
    
    # Check if gcloud is available
    if ! command -v gcloud &> /dev/null; then
      echo "ERROR: gcloud command not found"
      exit 1
    fi
    
    # Get client ID with error checking
    echo "Attempting to retrieve UPWIND_CLIENT_ID..."
    if ! CLIENT_ID_OUTPUT=$(timeout 30 gcloud secrets versions access latest --secret=${data.google_secret_manager_secret.scanner_client_id.secret_id} --project=${local.project} 2>&1); then
      echo "ERROR: Failed to retrieve UPWIND_CLIENT_ID from Secret Manager"
      echo "Error output: $CLIENT_ID_OUTPUT"
      exit 1
    fi
    UPWIND_CLIENT_ID="$CLIENT_ID_OUTPUT"
    if [ -z "$UPWIND_CLIENT_ID" ]; then
      echo "ERROR: UPWIND_CLIENT_ID is empty after retrieval"
      exit 1
    fi
    export UPWIND_CLIENT_ID
    echo "Successfully retrieved UPWIND_CLIENT_ID (length: $${#UPWIND_CLIENT_ID})"
    
    # Get client secret with error checking
    echo "Attempting to retrieve UPWIND_CLIENT_SECRET..."
    if ! CLIENT_SECRET_OUTPUT=$(timeout 30 gcloud secrets versions access latest --secret=${data.google_secret_manager_secret.scanner_client_secret.secret_id} --project=${local.project} 2>&1); then
      echo "ERROR: Failed to retrieve UPWIND_CLIENT_SECRET from Secret Manager"
      echo "Error output: $CLIENT_SECRET_OUTPUT"
      exit 1
    fi
    UPWIND_CLIENT_SECRET="$CLIENT_SECRET_OUTPUT"
    if [ -z "$UPWIND_CLIENT_SECRET" ]; then
      echo "ERROR: UPWIND_CLIENT_SECRET is empty after retrieval"
      exit 1
    fi
    export UPWIND_CLIENT_SECRET
    echo "Successfully retrieved UPWIND_CLIENT_SECRET (length: $${#UPWIND_CLIENT_SECRET})"
    
    export UPWIND_INFRA_REGION=${var.upwind_infra_region}
    export GCP_REGION=${var.region}
    export GCP_CLOUDSCANNER_SA_EMAIL=${local.cloudscanner_sa.email}
    export GCP_CLOUDSCANNER_SCALER_SA_EMAIL=${local.cloudscanner_scaler_sa.email}
    export UPWIND_CLOUDSCANNER_ID=${var.scanner_id}
    
    # Write credentials to file for systemd service (matching regular ASG behavior)
    echo "Writing credentials to /etc/cloudscanner.env for systemd service..."
    mkdir -p /etc
    cat > /etc/cloudscanner.env <<-ENVEOF
UPWIND_CLIENT_ID=$UPWIND_CLIENT_ID
UPWIND_CLIENT_SECRET=$UPWIND_CLIENT_SECRET
UPWIND_INFRA_REGION=$UPWIND_INFRA_REGION
GCP_REGION=$GCP_REGION
GCP_CLOUDSCANNER_SA_EMAIL=$GCP_CLOUDSCANNER_SA_EMAIL
GCP_CLOUDSCANNER_SCALER_SA_EMAIL=$GCP_CLOUDSCANNER_SCALER_SA_EMAIL
UPWIND_CLOUDSCANNER_ID=$UPWIND_CLOUDSCANNER_ID
ENVEOF
    chmod 600 /etc/cloudscanner.env
    echo "Credentials written to /etc/cloudscanner.env"
    
    echo "Environment variables set:"
    echo "  UPWIND_INFRA_REGION=$UPWIND_INFRA_REGION"
    echo "  GCP_REGION=$GCP_REGION"
    echo "  UPWIND_CLOUDSCANNER_ID=$UPWIND_CLOUDSCANNER_ID"

    echo "Getting Cloud Scanner install script for ${var.scanner_id} ..."
    if ! curl -f -L https://get.${var.public_uri_domain}/cloudscanner.sh -o cloudscanner.sh; then
      echo "ERROR: Failed to download install script"
      exit 1
    fi
    
    chmod +x cloudscanner.sh
    echo "Executing Cloud Scanner install for ${var.scanner_id}..."
    if ! UPWIND_IO=${var.public_uri_domain} bash ./cloudscanner.sh; then
      echo "ERROR: Cloud Scanner install failed with exit code $?"
      exit 1
    fi
    
    echo "Cloud Scanner install finished successfully for ${var.scanner_id}..."
    echo "Verifying systemd service exists..."
    if systemctl list-units --all --type service --no-legend | grep -qF "upwind-cloudscanner"; then
      echo "SUCCESS: upwind-cloudscanner service found"
      systemctl status upwind-cloudscanner --no-pager || true
      echo "Service status check complete"
    else
      echo "WARNING: upwind-cloudscanner service not found"
      echo "Checking for service file..."
      if [ -f /etc/systemd/system/upwind-cloudscanner.service ]; then
        echo "Service file exists but service not loaded. Attempting daemon-reload..."
        systemctl daemon-reload || true
        systemctl list-units --all --type service --no-legend | grep -i cloudscanner || echo "Still not found after reload"
      else
        echo "Service file does not exist at /etc/systemd/system/upwind-cloudscanner.service"
      fi
    fi
    echo "=== Installation complete ==="
    echo "Startup log saved to: $LOGFILE"
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
    labels = merge(local.merged_labels, {
      upwind_component = "cloudscanner"
      name             = "upwind-cs-asg-${var.scanner_id}"
    })
  }

  # Setting the initial target size. The number of VMs to be created when the instance group is created.
  target_size = var.target_size

  lifecycle {
    replace_triggered_by = [null_resource.always_run]
  }
}

# DSPM Instance Templates
# Create DSPM instance templates for Data Security Posture Management scanning
# Similar to regular templates but using install_dspm instead of regular install
resource "google_compute_region_instance_template" "cloudscanner_dspm_inst_templates" {
  count        = var.dspm_enabled ? 2 : 0
  project      = local.project
  name_prefix  = "upwind-tpl-dspm-${var.scanner_id}-"
  machine_type = var.machine_type
  region       = var.region

  # Label is used for IsNotCloudScannerInstance
  labels = {
    upwind-component = "cloudscanner-dspm"
  }

  # add tags for SSH
  tags = var.enable_iap_ssh ? ["ssh-enabled"] : []

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    set -o pipefail

    # Log file for debugging
    LOGFILE="/var/log/cloudscanner-startup.log"
    mkdir -p /var/log

    # Redirect all output to both log file and serial console
    # Use tee to write to both, and don't fail if serial console is unavailable
    exec > >(tee -a "$LOGFILE" | (cat >> /dev/ttyS0 2>/dev/null || cat))
    exec 2>&1

    echo "=== Starting DSPM Cloud Scanner installation for ${var.scanner_id} ==="
    echo "Timestamp: $(date)"
    echo "Log file: $LOGFILE"

    # Retrieve credentials from Secret Manager
    echo "Getting upwind credentials from Secret Manager for ${var.scanner_id}..."
    echo "Secret ID for client_id: ${data.google_secret_manager_secret.scanner_client_id.secret_id}"
    echo "Secret ID for client_secret: ${data.google_secret_manager_secret.scanner_client_secret.secret_id}"
    echo "Project: ${local.project}"
    
    # Check if gcloud is available
    if ! command -v gcloud &> /dev/null; then
      echo "ERROR: gcloud command not found"
      exit 1
    fi
    
    # Configure gcloud to use the instance's service account
    echo "Configuring gcloud to use instance service account..."
    gcloud config set account $(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" -H "Metadata-Flavor: Google") 2>&1 || true
    gcloud config set project ${local.project} 2>&1 || true
    
    # Verify we can access the metadata server
    echo "Verifying service account access..."
    SA_EMAIL=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" -H "Metadata-Flavor: Google" 2>&1)
    echo "Service account: $SA_EMAIL"
    
    # Get client ID with error checking
    echo "Attempting to retrieve UPWIND_CLIENT_ID..."
    if ! CLIENT_ID_OUTPUT=$(timeout 30 gcloud secrets versions access latest --secret=${data.google_secret_manager_secret.scanner_client_id.secret_id} --project=${local.project} 2>&1); then
      echo "ERROR: Failed to retrieve UPWIND_CLIENT_ID from Secret Manager"
      echo "Error output: $CLIENT_ID_OUTPUT"
      exit 1
    fi
    UPWIND_CLIENT_ID="$CLIENT_ID_OUTPUT"
    if [ -z "$UPWIND_CLIENT_ID" ]; then
      echo "ERROR: UPWIND_CLIENT_ID is empty after retrieval"
      exit 1
    fi
    export UPWIND_CLIENT_ID
    echo "Successfully retrieved UPWIND_CLIENT_ID (length: $${#UPWIND_CLIENT_ID})"
    
    # Get client secret with error checking
    echo "Attempting to retrieve UPWIND_CLIENT_SECRET..."
    if ! CLIENT_SECRET_OUTPUT=$(timeout 30 gcloud secrets versions access latest --secret=${data.google_secret_manager_secret.scanner_client_secret.secret_id} --project=${local.project} 2>&1); then
      echo "ERROR: Failed to retrieve UPWIND_CLIENT_SECRET from Secret Manager"
      echo "Error output: $CLIENT_SECRET_OUTPUT"
      exit 1
    fi
    UPWIND_CLIENT_SECRET="$CLIENT_SECRET_OUTPUT"
    if [ -z "$UPWIND_CLIENT_SECRET" ]; then
      echo "ERROR: UPWIND_CLIENT_SECRET is empty after retrieval"
      exit 1
    fi
    export UPWIND_CLIENT_SECRET
    echo "Successfully retrieved UPWIND_CLIENT_SECRET (length: $${#UPWIND_CLIENT_SECRET})"
    
    export UPWIND_INFRA_REGION=${var.upwind_infra_region}
    export GCP_REGION=${var.region}
    export GCP_CLOUDSCANNER_SA_EMAIL=${local.cloudscanner_sa.email}
    export GCP_CLOUDSCANNER_SCALER_SA_EMAIL=${local.cloudscanner_scaler_sa.email}
    export UPWIND_CLOUDSCANNER_ID=${var.scanner_id}
    
    # Write credentials to file for systemd service (matching regular ASG behavior)
    echo "Writing credentials to /etc/cloudscanner.env for systemd service..."
    mkdir -p /etc
    cat > /etc/cloudscanner.env <<-ENVEOF
UPWIND_CLIENT_ID=$UPWIND_CLIENT_ID
UPWIND_CLIENT_SECRET=$UPWIND_CLIENT_SECRET
UPWIND_INFRA_REGION=$UPWIND_INFRA_REGION
GCP_REGION=$GCP_REGION
GCP_CLOUDSCANNER_SA_EMAIL=$GCP_CLOUDSCANNER_SA_EMAIL
GCP_CLOUDSCANNER_SCALER_SA_EMAIL=$GCP_CLOUDSCANNER_SCALER_SA_EMAIL
UPWIND_CLOUDSCANNER_ID=$UPWIND_CLOUDSCANNER_ID
ENVEOF
    chmod 600 /etc/cloudscanner.env
    echo "Credentials written to /etc/cloudscanner.env"
    
    echo "Environment variables set:"
    echo "  UPWIND_INFRA_REGION=$UPWIND_INFRA_REGION"
    echo "  GCP_REGION=$GCP_REGION"
    echo "  UPWIND_CLOUDSCANNER_ID=$UPWIND_CLOUDSCANNER_ID"

    echo "Getting Cloud Scanner install script for ${var.scanner_id} ..."
    if ! curl -f -L https://get.${var.public_uri_domain}/cloudscanner.sh -o cloudscanner.sh; then
      echo "ERROR: Failed to download install script"
      exit 1
    fi
    
    chmod +x cloudscanner.sh
    echo "Executing Cloud Scanner DSPM install for ${var.scanner_id}..."
    if ! UPWIND_IO=${var.public_uri_domain} bash ./cloudscanner.sh install_dspm; then
      echo "ERROR: Cloud Scanner DSPM install failed with exit code $?"
      exit 1
    fi
    
    echo "Cloud Scanner DSPM install finished successfully for ${var.scanner_id}..."
    echo "Verifying systemd service exists..."
    if systemctl list-units --all --type service --no-legend | grep -qF "upwind-cloudscanner"; then
      echo "SUCCESS: upwind-cloudscanner service found"
      systemctl status upwind-cloudscanner --no-pager || true
      echo "Service status check complete"
    else
      echo "WARNING: upwind-cloudscanner service not found"
      echo "Checking for service file..."
      if [ -f /etc/systemd/system/upwind-cloudscanner.service ]; then
        echo "Service file exists but service not loaded. Attempting daemon-reload..."
        systemctl daemon-reload || true
        systemctl list-units --all --type service --no-legend | grep -i cloudscanner || echo "Still not found after reload"
      else
        echo "Service file does not exist at /etc/systemd/system/upwind-cloudscanner.service"
      fi
    fi
    echo "=== Installation complete ==="
    echo "Startup log saved to: $LOGFILE"
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

# DSPM Instance Group Manager
resource "google_compute_region_instance_group_manager" "cloudscanner_dspm" {
  count                            = var.dspm_enabled ? 1 : 0
  project                          = local.project
  name                             = "upwind-cs-asg-dspm-${var.scanner_id}"
  base_instance_name               = "upwind-vm-dspm-${var.scanner_id}"
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
    name              = "cloudscanner-dspm"
    instance_template = google_compute_region_instance_template.cloudscanner_dspm_inst_templates[0].id
  }

  all_instances_config {
    labels = merge(local.merged_labels, {
      upwind_component = "cloudscanner-dspm"
      name             = "upwind-cs-asg-dspm-${var.scanner_id}"
    })
  }

  # Setting the initial target size. The number of VMs to be created when the instance group is created.
  target_size = 1

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
# This will be deployed in ONE region only. By default it will be in us-central1 unless overridden by the user.
# Multiple scheduler jobs in the same region will be created if multiple scanners are deployed in the same region.
# Each scheduler job can have a single HTTP target, so we create a separate job for each scanner.
resource "google_cloud_scheduler_job" "scaler_scheduler_job" {
  name     = "upwind-scaler-scheduler-job-${var.scanner_id}"
  region   = var.scheduler_region != "" ? var.scheduler_region : var.default_scheduler_region
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
