terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# 1. Primary Compute VM for Oracle Target Database
resource "google_compute_instance" "oracle_target" {
  name         = var.instance_name
  project      = var.project_id
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["oracle-target-db"]

  boot_disk {
    initialize_params {
      image = "oracle-cloud-os-images/oracle-database-19-3-ol8" # Official Oracle Linux 8 image
      size  = 50
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnet_name
    # No public IP assigned - Private network architecture
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_integrity_monitoring = true
    enable_vtpm                 = true
  }

  metadata_startup_script = templatefile("${path.module}/templates/db_startup.sh.tpl", {})

  metadata = {
    ssh-keys = "oracle:${var.ssh_public_key}"
  }

  # Ensure attached disks are not destroyed when VM is re-provisioned
  lifecycle {
    ignore_changes = [attached_disk]
  }
}

# 2. Block Storage Disk for /u01 Oracle Installation Binaries
resource "google_compute_disk" "u01_disk" {
  name    = "${var.instance_name}-u01"
  project = var.project_id
  type    = "pd-balanced"
  zone    = var.zone
  size    = var.u01_disk_size
}

resource "google_compute_attached_disk" "u01_attach" {
  device_name = "oracle-u01"
  disk        = google_compute_disk.u01_disk.id
  instance    = google_compute_instance.oracle_target.id
  zone        = var.zone
}

# 3. Block Storage Disk for Oracle Datafiles (DATA)
resource "google_compute_disk" "data_disk" {
  name    = "${var.instance_name}-data"
  project = var.project_id
  type    = "pd-ssd" # High-performance SSD for database execution
  zone    = var.zone
  size    = var.data_disk_size
}

resource "google_compute_attached_disk" "data_attach" {
  device_name = "oracle-data"
  disk        = google_compute_disk.data_disk.id
  instance    = google_compute_instance.oracle_target.id
  zone        = var.zone
}

# 4. Block Storage Disk for Redo Logs & Recovery (RECO)
resource "google_compute_disk" "reco_disk" {
  name    = "${var.instance_name}-reco"
  project = var.project_id
  type    = "pd-balanced"
  zone    = var.zone
  size    = var.reco_disk_size
}

resource "google_compute_attached_disk" "reco_attach" {
  device_name = "oracle-reco"
  disk        = google_compute_disk.reco_disk.id
  instance    = google_compute_instance.oracle_target.id
  zone        = var.zone
}
