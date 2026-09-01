output "gcp_asg_name" {
  description = "The name of the Cloud Scanner Instance Manager Group."
  value       = google_compute_region_instance_group_manager.cloudscanner.name

  precondition {
    condition = alltrue([
      for zone in var.availability_zones : startswith(zone, "${var.region}-")
    ])
    error_message = "Cloud Scanner preflight failed: every availability_zones entry must belong to region ${var.region}. Received: ${join(", ", var.availability_zones)}."
  }

  precondition {
    condition     = var.custom_subnet == "" || var.custom_network != ""
    error_message = "Cloud Scanner preflight failed: custom_subnet requires custom_network. Set both values to use customer-managed networking, or leave both empty to let the module create the network."
  }
}

output "gcp_dspm_asg_name" {
  description = "The name of the Cloud Scanner DSPM Instance Manager Group."
  value       = var.dspm_enabled ? google_compute_region_instance_group_manager.cloudscanner_dspm[0].name : ""
}
