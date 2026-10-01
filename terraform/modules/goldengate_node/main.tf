terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_compute_instance" "ogg_instance" {
  name         = var.instance_name
  project      = var.project_id
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["goldengate-node"]

  boot_disk {
    initialize_params {
      image = "oracle-cloud-os-images/oracle-database-19-3-ol8" # Or standard OL8 image
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

  metadata_startup_script = templatefile("${path.module}/templates/ogg_startup.sh.tpl", {})

  metadata = {
    ssh-keys = "ogguser:${var.ssh_public_key}"
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }
}

resource "google_compute_disk" "ogg_disk" {
  name    = "${var.instance_name}-storage"
  project = var.project_id
  type    = "pd-ssd"
  zone    = var.zone
  size    = var.disk_size
}

resource "google_compute_attached_disk" "ogg_disk_attach" {
  device_name = "ogg-disk"
  disk        = google_compute_disk.ogg_disk.id
  instance    = google_compute_instance.ogg_instance.id
  zone        = var.zone
}
