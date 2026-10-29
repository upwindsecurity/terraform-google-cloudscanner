mock_provider "google" {
  override_data {
    target = data.google_project.scanner
    values = {
      number = "123456789"
    }
  }
}
mock_provider "null" {}

variables {
  upwind_organization_id       = "org_abcde"
  scanner_id                   = "ucsc-abc123"
  cloudscanner_sa_email        = "upwind-cs-abcde@proj-a.iam.gserviceaccount.com"
  cloudscanner_scaler_sa_email = "upwind-scaler-abcde@proj-a.iam.gserviceaccount.com"
  upwind_orchestrator_project  = "proj-abc"
}

run "saas_deploys_into_saas_project" {
  command = plan

  variables {
    is_saas      = true
    saas_project = "upwind-saas"
  }

  assert {
    condition = alltrue([
      google_compute_network.cloudscanner_network[0].project == "upwind-saas",
      google_compute_region_instance_template.cloudscanner_inst_templates[0].project == "upwind-saas",
      google_cloud_run_v2_job.scaler_function[0].project == "upwind-saas",
      google_cloud_scheduler_job.scaler_scheduler_job[0].project == "upwind-saas",
    ])
    error_message = "is_saas must deploy every resource into saas_project."
  }

  assert {
    condition = alltrue([for t in concat(google_compute_region_instance_template.cloudscanner_inst_templates, google_compute_region_instance_template.cloudscanner_dspm_inst_templates) :
      strcontains(t.metadata_startup_script, "export GCP_SAAS_WORKER=true\n") &&
      strcontains(t.metadata_startup_script, "export GCP_SAAS_WORKER_PROJECT=upwind-saas\n") &&
      strcontains(t.metadata_startup_script, "export GCP_SAAS_ORCHESTRATOR=proj-abc\n")
    ])
    error_message = "Scanner and DSPM workers must be told the SaaS worker and orchestrator projects."
  }
}

run "saas_requires_saas_project" {
  command = plan

  variables {
    is_saas = true
  }

  expect_failures = [var.saas_project]
}

run "shared_vpc_grants_network_user_on_host_subnet" {
  command = plan

  variables {
    custom_network            = "shared-net"
    custom_subnet             = "shared-subnet"
    network_project           = "host-proj"
    scaler_vpc_egress_enabled = true
  }

  assert {
    condition     = data.google_compute_subnetwork.custom_subnet[0].project == "host-proj" && data.google_compute_network.custom_network[0].project == "host-proj"
    error_message = "The custom network and subnet must be looked up in network_project."
  }

  assert {
    condition = alltrue([for m in [google_compute_subnetwork_iam_member.cloudscanner_network_user[0], google_compute_subnetwork_iam_member.scaler_network_user[0]] :
      m.project == "host-proj" && m.subnetwork == "shared-subnet" && m.role == "roles/compute.networkUser"
    ])
    error_message = "networkUser must be granted on the subnet in the host project."
  }

  assert {
    condition     = google_compute_subnetwork_iam_member.cloudscanner_network_user[0].member == "serviceAccount:123456789@cloudservices.gserviceaccount.com"
    error_message = "The scanner project's Google APIs service agent must get networkUser."
  }

  assert {
    condition     = google_compute_subnetwork_iam_member.scaler_network_user[0].member == "serviceAccount:service-123456789@serverless-robot-prod.iam.gserviceaccount.com"
    error_message = "The scanner project's Cloud Run service agent must get networkUser."
  }
}

run "shared_vpc_skips_scaler_grant_without_vpc_egress" {
  command = plan

  variables {
    custom_network  = "shared-net"
    custom_subnet   = "shared-subnet"
    network_project = "host-proj"
  }

  assert {
    condition     = length(google_compute_subnetwork_iam_member.cloudscanner_network_user) == 1 && length(google_compute_subnetwork_iam_member.scaler_network_user) == 0
    error_message = "The Cloud Run agent only needs networkUser when the scaler uses Direct VPC egress."
  }
}

run "same_project_network_needs_no_grant" {
  command = plan

  variables {
    custom_network            = "shared-net"
    custom_subnet             = "shared-subnet"
    network_project           = "proj-abc"
    scaler_vpc_egress_enabled = true
  }

  assert {
    condition     = length(google_compute_subnetwork_iam_member.cloudscanner_network_user) == 0 && length(google_compute_subnetwork_iam_member.scaler_network_user) == 0
    error_message = "No networkUser grant is needed when the network lives in the scanner project."
  }
}
