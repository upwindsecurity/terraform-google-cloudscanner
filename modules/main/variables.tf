### Upwind Related

variable "upwind_organization_id" {
  type        = string
  description = "The Upwind Organization ID."

  validation {
    condition     = can(regex("^org_[a-zA-Z0-9]{1,}$", var.upwind_organization_id))
    error_message = "The Upwind organization ID must start with 'org_' followed by alphanumeric characters."
  }
}

variable "scanner_id" {
  type        = string
  description = "The Upwind Scanner ID."

  validation {
    condition     = can(regex("^ucsc-[a-zA-Z0-9]{1,}$", var.scanner_id))
    error_message = "The Upwind scanner ID must start with 'ucsc-' followed by alphanumeric characters."
  }
}

variable "public_uri_domain" {
  type        = string
  description = "The public URI domain."
  default     = "upwind.io"

  validation {
    condition     = contains(["upwind.io", "upwind.dev"], var.public_uri_domain)
    error_message = "The public_uri_domain must be either 'upwind.io' or 'upwind.dev'."
  }
}

variable "scaler_function_schedule" {
  type        = string
  description = "The schedule to use for the scaler function."
  default     = "*/10 * * * *" # Every 10 minutes
}

variable "upwind_infra_region" {
  type        = string
  description = "The Upwind infrastructure region where the resources are created."
  default     = "us"

  validation {
    condition     = can(regex("^(us|eu|me|pdc01)$", var.upwind_infra_region))
    error_message = "The Upwind infrastructure region must be one of 'us', 'eu', or 'me'"
  }
}

### Google Cloud Related

variable "access_token" {
  description = "The access token used to authenticate with Google Cloud."
  type        = string
  sensitive   = true
}

variable "cloudscanner_sa_email" {
  type        = string
  description = "The cloudscanner service account email to use."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+@[a-zA-Z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.cloudscanner_sa_email))
    error_message = "Invalid Google service account email format. Must be in the format: name@project-id.iam.gserviceaccount.com"
  }
}

variable "cloudscanner_scaler_sa_email" {
  type        = string
  description = "The cloudscanner scaler service account email to use."
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+@[a-zA-Z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.cloudscanner_scaler_sa_email))
    error_message = "Invalid Google service account email format. Must be in the format: name@project-id.iam.gserviceaccount.com"
  }
}

variable "upwind_orchestrator_project" {
  type        = string
  description = "The main Google Cloud project where the resources are created."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.upwind_orchestrator_project))
    error_message = "The Upwind orchestrator project ID must be 6-30 characters, lowercase letters, numbers or hyphens, must start with a letter, and cannot end with a hyphen."
  }
}

variable "region" {
  type        = string
  description = "The region that all resources will be created in."
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "The region must be a valid Google Cloud region (e.g., us-central1, europe-west4)."
  }
}

variable "availability_zones" {
  type        = list(any)
  description = "The zones within the region that will be used for zone based resources."
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "At least one availability zone must be specified."
  }

  validation {
    condition     = alltrue([for zone in var.availability_zones : can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", zone))])
    error_message = "All availability zones must be valid Google Cloud zones (e.g., us-central1-a)."
  }

  validation {
    condition     = length(var.availability_zones) == length(distinct(var.availability_zones))
    error_message = "All availability zones must be unique."
  }
}

### Scheduler related
locals {
  # Supported Scheduler regions, see https://cloud.google.com/scheduler/docs/locations
  valid_scheduler_regions = [
    # Americas
    "northamerica-northeast1", "southamerica-east1",
    "us-central1", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4",

    # Europe
    "europe-central2", "europe-west1", "europe-west2", "europe-west3", "europe-west6",

    # Asia Pacific
    "asia-east1", "asia-east2", "asia-northeast1", "asia-northeast2", "asia-northeast3",
    "asia-south1", "asia-southeast1", "asia-southeast2",

    # Australia
    "australia-southeast1"
  ]
}

variable "default_scheduler_region" {
  type        = string
  description = "The default region to use for the Cloud Scheduler job if no specific region is provided."
  default     = "us-central1"

  validation {
    condition     = contains(local.valid_scheduler_regions, var.default_scheduler_region)
    error_message = "The default scheduler region must be a valid Cloud Scheduler region. Supported regions: ${join(", ", local.valid_scheduler_regions)}."
  }
}

variable "scheduler_region" {
  type        = string
  description = "The region to use for the Cloud Scheduler job. If not set, the default_scheduler_region will be used."
  default     = ""

  validation {
    condition     = var.scheduler_region == "" || contains(local.valid_scheduler_regions, var.scheduler_region)
    error_message = "The scheduler region must be a valid Cloud Scheduler region. Supported regions: ${join(", ", local.valid_scheduler_regions)}, or leave empty to use default."
  }
}

### Instance Group Related

variable "machine_type" {
  type        = string
  description = "The machine type to use."
  default     = "e2-highmem-2"
}

variable "boot_image" {
  type        = string
  description = "The source image to use for instances."
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "boot_disk_size_gb" {
  type        = number
  description = "The disk size in GB to use."
  default     = 40
}

variable "boot_disk_type" {
  type        = string
  description = "The disk type to use."
  default     = "pd-standard"
}

variable "target_size" {
  type        = number
  description = "The target size of the autoscaling group."
  default     = 1
}

variable "dspm_enabled" {
  type        = bool
  description = "Enable DSPM (Data Security Posture Management). If false, DSPM MIG will not be created."
  default     = false
}

### Network related

variable "custom_network" {
  description = "The name of a custom network to use."
  type        = string
  default     = ""
}

variable "custom_subnet" {
  description = "The name of a custom subnetwork to use."
  type        = string
  default     = ""
}

variable "enable_iap_ssh" {
  description = "Whether to enable SSH access via IAP"
  type        = bool
  default     = true
}

variable "min_nat_ports_per_vm" {
  description = "Minimum number of ports allocated to each VM for NAT service"
  type        = number
  default     = 64
}

variable "labels" {
  description = "A map of labels to apply to all resources"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.labels :
      can(regex("^[a-z0-9_-]{1,63}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Invalid labels found: ${join(", ", [for k, v in var.labels : !can(regex("^[a-z0-9_-]{1,63}$", k)) || !can(regex("^[a-z0-9_-]{0,63}$", v)) ? "'${k}=${v}'" : ""])}. Label keys must be 1-63 characters and label values must be 0-63 characters of lowercase letters, numbers, underscores, or hyphens."
  }
}

variable "default_labels" {
  description = "Default labels applied to all resources (can be overridden)"
  type        = map(string)
  default = {
    managed_by = "terraform"
    component  = "upwind"
  }
  validation {
    condition = alltrue([
      for k, v in var.default_labels :
      can(regex("^[a-z0-9_-]{1,63}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Invalid default labels found: ${join(", ", [for k, v in var.default_labels : !can(regex("^[a-z0-9_-]{1,63}$", k)) || !can(regex("^[a-z0-9_-]{0,63}$", v)) ? "'${k}=${v}'" : ""])}. Label keys must be 1-63 characters and label values must be 0-63 characters of lowercase letters, numbers, underscores, or hyphens."
  }
}
