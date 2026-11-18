# The cleaner's own network, only for Direct VPC egress. Nothing else is attached to it, so
# its range never meets a customer range.
resource "google_compute_network" "cleaner" {
  count = var.cleaner_vpc_egress_enabled ? 1 : 0

  name                    = var.name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cleaner" {
  count = var.cleaner_vpc_egress_enabled ? 1 : 0

  name          = var.name
  region        = var.region
  network       = google_compute_network.cleaner[0].id
  ip_cidr_range = "10.10.0.0/26"
}
