### Volume vetter

variable "name" {
  type        = string
  description = "Name of the volume-vetter Cloud Run service. The Eventarc trigger is named <name>-disks-insert."

  validation {
    # Leave room for the "-disks-insert" (13 char) trigger suffix within Eventarc's 63-char limit.
    condition     = can(regex("^[a-z]([-a-z0-9]{0,48}[a-z0-9])?$", var.name))
    error_message = "The name must be 1-50 characters of lowercase letters, digits or hyphens, start with a letter and not end with a hyphen."
  }
}

variable "service_account_email" {
  type        = string
  description = "The service account the vetter runs as, and that the Eventarc trigger uses to deliver events: the customer's hub account. It verifies with the signing key's public half, which roles/cloudkms.signerVerifier already grants it, so no extra KMS grant is made here."
}

variable "sign_key" {
  type        = string
  description = "The KMS cryptoKey resource the worker signs scan-volume claims with (projects/P/locations/L/keyRings/R/cryptoKeys/K). The vetter resolves each token's version public key under it. Empty switches the vetter off."
}

variable "customer_sa" {
  type        = string
  description = "The customer's inward-granted service account. Only compute.disks.insert events whose principal is this SA are assessed."
}

### Log shipping to CloudScanner (so the vetter's verdicts reach Upwind's central logging / OpenSearch)

variable "client_id_secret" {
  type        = string
  description = "Secret Manager secret id, in var.project, holding the Upwind client id. The vetter runs as the hub account, which already reads these through the scaler's grant, so no extra IAM is made here."
}

variable "client_secret_secret" {
  type        = string
  description = "Secret Manager secret id, in var.project, holding the Upwind client secret."
}

variable "secret_version" {
  type        = string
  description = "Secret Manager version for the client id/secret. Defaults to \"latest\", so a rotated credential is picked up on the next cold start with no apply."
  default     = "latest"

  validation {
    condition     = var.secret_version == "latest" || can(regex("^[1-9][0-9]*$", var.secret_version))
    error_message = "The secret_version must be \"latest\" or a positive integer version number (e.g. \"3\")."
  }
}

variable "dry_run" {
  type        = bool
  description = "Report what would be deleted and delete nothing. Defaults true: a new deletion control starts in report-only until the signing rollout is confirmed."
  default     = true
}

variable "grant_invoker" {
  type        = bool
  description = "Grant the service account roles/run.invoker on the vetter service, so its Eventarc trigger can invoke it. Leave false where the service account already has it."
  default     = false
}

variable "grant_event_receiver" {
  type        = bool
  description = "Grant the service account roles/eventarc.eventReceiver on the project, so its Eventarc trigger can receive events. Leave false where the service account already has it."
  default     = false
}

### Upwind Related

variable "public_uri_domain" {
  type        = string
  description = "The public URI domain. Selects the prod or dev container image, and prefixes the log-shipping region on upwind.dev."
  default     = "upwind.io"

  validation {
    condition     = contains(["upwind.io", "upwind.dev"], var.public_uri_domain)
    error_message = "The public_uri_domain must be either 'upwind.io' or 'upwind.dev'."
  }
}

variable "upwind_infra_region" {
  type        = string
  description = "The Upwind infrastructure region the vetter ships its logs to. A go-common/region name; on upwind.dev it is prefixed with 'dev-'. Constant for the deployment, not the GCP region of a disk."
  default     = "us"
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
  description = "The scanner project the vetter runs in and protects."
}

variable "region" {
  type        = string
  description = "The region for the vetter service. The Eventarc trigger is global, so it catches disk creations in any region."
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
