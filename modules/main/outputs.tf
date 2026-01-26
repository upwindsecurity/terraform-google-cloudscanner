output "gcp_asg_name" {
  description = "The name of the Cloud Scanner Instance Manager Group."
  value       = google_compute_region_instance_group_manager.cloudscanner.name
}

output "gcp_dspm_asg_name" {
  description = "The name of the Cloud Scanner DSPM Instance Manager Group."
  value       = var.dspm_enabled ? google_compute_region_instance_group_manager.cloudscanner_dspm[0].name : ""
}
