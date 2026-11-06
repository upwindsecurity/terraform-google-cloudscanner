output "service_name" {
  description = "Name of the volume-vetter Cloud Run service."
  value       = google_cloud_run_v2_service.vetter.name
}

output "service_uri" {
  description = "The vetter service's URI."
  value       = google_cloud_run_v2_service.vetter.uri
}

output "trigger_id" {
  description = "Resource id of the Eventarc trigger on compute.disks.insert."
  value       = google_eventarc_trigger.disks_insert.id
}
