resource "google_service_account" "zdm_sa" {
  count        = var.create_service_account ? 1 : 0
  account_id   = "${var.instance_name}-sa"
  display_name = "Service Account for ZDM Node VM"
  project      = var.project_id
}

resource "google_project_iam_member" "logging" {
  count   = var.create_service_account ? 1 : 0
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.zdm_sa[0].email}"
}

resource "google_project_iam_member" "monitoring" {
  count   = var.create_service_account ? 1 : 0
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.zdm_sa[0].email}"
}

resource "google_compute_instance" "zdm_vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["zdm-node"]

  boot_disk {
    initialize_params {
      image = "oracle-cloud-os-images/oracle-linux-8"
      size  = 100
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_name
    # No access_config block means no public IP is created (highly secure)
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_integrity_monitoring = true
    enable_vtpm                 = true
  }

  metadata = {
    ssh-keys = "zdmuser:${var.ssh_public_key}"
    startup-script = templatefile("${path.module}/templates/startup.sh.tpl", {
      zdm_software_bucket = var.zdm_software_bucket
      zdm_software_zip    = var.zdm_software_zip
      install_docker      = var.install_docker
    })
  }

  service_account {
    email  = var.create_service_account ? google_service_account.zdm_sa[0].email : "${var.instance_name}-sa@${var.project_id}.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }
}
