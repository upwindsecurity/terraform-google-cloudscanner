output "cloudscanner_asg_name" {
  description = "The name of the Cloud Scanner Auto Scaling Group"
  value       = module.cloudscanner_basic.gcp_asg_name
}
