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
  fs_disks = [
    {
      auto_delete  = true
      boot         = false
      device_name  = "oracle_home"
      disk_size_gb = var.oracle_home_disk.size_gb
      disk_type    = var.oracle_home_disk.type
      disk_labels  = { purpose = "software" } # Do not modify this label
    }
  ]
  asm_disks = [
    {
      auto_delete  = true
      boot         = false
      device_name  = "data"
      disk_size_gb = var.data_disk.size_gb
      disk_type    = var.data_disk.type
      disk_labels  = { diskgroup = "data", purpose = "asm" }
    },
    {
      auto_delete  = true
      boot         = false
      device_name  = "reco"
      disk_size_gb = var.reco_disk.size_gb
      disk_type    = var.reco_disk.type
      disk_labels  = { diskgroup = "reco", purpose = "asm" }
    },
    {
      auto_delete  = true
      boot         = false
      device_name  = "swap"
      disk_size_gb = var.swap_disk_size_gb
      disk_type    = var.swap_disk_type
      disk_labels  = { purpose = "swap" }
    }
  ]

  # Takes the list of filesystem disks and converts them into a list of objects with the required fields by ansible
  data_mounts_config = [
    for i, d in local.fs_disks : {
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
    for g in distinct([for d in local.asm_disks : d.disk_labels.diskgroup if lookup(d.disk_labels, "diskgroup", null) != null]) : {
      diskgroup = upper(g)
      disks = [
        for d in local.asm_disks : {
          blk_device = "/dev/disk/by-id/google-${d.device_name}"
          name       = d.device_name
        } if lookup(d.disk_labels, "diskgroup", null) == g
      ]
    }
  ]

  # Concatenetes both lists to be passed down to the instance module
  additional_disks = concat(local.fs_disks, local.asm_disks)

  project_id = var.project_id
}

module "instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 13.0"

  name_prefix        = format("%s-template", var.instance_name)
  region             = var.region
  project_id         = local.project_id
  network            = coalesce(var.network, var.subnetwork)
  subnetwork         = coalesce(var.subnetwork, var.network)
  subnetwork_project = local.project_id
  service_account = {
    email  = var.vm_service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  machine_type         = var.machine_type
  source_image_family  = var.source_image_family
  source_image_project = var.source_image_project
  disk_size_gb         = var.boot_disk_size_gb
  disk_type            = var.boot_disk_type
  auto_delete          = true


  metadata = {
    metadata_startup_script = var.metadata_startup_script
    enable-oslogin          = "TRUE"
  }

  additional_disks = local.additional_disks

  tags = var.network_tags
}

module "compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 13.0"

  region              = var.region
  zone                = var.zone
  network            = coalesce(var.network, var.subnetwork)
  subnetwork         = coalesce(var.subnetwork, var.network)
  subnetwork_project  = local.project_id
  hostname            = var.instance_name
  instance_template   = module.instance_template.self_link
  deletion_protection = false

  access_config = var.assign_public_ip ? [{
    nat_ip       = null
    network_tier = "PREMIUM"
  }] : []
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_compute_instance" "control_node" {
  project      = var.project_id
  name         = "${var.control_node_name_prefix}-${random_id.suffix.hex}"
  machine_type = var.control_node_machine_type
  zone         = var.zone

  scheduling {
    max_run_duration {
      seconds = 604800
    }
    instance_termination_action = "DELETE"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network            = coalesce(var.network, var.subnetwork)
    subnetwork         = coalesce(var.subnetwork, var.network)
    subnetwork_project = local.project_id

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
    gcs_source = var.gcs_source
    instance_name = module.compute_instance.instances_details[0].name
    instance_zone = module.compute_instance.instances_details[0].zone
    ip_addr = module.compute_instance.instances_details[0].network_interface[0].network_ip
    asm_disk_config = jsonencode(local.asm_disk_config)
    data_mounts_config = jsonencode(local.data_mounts_config)
    swap_blk_device = "/dev/disk/by-id/google-swap"
    ora_swlib_bucket = var.ora_swlib_bucket
    ora_version = var.ora_version
    ora_backup_dest = var.ora_backup_dest
    ora_db_name = var.ora_db_name
    ora_db_container = var.ora_db_container
    ntp_pref = var.ntp_pref
    ora_release = var.ora_release
    ora_edition = var.ora_edition
    ora_listener_port = var.ora_listener_port
    ora_redo_log_size = var.ora_redo_log_size
    db_password_secret = var.db_password_secret
    install_workload_agent = var.install_workload_agent
    oracle_metrics_secret = var.oracle_metrics_secret
    skip_database_config = var.skip_database_config
    ora_pga_target_mb = var.ora_pga_target_mb
    ora_sga_target_mb = var.ora_sga_target_mb
    deployment_name = var.deployment_name
  })

  metadata = {
    enable-oslogin = "TRUE"
  }

  depends_on = [module.compute_instance]
}

output "control_node_log_url" {
  description = "Logs Explorer URL with Oracle Toolkit output"
  value       = "https://console.cloud.google.com/logs/query;query=resource.labels.instance_id%3D${urlencode(google_compute_instance.control_node.instance_id)};duration=P30D?project=${urlencode(var.project_id)}"
}

