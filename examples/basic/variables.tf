# This file is intentionally empty but required by TFLint for standard module structure

variable "upwind_organization_id" {
  type        = string
  description = "The Upwind Organization ID"
}

variable "scanner_id" {
  type        = string
  description = "The Upwind Scanner ID"
}

variable "cloudscanner_sa_email" {
  type        = string
  description = "The cloudscanner service account email to use"
}

variable "cloudscanner_scaler_sa_email" {
  type        = string
  description = "The cloudscanner scaler service account email to use"
}

variable "upwind_orchestrator_project" {
  type        = string
  description = "The main Google Cloud project where the resources are created"
}
