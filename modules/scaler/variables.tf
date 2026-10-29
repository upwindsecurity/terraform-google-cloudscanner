### Scaler

variable "name" {
  type        = string
  description = "Name of the scaler Cloud Run job. The Scheduler job is named <name>-scheduler."

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.name))
    error_message = "The name must be 1-63 characters of lowercase letters, digits or hyphens, start with a letter and not end with a hyphen."
  }
}

variable "service_account_email" {
  type        = string
  description = "The service account the scaler runs as, and that Cloud Scheduler uses to start it."
}

variable "client_id_secret" {
  type        = string
  description = "Secret Manager secret id, in var.project, holding the scanner client id."
}

variable "client_secret_secret" {
  type        = string
  description = "Secret Manager secret id, in var.project, holding the scanner client secret."
}

variable "scanner_secret_version" {
  type        = string
  description = "Secret Manager version for the scanner client id/secret mounted into the scaler job. Defaults to \"latest\", so a rotated credential is picked up on the next job execution with no apply. Set to a specific numeric version (e.g. \"3\") only to deliberately pin."
  default     = "latest"

  validation {
    condition     = var.scanner_secret_version == "latest" || can(regex("^[1-9][0-9]*$", var.scanner_secret_version))
    error_message = "The scanner_secret_version must be \"latest\" or a positive integer version number (e.g. \"3\")."
  }
}

variable "scaler_vpc_egress_enabled" {
  type        = bool
  description = "Attach the scaler to its own small VPC with Direct VPC egress for private ranges only. Only needed where a GCP org policy (constraints/run.allowedVPCEgress) requires Cloud Run resources to declare an egress setting: it delays the scaler's startup and holds addresses in the subnet for hours after the scaler is deleted, blocking network teardown."
  default     = false
}

variable "grant_invoker" {
  type        = bool
  description = "Grant the scaler service account roles/run.invoker on the scaler job, so Cloud Scheduler can start it. Leave false where the service account already has it."
  default     = false
}

variable "grant_secret_access" {
  type        = bool
  description = "Grant the scaler service account roles/secretmanager.secretAccessor on the two scanner secrets. Leave false where the service account already has it."
  default     = false
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
  description = "The Upwind infrastructure region where the resources are created."
  default     = "us"

  validation {
    condition     = can(regex("^(ap|us|eu|me|pdc01|pdc02)$", var.upwind_infra_region))
    error_message = "The Upwind infrastructure region must be one of 'us', 'eu', or 'me'"
  }
}

### Google Cloud Related

variable "access_token" {
  description = "An OAuth access token to authenticate with Google Cloud. Leave unset to use the provider's ambient credentials (Application Default Credentials, e.g. from `gcloud auth application-default login` or a CI workload identity)."
  type        = string
  default     = null
  sensitive   = true
}

variable "project" {
  type        = string
  description = "The project the scaler runs in. It scales every scanner config in this project."
}

variable "region" {
  type        = string
  description = "The region for the scaler job and its Scheduler job."
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
