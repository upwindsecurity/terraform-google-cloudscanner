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
  cloudscanner_snapshot_reader_role                 = format("projects/%s/roles/CloudScannerSnapshotReader_%s", local.project, local.resource_suffix_underscore)
  cloudscanner_snapshot_writer_role                 = format("projects/%s/roles/CloudScannerSnapshotWriter_%s", local.project, local.resource_suffix_underscore)
  cloudscanner_instance_template_mgmt_role          = format("projects/%s/roles/Cloud ScannerInstTmplMgmtRole_%s", local.project, local.resource_suffix_underscore)
  cloudscanner_instance_template_test_creation_role = format("projects/%s/roles/Cloud ScannerInstTmplTestCreationRole_%s", local.project, local.resource_suffix_underscore)
}

resource "google_project_iam_member" "cloudscanner_storage_delete_role_member" {
  project = local.project
  role    = local.cloudscanner_storage_delete_role
  member  = "serviceAccount:${local.cloudscanner_sa.email}"

  condition {
    # Limit storage deletion permissions to snapshots and disks we generate only
    title      = "Upwind Cloud Scanner Storage Deletion"
    expression = "resource.name.endsWith('${var.scanner_id}')"
  }
}

resource "google_project_iam_member" "cloudscanner_scaler_storage_delete_role_member" {
  project = local.project
  role    = local.cloudscanner_storage_delete_role
  member  = "serviceAccount:${local.cloudscanner_scaler_sa.email}"

  condition {
    # Limit storage deletion permissions to snapshots and disks we generate only
    title      = "Upwind Cloud Scanner Scaler Storage Deletion"
    expression = "resource.name.endsWith('${var.scanner_id}')"
  }
}

resource "google_project_iam_member" "cloudscanner_snapshot_reader_role_member" {
  project = local.project
  role    = local.cloudscanner_snapshot_reader_role
  member  = "serviceAccount:${local.cloudscanner_sa.email}"
}

resource "google_project_iam_member" "cloudscanner_snapshot_writer_role_member" {
  project = local.project
  role    = local.cloudscanner_snapshot_writer_role
  member  = "serviceAccount:${local.cloudscanner_sa.email}"
  condition {
    # Limit storage deletion permissions to snapshots and disks we generate only
    title      = "Upwind CloudScanner Snapshot Writer"
    expression = "resource.name.endsWith('${var.scanner_id}')"
  }
}

resource "google_project_iam_member" "cloudscanner_scaler_snapshot_reader_role_member" {
  project = local.project
  role    = local.cloudscanner_snapshot_reader_role
  member  = "serviceAccount:${local.cloudscanner_scaler_sa.email}"
}

resource "google_project_iam_member" "cloudscanner_scaler_snapshot_writer_role_member" {
  project = local.project
  role    = local.cloudscanner_snapshot_writer_role
  member  = "serviceAccount:${local.cloudscanner_scaler_sa.email}"
  condition {
    # Limit storage deletion permissions to snapshots and disks we generate only
    title      = "Upwind CloudScanner Scaler Snapshot Writer"
    expression = "resource.name.endsWith('${var.scanner_id}')"
  }
}

# Create the role binding to allow management of instances templates
resource "google_project_iam_member" "cloudscanner_instance_template_mgmt_member" {
  project = local.project
  role    = local.cloudscanner_instance_template_mgmt_role
  member  = "serviceAccount:${local.cloudscanner_scaler_sa.email}" # Cloud Scanner Scaler (Cloud Run)"

  condition {
    # Limit the use of the roles to cloudscanner only instance templates
    title      = "Upwind Cloud Scanner Instance Template Management"
    expression = "resource.name.startsWith('projects/${local.project}/regions/${var.region}/instanceTemplates/upwind-tpl-${var.scanner_id}-')"
  }
}

resource "google_project_iam_member" "cloudscanner_instance_template_test_creation_member" {
  project = local.project
  role    = local.cloudscanner_instance_template_test_creation_role
  member  = "serviceAccount:${local.cloudscanner_scaler_sa.email}" # Cloud Scanner Scaler (Cloud Run)"

  condition {
    # Upgrading templates performs a 'dry-run' of instance creation, limit to resources using this pattern
    title      = "Upwind Cloud Scanner Instance Template Upgrade"
    expression = "resource.name.endsWith('${var.scanner_id}-0000')"
  }
}
