# The scaler's own network, only for Direct VPC egress. Nothing else is attached to it, so
# its range never meets a customer range. Deleting it can be blocked for 1-2 hours after
# the job is deleted, while Cloud Run still holds its egress addresses.
resource "google_compute_network" "scaler" {
  count = var.scaler_vpc_egress_enabled ? 1 : 0

  name                    = var.name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "scaler" {
  count = var.scaler_vpc_egress_enabled ? 1 : 0

  name          = var.name
  region        = var.region
  network       = google_compute_network.scaler[0].id
  ip_cidr_range = "10.10.0.0/26"
}
