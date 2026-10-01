resource "google_compute_network" "vpc" {
  count                   = var.create_networking ? 1 : 0
  name                    = var.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  count                    = var.create_networking ? 1 : 0
  name                     = var.subnet_name
  project                  = var.project_id
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = var.create_networking ? google_compute_network.vpc[0].id : "projects/${var.project_id}/global/networks/${var.network_name}"
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "odb_subnet" {
  count                    = var.create_odb_subnet && var.create_networking ? 1 : 0
  name                     = var.odb_subnet_name
  project                  = var.project_id
  ip_cidr_range            = var.odb_subnet_cidr
  region                   = var.region
  network                  = var.create_networking ? google_compute_network.vpc[0].id : "projects/${var.project_id}/global/networks/${var.network_name}"
  private_ip_google_access = true
}

# Allow SSH to ZDM VM (from public or restricted sources)
resource "google_compute_firewall" "allow_ssh_to_zdm" {
  count   = var.create_networking ? 1 : 0
  name    = "${var.network_name}-allow-ssh-to-zdm"
  network = var.create_networking ? google_compute_network.vpc[0].name : var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["zdm-node"]
  source_ranges = ["0.0.0.0/0"] # In production, restrict this CIDR
}

# Allow ZDM Service Node to connect via SSH and SQL*Net to Source & Target Databases
resource "google_compute_firewall" "zdm_to_databases" {
  count   = var.create_networking ? 1 : 0
  name    = "${var.network_name}-zdm-to-databases"
  network = var.create_networking ? google_compute_network.vpc[0].name : var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22", "1521", "1522"]
  }

  source_tags = ["zdm-node"]
  target_tags = ["oracle-source-db", "oracle-target-db"]

  # Fallback to CIDRs if tags are not used
  source_ranges = concat(
    [var.subnet_cidr],
    var.create_odb_subnet ? [var.odb_subnet_cidr] : [],
    var.source_db_ips,
    var.target_db_ips
  )
}

# Allow Oracle Data Guard traffic between Source and Target Databases on port 1521
resource "google_compute_firewall" "dataguard_replication" {
  count   = var.create_networking ? 1 : 0
  name    = "${var.network_name}-dataguard-replication"
  network = var.create_networking ? google_compute_network.vpc[0].name : var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["1521"]
  }

  source_tags = ["oracle-source-db", "oracle-target-db"]
  target_tags = ["oracle-source-db", "oracle-target-db"]

  source_ranges = concat(var.source_db_ips, var.target_db_ips)
}

# Allow ZDM internal loopback / control ports (if needed internally within the VPC)
resource "google_compute_firewall" "zdm_control" {
  count   = var.create_networking ? 1 : 0
  name    = "${var.network_name}-zdm-control"
  network = var.create_networking ? google_compute_network.vpc[0].name : var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8900", "8897", "8898"]
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["zdm-node"]
}
