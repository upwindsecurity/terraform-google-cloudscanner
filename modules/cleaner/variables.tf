### Cleaner

variable "name" {
  type        = string
  description = "Name of the cleaner Cloud Run job. The Scheduler job is named <name>-scheduler."

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.name))
    error_message = "The name must be 1-63 characters of lowercase letters, digits or hyphens, start with a letter and not end with a hyphen."
  }
}

variable "service_account_email" {
  type        = string
  description = "The service account the cleaner runs as, and that Cloud Scheduler uses to start it: the customer's hub account."
}

variable "client_id_secret" {
  type        = string
  description = "Secret Manager secret id, in var.project, holding the Upwind client id."
}

variable "client_secret_secret" {
  type        = string
  description = "Secret Manager secret id, in var.project, holding the Upwind client secret."
}

variable "secret_version" {
  type        = string
  description = "Secret Manager version for the client id/secret. Defaults to \"latest\", so a rotated credential is picked up on the next run with no apply."
  default     = "latest"

  validation {
    condition     = var.secret_version == "latest" || can(regex("^[1-9][0-9]*$", var.secret_version))
    error_message = "The secret_version must be \"latest\" or a positive integer version number (e.g. \"3\")."
  }
}

variable "dry_run" {
  type        = bool
  description = "Report what would be deleted and delete nothing."
  default     = false
}

variable "grant_invoker" {
  type        = bool
  description = "Grant the service account roles/run.invoker on the cleaner job, so Cloud Scheduler can start it. Leave false where the service account already has it."
  default     = false
}

variable "vpc_egress" {
  type = object({
    network    = string
    subnetwork = string
  })
  description = "Network and subnetwork ids for Direct VPC egress (private ranges only), where a GCP org policy (constraints/run.allowedVPCEgress) requires Cloud Run resources to declare an egress setting. Null for no VPC egress."
  default     = null
}

### Upwind Related

variable "public_uri_domain" {
  type        = string
  description = "The public URI domain."
  default     = "upwind.io"

  validation {
    condition     = contains(["upwind.io", "upwind.dev"], var.public_uri_domain)
    error_message = "The public_uri_domain must be either 'upwind.io' or 'upwind.dev'."
  }
}

variable "upwind_infra_region" {
  type        = string
  description = "The Upwind infrastructure region the cleaner reports to."
  default     = "us"
}

### Google Cloud Related

variable "access_token" {
  description = "The access token used to authenticate with Google Cloud."
  type        = string
  sensitive   = true
}

variable "project" {
  type        = string
  description = "The scanner project the cleaner runs in and cleans."
}

variable "region" {
  type        = string
  description = "The region for the cleaner job and its Scheduler job."
  default     = "us-central1"
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
    error_message = "Label keys must be 1-63 characters and label values must be 0-63 characters of lowercase letters, numbers, underscores, or hyphens."
  }
}

variable "default_labels" {
  description = "Default labels applied to all resources (can be overridden)"
  type        = map(string)
  default = {
    managed_by = "terraform"
    component  = "upwind"
  }
}
