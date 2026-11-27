locals {
  cleaner_nat = var.cleaner_vpc_egress_enabled && var.cleaner_vpc_egress == "ALL_TRAFFIC"
}

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

# All-traffic egress sends Google API and Upwind calls through this network too, so it needs NAT.
# Private-ranges egress reaches them directly and needs none.
resource "google_compute_router" "cleaner" {
  count = local.cleaner_nat ? 1 : 0

  name    = var.name
  region  = var.region
  network = google_compute_network.cleaner[0].id
}

resource "google_compute_router_nat" "cleaner" {
  count = local.cleaner_nat ? 1 : 0

  name                               = var.name
  router                             = google_compute_router.cleaner[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.cleaner[0].id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
