data "google_secret_manager_secret" "scanner_client_id" {
  project   = local.project
  secret_id = "upwind-scanner-client-id-${local.resource_suffix_hyphen}"
}

data "google_secret_manager_secret" "scanner_client_secret" {
  project   = local.project
  secret_id = "upwind-scanner-client-secret-${local.resource_suffix_hyphen}"
}

data "google_secret_manager_secret_version" "scanner_client_id_v1" {
  project = local.project
  secret  = data.google_secret_manager_secret.scanner_client_id.secret_id
}

data "google_secret_manager_secret_version" "scanner_client_secret_v1" {
  project = local.project
  secret  = data.google_secret_manager_secret.scanner_client_secret.secret_id
}
