output "gcp_asg_name" {
  description = "The name of the Cloud Scanner Instance Manager Group."
  value       = google_compute_region_instance_group_manager.cloudscanner.name
}
