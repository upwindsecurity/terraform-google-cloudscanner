locals {
  subnet_ip_cidr_range = "192.168.16.0/20"
}

data "google_compute_network" "custom_network" {
  count   = var.custom_network != "" ? 1 : 0
  project = local.project
  name    = var.custom_network
}

data "google_compute_subnetwork" "custom_subnet" {
  count   = var.custom_network != "" && var.custom_subnet != "" ? 1 : 0
  project = local.project
  name    = var.custom_subnet
  region  = var.region
}

resource "google_compute_network" "cloudscanner_network" {
  count                   = var.custom_network == "" ? 1 : 0
  project                 = local.project
  name                    = "upwind-network-${var.scanner_id}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cloudscanner_subnetwork" {
  count         = var.custom_network == "" ? 1 : 0
  project       = local.project
  name          = "upwind-subnet-${var.scanner_id}"
  network       = google_compute_network.cloudscanner_network[0].self_link
  ip_cidr_range = local.subnet_ip_cidr_range
  region        = var.region
}

resource "google_compute_router" "cloudscanner_router" {
  count   = var.custom_network == "" ? 1 : 0
  project = local.project
  name    = "upwind-router-${var.scanner_id}"
  network = google_compute_network.cloudscanner_network[0].self_link
  region  = var.region
}

resource "google_compute_router_nat" "cloudscanner_router_nat" {
  count                              = var.custom_network == "" ? 1 : 0
  project                            = local.project
  name                               = "upwind-nat-${var.scanner_id}"
  router                             = google_compute_router.cloudscanner_router[0].name
  region                             = google_compute_router.cloudscanner_router[0].region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  min_ports_per_vm                   = var.min_nat_ports_per_vm
  subnetwork {
    name                    = google_compute_subnetwork.cloudscanner_subnetwork[0].id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "cloudscanner_fw_iap_ssh" {
  count     = var.enable_iap_ssh ? 1 : 0
  project   = local.project
  name      = "upwind-fw-${var.scanner_id}-iap-ssh"
  network   = local.network
  direction = "INGRESS"

  # Allow SSH from IAP ranges only
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Allow IAP forwarding only (not public IP addresses)
  source_ranges = ["35.235.240.0/20"]

  # Target specific instances
  target_tags = ["ssh-enabled"]
  priority    = 1000
}
