mock_provider "google" {}
mock_provider "null" {}

variables {
  upwind_organization_id       = "org_abcde"
  scanner_id                   = "ucsc-abc123"
  cloudscanner_sa_email        = "upwind-cs-abcde@proj-a.iam.gserviceaccount.com"
  cloudscanner_scaler_sa_email = "upwind-scaler-abcde@proj-a.iam.gserviceaccount.com"
  upwind_orchestrator_project  = "proj-abc"
  dspm_enabled                 = true
}

run "workers_block_project_ssh_keys" {
  command = plan

  assert {
    condition = length(concat(google_compute_region_instance_template.cloudscanner_inst_templates, google_compute_region_instance_template.cloudscanner_dspm_inst_templates)) == 4 && alltrue([
      for t in concat(google_compute_region_instance_template.cloudscanner_inst_templates, google_compute_region_instance_template.cloudscanner_dspm_inst_templates) :
      t.metadata["block-project-ssh-keys"] == "TRUE" && t.metadata["enable-oslogin"] == "TRUE"
    ])
    error_message = "Scanner and DSPM worker templates must set block-project-ssh-keys and enable-oslogin to TRUE."
  }
}

# Projects enforcing constraints/compute.disableSerialPortAccess reject a VM that enables the
# interactive serial console, and the MIG creates workers after apply, so the deploy still succeeds.
run "workers_leave_serial_port_access_off" {
  command = plan

  assert {
    condition = alltrue([
      for t in concat(google_compute_region_instance_template.cloudscanner_inst_templates, google_compute_region_instance_template.cloudscanner_dspm_inst_templates) :
      !contains(keys(t.metadata), "serial-port-enable")
    ])
    error_message = "Scanner and DSPM worker templates must not set serial-port-enable."
  }
}
