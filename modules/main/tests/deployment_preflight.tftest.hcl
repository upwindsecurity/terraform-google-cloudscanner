mock_provider "google" {
  override_during = plan
}

mock_provider "null" {
  override_during = plan
}

variables {
  access_token                  = "test-token"
  upwind_organization_id       = "org_test123"
  scanner_id                   = "ucsc-12345678"
  cloudscanner_sa_email        = "cloudscanner@test-project.iam.gserviceaccount.com"
  cloudscanner_scaler_sa_email = "scaler@test-project.iam.gserviceaccount.com"
  upwind_orchestrator_project  = "test-project"
}

run "accepts_consistent_managed_network_configuration" {
  command = plan
}

run "rejects_zone_outside_configured_region" {
  command = plan

  variables {
    availability_zones = ["europe-west4-a"]
  }

  expect_failures = [
    output.gcp_asg_name,
  ]
}

run "rejects_subnet_without_custom_network" {
  command = plan

  variables {
    custom_subnet = "scanner-subnet"
  }

  expect_failures = [
    output.gcp_asg_name,
  ]
}

run "rejects_cloudscanner_service_account_from_another_project" {
  command = plan

  variables {
    cloudscanner_sa_email = "cloudscanner@other-project.iam.gserviceaccount.com"
  }

  expect_failures = [
    data.google_service_account.cloudscanner_sa,
  ]
}

run "rejects_scaler_service_account_from_another_project" {
  command = plan

  variables {
    cloudscanner_scaler_sa_email = "scaler@other-project.iam.gserviceaccount.com"
  }

  expect_failures = [
    data.google_service_account.cloudscanner_scaler_sa,
  ]
}

run "accepts_custom_subnet_attached_to_selected_network" {
  command = plan

  variables {
    custom_network = "customer-vpc"
    custom_subnet  = "scanner-subnet"
  }

  override_data {
    target = data.google_compute_network.custom_network[0]
    values = {
      name      = "customer-vpc"
      self_link = "https://www.googleapis.com/compute/v1/projects/test-project/global/networks/customer-vpc"
    }
  }

  override_data {
    target = data.google_compute_subnetwork.custom_subnet[0]
    values = {
      network = "https://www.googleapis.com/compute/v1/projects/test-project/global/networks/customer-vpc"
    }
  }
}

run "rejects_custom_subnet_attached_to_different_network" {
  command = plan

  variables {
    custom_network = "customer-vpc"
    custom_subnet  = "scanner-subnet"
  }

  override_data {
    target = data.google_compute_network.custom_network[0]
    values = {
      name      = "customer-vpc"
      self_link = "https://www.googleapis.com/compute/v1/projects/test-project/global/networks/customer-vpc"
    }
  }

  override_data {
    target = data.google_compute_subnetwork.custom_subnet[0]
    values = {
      network = "https://www.googleapis.com/compute/v1/projects/test-project/global/networks/other-vpc"
    }
  }

  expect_failures = [
    data.google_compute_subnetwork.custom_subnet,
  ]
}
