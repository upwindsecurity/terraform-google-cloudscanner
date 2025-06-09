data "google_service_account" "cloudscanner_sa" {
  project    = local.project
  account_id = split("@", var.cloudscanner_sa_email)[0]
}

data "google_service_account" "cloudscanner_scaler_sa" {
  project    = local.project
  account_id = split("@", var.cloudscanner_scaler_sa_email)[0]
}

locals {
  cloudscanner_storage_delete_role                  = format("projects/%s/roles/Cloud ScannerStorageDeleteRole_%s", local.project, local.resource_suffix_underscore)
  cloudscanner_instance_template_mgmt_role          = format("projects/%s/roles/Cloud ScannerInstTmplMgmtRole_%s", local.project, local.resource_suffix_underscore)
  cloudscanner_instance_template_test_creation_role = format("projects/%s/roles/Cloud ScannerInstTmplTestCreationRole_%s", local.project, local.resource_suffix_underscore)
}

resource "google_project_iam_binding" "cloudscanner_storage_delete_role_binding" {
  project = local.project
  role    = local.cloudscanner_storage_delete_role
  members = [
    "serviceAccount:${local.cloudscanner_sa.email}",       # Cloud Scanner VMs
    "serviceAccount:${local.cloudscanner_scaler_sa.email}" # Cloud Scanner Scaler (Cloud Run)"
  ]

  condition {
    # Limit storage deletion permissions to snapshots and disks we generate only
    title      = "Upwind Cloud Scanner Storage Deletion"
    expression = "resource.name.endsWith('${var.scanner_id}')"
  }
}

# Create the role binding to allow management of instances templates
resource "google_project_iam_binding" "cloudscanner_instance_template_mgmt_binding" {
  project = local.project
  role    = local.cloudscanner_instance_template_mgmt_role
  members = [
    "serviceAccount:${local.cloudscanner_scaler_sa.email}" # Cloud Scanner Scaler (Cloud Run)"
  ]

  condition {
    # Limit the use of the roles to cloudscanner only instance templates
    title      = "Upwind Cloud Scanner Instance Template Management"
    expression = "resource.name.startsWith('projects/${local.project}/regions/${var.region}/instanceTemplates/upwind-tpl-${var.scanner_id}-')"
  }
}

resource "google_project_iam_binding" "cloudscanner_instance_template_test_creation_binding" {
  project = local.project
  role    = local.cloudscanner_instance_template_test_creation_role
  members = [
    "serviceAccount:${local.cloudscanner_scaler_sa.email}" # Cloud Scanner Scaler (Cloud Run)"
  ]

  condition {
    # Upgrading templates performs a 'dry-run' of instance creation, limit to resources using this pattern
    title      = "Upwind Cloud Scanner Instance Template Upgrade"
    expression = "resource.name.endsWith('${var.scanner_id}-0000')"
  }
}
