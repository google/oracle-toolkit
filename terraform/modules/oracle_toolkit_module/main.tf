# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  # Takes the list of filesystem disks and converts them into a list of objects with the required fields by ansible
  data_mounts_config = [
    for i, d in var.fs_disks : {
      purpose     = d.disk_labels.purpose
      blk_device  = "/dev/disk/by-id/google-${d.device_name}"
      name        = format("u%02d", i + 1)
      fstype      = "xfs"
      mount_point = format("/u%02d", i + 1)
      mount_opts  = "nofail"
    }
  ]

  # Takes the list of asm disks and converts them into a list of objects with the required fields by ansible
  asm_disk_config = [
    for g in distinct([for d in var.asm_disks : d.disk_labels.diskgroup if lookup(d.disk_labels, "diskgroup", null) != null]) : {
      diskgroup = upper(g)
      disks = [
        for d in var.asm_disks : {
          blk_device = "/dev/disk/by-id/google-${d.device_name}"
          name       = d.device_name
        } if lookup(d.disk_labels, "diskgroup", null) == g
      ]
    }
  ]

  # Concatenetes both lists to be passed down to the instance module
  additional_disks = concat(var.fs_disks, var.asm_disks)

  project_id = var.project_id
}

module "instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 13.0"

  name_prefix        = format("%s-template", var.instance_name)
  region             = var.region
  project_id         = local.project_id
  subnetwork         = var.subnetwork
  subnetwork_project = local.project_id
  service_account = {
    email  = var.vm_service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  machine_type         = var.machine_type
  source_image_family  = var.source_image_family
  source_image_project = var.source_image_project
  disk_size_gb         = var.os_disk_size
  disk_type            = var.os_disk_type
  auto_delete          = true


  metadata = {
    metadata_startup_script = var.metadata_startup_script
  }

  additional_disks = local.additional_disks

  tags = var.network_tags
}

module "compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 13.0"

  region              = var.region
  zone                = var.zone
  subnetwork          = var.subnetwork
  subnetwork_project  = local.project_id
  hostname            = var.instance_name
  instance_template   = module.instance_template.self_link
  deletion_protection = false

  access_config = [
    {
      nat_ip       = null
      network_tier = "PREMIUM"
    }
  ]
}

# Archive the directory containing oracle-toolkit (one level above current path)
data "archive_file" "oracle_toolkit_zip" {
  type        = "zip"
  source_dir  = ".."
  output_path = "/tmp/oracle-toolkit.zip"
}

# Upload the Ansible archive to the GCS bucket provided by the user
resource "google_storage_bucket_object" "upload_archive" {
  name   = "oracle-toolkit.zip"
  bucket = var.gcs_source
  source = data.archive_file.oracle_toolkit_zip.output_path
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_compute_instance" "control_node" {
  project      = var.project_id
  name         = "${var.control_node_name_prefix}-${random_id.suffix.hex}"
  machine_type = var.control_node_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network       = var.subnetwork

    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }

  service_account {
    email  = var.control_node_service_account
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/scripts/setup.sh.tpl", {
    bucket_name         = var.gcs_source
    instance_name       = module.compute_instance.instances_details[0].name
    instance_zone       = module.compute_instance.instances_details[0].zone
    ip_addr             = module.compute_instance.instances_details[0].network_interface[0].network_ip
    asm_disk_config     = jsonencode(local.asm_disk_config)
    data_mounts_config  = jsonencode(local.data_mounts_config)
    swap_blk_device     = "/dev/disk/by-id/google-swap"
    ora_swlib_bucket    = var.ora_swlib_bucket
    ora_version         = var.ora_version
    ora_backup_dest     = var.ora_backup_dest
    ora_db_name         = var.ora_db_name
    ora_db_container    = lower(var.ora_db_container)
    ntp_pref            = var.ntp_pref
    oracle_release      = var.oracle_release
    ora_edition         = var.ora_edition
    ora_listener_port   = var.ora_listener_port
    ora_redo_log_size   = var.ora_redo_log_size
  })

  depends_on = [module.compute_instance, google_storage_bucket_object.upload_archive]
}
