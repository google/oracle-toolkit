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
  # Mode helper
  is_fs              = upper(var.ora_disk_mgmt) == "FS"
  ora_disk_mgmt_flag = upper(var.ora_disk_mgmt)

  # Storage backend helper. When "gcnv", the u01 (Oracle binaries) and DATA/RECO
  # disk groups are served by Google Cloud NetApp Volumes iSCSI LUNs (presented
  # as /dev/mapper/* by the iscsi-multipath role) instead of attached Hyperdisks.
  # Only swap (and the GCE boot disk) remain on Hyperdisk in GCNV mode, since
  # the OS must be running to reach an iSCSI LUN and swapping over the network is
  # unsafe.
  is_gcnv = lower(var.storage_backend) == "gcnv"

  # GCNV LUNs are bound to deterministic DM-Multipath aliases of the form
  # /dev/mapper/<deployment>_<name> (e.g. /dev/mapper/orcl_data). These
  # device_names are sourced from GCNV; everything else (swap) stays on Hyperdisk.
  gcnv_alias_prefix = replace(lower(local.deployment_id), "-", "_")
  gcnv_lun_devices  = ["oracle_home", "data", "reco"]

  # Base disk definitions (do not change device_name values)
  _u01 = {
    auto_delete  = true
    device_name  = "oracle_home"
    disk_size_gb = var.oracle_home_disk.size_gb
    disk_type    = var.oracle_home_disk.type
    disk_labels  = { purpose = "software" }
  }

  # DATA / RECO in ASMUDEV and ASMLIB mode (with disk groups)
  _data_asm = {
    auto_delete  = true
    device_name  = "data"
    disk_size_gb = var.data_disk.size_gb
    disk_type    = var.data_disk.type
    disk_labels  = { diskgroup = "data", purpose = "asm" }
  }
  _reco_asm = {
    auto_delete  = true
    device_name  = "reco"
    disk_size_gb = var.reco_disk.size_gb
    disk_type    = var.reco_disk.type
    disk_labels  = { diskgroup = "reco", purpose = "asm" }
  }

  # DATA / RECO in FS mode
  _data_fs = {
    auto_delete  = true
    device_name  = "data"
    disk_size_gb = var.data_disk.size_gb
    disk_type    = var.data_disk.type
    disk_labels  = { purpose = "data" }
  }
  _reco_fs = {
    auto_delete  = true
    device_name  = "reco"
    disk_size_gb = var.reco_disk.size_gb
    disk_type    = var.reco_disk.type
    disk_labels  = { purpose = "reco" }
  }

  _swap = {
    auto_delete  = true
    device_name  = "swap"
    disk_size_gb = var.swap_disk_size_gb
    disk_type    = var.swap_disk_type
    disk_labels  = { purpose = "swap" }
  }

  # Build lists based on mode
  # Filesystem disks (participate in XFS mounts via data_mounts_config)
  fs_disks = concat(
    [
      local._u01
    ],
    local.is_fs ? [local._data_fs, local._reco_fs] : []
  )

  asm_disks = concat(
    local.is_fs ? [] : [local._data_asm, local._reco_asm],
    [local._swap]
  )

  # DBCA destinations
  data_dest = local.is_fs ? "/u02/oradata" : "DATA"
  reco_dest = local.is_fs ? "/u03/fast_recovery_area" : "RECO"

  # Takes the list of filesystem disks and converts them into a list of objects with the required fields by ansible
  data_mounts_config = [
    for i, d in local.fs_disks : {
      purpose     = d.disk_labels.purpose
      blk_device  = local.blk_device_for[d.device_name]
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
          blk_device = local.blk_device_for[d.device_name]
          name       = d.device_name
        } if lookup(d.disk_labels, "diskgroup", null) == g
      ]
    }
  ]

  # Resolves the block-device path for every logical disk. GCNV DATA/RECO map to
  # their deterministic /dev/mapper alias; all other disks (and the entire
  # Hyperdisk backend) keep the existing /dev/disk/by-id/google-* path.
  blk_device_for = {
    for d in concat(local.fs_disks, local.asm_disks) :
    d.device_name => (
      (local.is_gcnv && contains(local.gcnv_lun_devices, d.device_name))
      ? "/dev/mapper/${local.gcnv_alias_prefix}_${d.device_name}"
      : "/dev/disk/by-id/google-${d.device_name}"
    )
  }

  # Concatenetes both lists to be passed down to the instance module. In GCNV
  # mode the u01/DATA/RECO devices live on iSCSI LUNs, so they are not attached
  # as Hyperdisks (only swap remains; the boot disk is separate).
  additional_disks = [
    for d in concat(local.fs_disks, local.asm_disks) : d
    if !(local.is_gcnv && contains(local.gcnv_lun_devices, d.device_name))
  ]

  # Storage pool enabled if either auto-create is requested OR existing pools are mapped
  storage_pool_enabled = (var.create_storage_pool != null && try(var.create_storage_pool.enabled, false)) || length(var.existing_storage_pools) > 0

  # Only create new pools if create is enabled AND no existing pools are mapped
  create_pool_enabled = var.create_storage_pool != null && try(var.create_storage_pool.enabled, false) && length(var.existing_storage_pools) == 0

  # When pool is enabled the template creates no additional inline disks; they are attached separately
  effective_additional_disks = local.storage_pool_enabled ? [] : local.additional_disks

  project_id = var.project_id

  subnetwork1_opt = var.subnetwork1 != "" ? var.subnetwork1 : null
  subnetwork2_opt = var.subnetwork2 != "" ? var.subnetwork2 : null

  is_multi_instance = (var.zone1 != "" && var.zone2 != "")

  instances = (local.is_multi_instance ? {
    "${var.instance_name}-1" = {
      zone       = var.zone1
      subnetwork = local.subnetwork1_opt
      role       = "primary"
    }
    "${var.instance_name}-2" = {
      zone       = var.zone2
      subnetwork = local.subnetwork2_opt
      role       = "standby"
    }
    } : {
    "${var.instance_name}-1" = {
      zone       = var.zone1
      subnetwork = local.subnetwork1_opt
      role       = "primary"
    }
  })

  deployment_id = var.deployment_name != "" ? var.deployment_name : var.instance_name
  db_tag        = "ora-db-${local.deployment_id}"
  control_tag   = "ora-control-node-${local.deployment_id}"

  # Cartesian product: VM × disk — drives google_compute_disk and google_compute_attached_disk when pool is enabled
  # key uses hyphens (valid GCP resource name); device_name keeps the original value for /dev/disk/by-id/ paths
  pool_disk_instances = local.storage_pool_enabled ? {
    for entry in flatten([
      for vm_name, vm in local.instances : [
        for disk in local.additional_disks : {
          key          = "${vm_name}-${replace(disk.device_name, "_", "-")}"
          vm_name      = vm_name
          zone         = vm.zone
          device_name  = disk.device_name
          disk_type    = disk.disk_type
          disk_size_gb = disk.disk_size_gb
          disk_labels  = disk.disk_labels
        }
      ]
    ]) : entry.key => entry
  } : {}
}

# Resolves info for the primary subnetwork (explicit or default)
data "google_compute_subnetwork" "subnetwork1_info" {
  self_link = (local.subnetwork1_opt != null ?
    "https://www.googleapis.com/compute/v1/${local.subnetwork1_opt}" :
    "https://www.googleapis.com/compute/v1/projects/${var.project_id}/regions/${local.region}/subnetworks/default"
  )
}

# Resolves info for the standby subnetwork if in multi-instance mode
data "google_compute_subnetwork" "subnetwork2_info" {
  count = local.is_multi_instance ? 1 : 0
  self_link = (local.subnetwork2_opt != null ?
    "https://www.googleapis.com/compute/v1/${local.subnetwork2_opt}" :
    "https://www.googleapis.com/compute/v1/projects/${var.project_id}/regions/${join("-", slice(split("-", var.zone2), 0, 2))}/subnetworks/default"
  )
}

locals {
  network = local.subnetwork1_opt == null ? "projects/${var.project_id}/global/networks/default" : data.google_compute_subnetwork.subnetwork1_info.network
  # Derive region from zone1 (e.g., us-central1-b -> us-central1)
  region = join("-", slice(split("-", var.zone1), 0, 2))

  # VPC network name for GCNV PSA / host groups. Prefer an explicit override,
  # otherwise take the last path segment of the resolved network self_link.
  gcnv_network_name = (
    var.gcnv_network_name != "" ? var.gcnv_network_name :
    element(split("/", local.network), length(split("/", local.network)) - 1)
  )

  os_repo_types = ["baseos", "appstream"]

  os_upstreams = {
    "oracle-linux-8" = {
      "baseos"    = "https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/x86_64"
      "appstream" = "https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64"
    }
    "oracle-linux-9" = {
      "baseos"    = "https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64"
      "appstream" = "https://yum.oracle.com/repo/OracleLinux/OL9/appstream/x86_64"
    }
  }
}

data "google_compute_image" "os_image" {
  family  = var.source_image_family
  project = var.source_image_project
}

resource "time_static" "template_suffix" {}

locals {
  template_suffix = formatdate("YYYYMMDDhhmmss", time_static.template_suffix.rfc3339)
}

resource "google_compute_instance_template" "default" {
  name         = "${var.instance_name}-${local.template_suffix}"
  project      = var.project_id
  machine_type = var.machine_type

  network_interface {
    subnetwork = local.subnetwork1_opt
    network    = local.subnetwork1_opt == null ? "projects/${var.project_id}/global/networks/default" : null
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = data.google_compute_image.os_image.self_link
    disk_type    = var.boot_disk_type
    disk_size_gb = var.boot_disk_size_gb
  }

  dynamic "disk" {
    for_each = local.effective_additional_disks
    content {
      boot         = false
      auto_delete  = disk.value.auto_delete
      device_name  = disk.value.device_name
      disk_size_gb = disk.value.disk_size_gb
      disk_type    = disk.value.disk_type
      labels       = disk.value.disk_labels
    }
  }

  service_account {
    email  = var.vm_service_account
    scopes = ["cloud-platform"]
  }

  metadata = {
    metadata_startup_script = var.metadata_startup_script
    enable-oslogin          = "TRUE"
    enable_tls              = var.enable_tls
  }

  tags = concat([local.db_tag], var.network_tags)
}

resource "google_compute_instance_from_template" "database_vm" {
  for_each = local.instances

  name                     = each.key
  zone                     = each.value.zone
  project                  = var.project_id
  source_instance_template = google_compute_instance_template.default.self_link

  network_interface {
    # Provide one of: subnetwork (preferred) OR default network
    subnetwork = each.value.subnetwork
    network    = each.value.subnetwork == null ? "projects/${var.project_id}/global/networks/default" : null

    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }
}

# -----------------------------------------------------------------------------
# Hyperdisk Storage Pool (optional)
# -----------------------------------------------------------------------------

resource "google_compute_storage_pool" "zone1" {
  count   = local.create_pool_enabled ? 1 : 0
  project = var.project_id
  name    = "${var.instance_name}-pool-z1"
  zone    = var.zone1

  storage_pool_type             = "projects/${var.project_id}/zones/${var.zone1}/storagePoolTypes/${var.create_storage_pool.storage_pool_type}"
  capacity_provisioning_type    = var.create_storage_pool.capacity_provisioning_type
  deletion_protection           = var.create_storage_pool.deletion_protection
  performance_provisioning_type = var.create_storage_pool.performance_provisioning_type
  pool_provisioned_capacity_gb  = var.create_storage_pool.pool_provisioned_capacity_gb
  pool_provisioned_iops         = var.create_storage_pool.storage_pool_type == "hyperdisk-balanced" ? var.create_storage_pool.pool_provisioned_iops : null
  pool_provisioned_throughput   = var.create_storage_pool.pool_provisioned_throughput
}

resource "google_compute_storage_pool" "zone2" {
  count   = (local.create_pool_enabled && local.is_multi_instance) ? 1 : 0
  project = var.project_id
  name    = "${var.instance_name}-pool-z2"
  zone    = var.zone2

  storage_pool_type             = "projects/${var.project_id}/zones/${var.zone2}/storagePoolTypes/${var.create_storage_pool.storage_pool_type}"
  capacity_provisioning_type    = var.create_storage_pool.capacity_provisioning_type
  deletion_protection           = var.create_storage_pool.deletion_protection
  performance_provisioning_type = var.create_storage_pool.performance_provisioning_type
  pool_provisioned_capacity_gb  = var.create_storage_pool.pool_provisioned_capacity_gb
  pool_provisioned_iops         = var.create_storage_pool.storage_pool_type == "hyperdisk-balanced" ? var.create_storage_pool.pool_provisioned_iops : null
  pool_provisioned_throughput   = var.create_storage_pool.pool_provisioned_throughput
}

resource "google_compute_disk" "pool_disks" {
  for_each = local.pool_disk_instances
  project  = var.project_id
  name     = each.key
  zone     = each.value.zone
  type     = each.value.disk_type
  size     = each.value.disk_size_gb
  labels   = each.value.disk_labels

  storage_pool = (
    length(var.existing_storage_pools) > 0
    ? lookup(var.existing_storage_pools, each.value.zone, null)
    : (
      each.value.zone == var.zone1
      ? one(google_compute_storage_pool.zone1[*].id)
      : one(google_compute_storage_pool.zone2[*].id)
    )
  )
}

resource "google_compute_attached_disk" "pool_disks" {
  for_each    = local.pool_disk_instances
  project     = var.project_id
  disk        = google_compute_disk.pool_disks[each.key].self_link
  instance    = google_compute_instance_from_template.database_vm[each.value.vm_name].self_link
  zone        = each.value.zone
  device_name = each.value.device_name
}

# -----------------------------------------------------------------------------
# Google Cloud NetApp Volumes (GCNV) storage backend (storage_backend = "gcnv")
# PSA peering + Flex pool + iSCSI LUNs + Host Groups, all provisioned in a
# single Terraform run. Each Host Group is created with a placeholder IQN
# (since a VM's real initiator IQN only exists after it boots) and its LUNs
# are attached to it immediately. During host prep, the gcnv-provision Ansible
# role reads each VM's real IQN and updates its Host Group via the NetApp API;
# Terraform ignores drift on that field so the update sticks. All resources
# are gated on local.is_gcnv, so the gce-pd path is untouched.
# -----------------------------------------------------------------------------
module "gcnv_psa" {
  count  = (local.is_gcnv && var.gcnv_create_psa) ? 1 : 0
  source = "./modules/gcnv_psa"

  create_psa         = true
  network_project_id = var.gcnv_network_project_id != "" ? var.gcnv_network_project_id : var.project_id
  network_name       = local.gcnv_network_name
  psa_range_name     = var.gcnv_psa_range_name
  psa_prefix_length  = var.gcnv_psa_prefix_length
  psa_reserved_cidr  = var.gcnv_psa_reserved_cidr
}

module "netapp_iscsi" {
  count  = local.is_gcnv ? 1 : 0
  source = "./modules/netapp_iscsi"

  depends_on = [module.gcnv_psa]

  name_prefix                = local.deployment_id
  pool_name                  = var.gcnv_pool_name != "" ? var.gcnv_pool_name : "${local.deployment_id}-flex-pool"
  pool_location              = var.gcnv_pool_location != "" ? var.gcnv_pool_location : var.zone1
  pool_capacity_gib          = var.gcnv_pool_capacity_gib
  pool_service_level         = var.gcnv_pool_service_level
  pool_type                  = var.gcnv_pool_type
  custom_performance_enabled = var.gcnv_custom_performance_enabled
  total_throughput_mibps     = var.gcnv_total_throughput_mibps
  total_iops                 = var.gcnv_total_iops
  host_os_type               = var.gcnv_host_os_type

  project_id         = var.project_id
  network_name       = local.gcnv_network_name
  network_project_id = var.gcnv_network_project_id != "" ? var.gcnv_network_project_id : var.project_id

  # One u01/DATA/RECO LUN set per database node, keyed to match local.instances.
  # Each node gets its own Host Group (placeholder IQN) with its LUNs attached;
  # the gcnv-provision Ansible role authorizes the real IQN during host prep.
  storage_node_keys = toset(keys(local.instances))
  lun_layout = {
    oracle_home = var.oracle_home_disk.size_gb
    data        = var.data_disk.size_gb
    reco        = var.reco_disk.size_gb
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  database_vm_nodes = [
    for vm in google_compute_instance_from_template.database_vm : {
      name = vm.name
      zone = vm.zone
      ip   = vm.network_interface[0].network_ip
      role = local.instances[vm.name].role
    }
  ]

  ar_repo_url_prefix = var.enable_ar_repo ? "https://${local.region}-yum.pkg.dev/remote/${var.project_id}/${local.deployment_id}" : ""

  # Per-host GCNV map consumed by the iscsi-multipath role, keyed by each DB
  # VM's name (== Ansible inventory_hostname, via --instance-hostname). The
  # gcnv-provision role (run just before iscsi-multipath) authorizes the host's
  # real IQN on its Host Group first, so this role only needs to (1)
  # discover/login the iSCSI portals and (2) bind each LUN's multipath WWID to
  # its /dev/mapper alias. The NetApp LUN multipath WWID is "3600a0980" + the
  # block device identifier (LUN serial).
  gcnv_host_map = local.is_gcnv ? {
    for k, v in local.instances :
    google_compute_instance_from_template.database_vm[k].name => {
      portals = distinct(flatten([
        for vk, m in module.netapp_iscsi[0].iscsi_mount :
        split(",", m.ip_address)
        if startswith(vk, "${k}-") && try(m.ip_address, null) != null
      ]))
      multipath_aliases = [
        for vk, m in module.netapp_iscsi[0].iscsi_mount : {
          wwid  = "3600a0980${m.identifier}"
          alias = "${local.gcnv_alias_prefix}_${trimprefix(vk, "${k}-")}"
        } if startswith(vk, "${k}-") && try(m.identifier, null) != null
      ]
    }
  } : {}

  # Per-node GCNV fulfillment plan consumed by the gcnv-provision Ansible role.
  # For each DB VM it carries everything the role needs to update that node's
  # Host Group (already created by Terraform with a placeholder IQN, and
  # already attached to the node's LUNs) with the VM's real initiator IQN.
  gcnv_fulfillment = local.is_gcnv ? [
    for k, v in local.instances : {
      name          = google_compute_instance_from_template.database_vm[k].name
      zone          = google_compute_instance_from_template.database_vm[k].zone
      host_group    = module.netapp_iscsi[0].host_group_names[k]
      region        = local.region
      pool_location = module.netapp_iscsi[0].storage_pool_location
      project       = var.project_id
      os_type       = var.gcnv_host_os_type
      block_devices = [
        for vk, m in module.netapp_iscsi[0].iscsi_mount : {
          volume       = m.volume_name
          block_device = m.block_device_name
        } if startswith(vk, "${k}-")
      ]
    }
  ] : []

  common_flags = join(" ", compact([
    "--storage-backend ${var.storage_backend}",
    local.is_gcnv ? "--gcnv-host-map-json '${jsonencode(local.gcnv_host_map)}'" : "",
    local.is_gcnv ? "--gcnv-fulfillment-json '${jsonencode(local.gcnv_fulfillment)}'" : "",
    local.ora_disk_mgmt_flag != "" ? "--ora-disk-mgmt ${local.ora_disk_mgmt_flag}" : "",
    length(local.asm_disk_config) > 0 ? "--ora-asm-disks-json '${jsonencode(local.asm_disk_config)}'" : "",
    length(local.data_mounts_config) > 0 ? "--ora-data-mounts-json '${jsonencode(local.data_mounts_config)}'" : "",
    # Keep DBCA destinations aligned with the computed mode
    "--ora-data-destination ${local.data_dest}",
    "--ora-reco-destination ${local.reco_dest}",
    "--swap-blk-device /dev/disk/by-id/google-swap",
    var.ora_swlib_bucket != "" ? "--ora-swlib-bucket ${var.ora_swlib_bucket}" : "",
    var.ora_version != "" ? "--ora-version ${var.ora_version}" : "",
    var.ora_backup_dest != "" ? "--backup-dest ${var.ora_backup_dest}" : "",
    var.ora_db_name != "" ? "--ora-db-name ${var.ora_db_name}" : "",
    var.ora_db_unique_name != "" ? "--ora-db-unique-name ${var.ora_db_unique_name}" : "",
    var.ora_db_domain != "" ? "--ora-db-domain ${var.ora_db_domain}" : "",
    var.ora_db_container != "" ? "--ora-db-container ${var.ora_db_container}" : "",
    var.ntp_pref != "" ? "--ntp-pref ${var.ntp_pref}" : "",
    var.ora_release != "" ? "--ora-release ${var.ora_release}" : "",
    var.ora_edition != "" ? "--ora-edition ${var.ora_edition}" : "",
    var.ora_listener_port != "" ? "--ora-listener-port ${var.ora_listener_port}" : "",
    var.ora_redo_log_size != "" ? "--ora-redo-log-size ${var.ora_redo_log_size}" : "",
    var.ora_redo_log_count != "" ? "--ora-redo-log-count ${var.ora_redo_log_count}" : "",
    var.ora_redo_log_location != "" ? "--ora-redo-log-location '${var.ora_redo_log_location}'" : "",
    var.db_password_secret != "" ? "--db-password-secret ${var.db_password_secret}" : "",
    var.oracle_metrics_secret != "" ? "--oracle-metrics-secret ${var.oracle_metrics_secret}" : "",
    var.install_workload_agent ? "--install-workload-agent" : "",
    var.skip_database_config ? "--skip-database-config" : "",
    var.ora_pga_target_mb != "" ? "--ora-pga-target-mb ${var.ora_pga_target_mb}" : "",
    var.ora_sga_target_mb != "" ? "--ora-sga-target-mb ${var.ora_sga_target_mb}" : "",
    var.data_guard_protection_mode != "" ? "--data-guard-protection-mode '${var.data_guard_protection_mode}'" : "",
    var.enable_tls ? "--tls-secret DYNAMIC_MAPPED" : "",
    var.enable_tls && var.tls_listener_port != "" ? "--tls-listener-port ${var.tls_listener_port}" : "",
    local.ar_repo_url_prefix != "" ? "--ar-repo-url '${local.ar_repo_url_prefix}'" : ""
  ]))
}

# The control node runs install-oracle.sh.
resource "google_compute_instance" "control_node" {
  project      = var.project_id
  name         = "${var.control_node_name_prefix}-${random_id.suffix.hex}"
  machine_type = var.control_node_machine_type
  zone         = var.zone1

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
    subnetwork         = local.subnetwork1_opt
    network            = local.subnetwork1_opt == null ? "projects/${var.project_id}/global/networks/default" : null
    subnetwork_project = local.subnetwork1_opt != null ? local.project_id : null

    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }

  service_account {
    email  = var.control_node_service_account
    scopes = ["cloud-platform"]
  }

  lifecycle {
    precondition {
      condition = (
        (local.is_fs && (var.ora_backup_dest == "" || can(regex("^/.*$", var.ora_backup_dest))))
        ||
        (!local.is_fs && (var.ora_backup_dest == "" || can(regex("^\\+.*$", var.ora_backup_dest)) || can(regex("^/.*$", var.ora_backup_dest))))
      )
      error_message = "FS mode: ora_backup_dest must be an absolute path like '/u03/backup'. ASMUDEV/ASMLIB mode: ora_backup_dest must be an ASMUDEV/ASMLIB diskgroup like '+RECO'."
    }

    precondition {
      condition = !var.enable_ar_repo || (
        data.google_compute_subnetwork.subnetwork1_info.private_ip_google_access &&
        alltrue([for s in data.google_compute_subnetwork.subnetwork2_info : s.private_ip_google_access])
      )
      error_message = "The 'enable_ar_repo' feature is enabled, but Private Google Access (PGA) is not enabled on the target subnetwork(s). PGA is required for internal access to Artifact Registry."
    }

    precondition {
      condition = !local.create_pool_enabled || (
        var.oracle_home_disk.type == var.create_storage_pool.storage_pool_type &&
        var.data_disk.type == var.create_storage_pool.storage_pool_type &&
        var.reco_disk.type == var.create_storage_pool.storage_pool_type &&
        var.swap_disk_type == var.create_storage_pool.storage_pool_type
      )
      error_message = "When storage_pool is enabled, oracle_home_disk.type, data_disk.type, reco_disk.type, and swap_disk_type must all match storage_pool.storage_pool_type."
    }

    precondition {
      condition     = var.ora_redo_log_count == "" || var.ora_redo_log_location != ""
      error_message = "ora_redo_log_count is set, so ora_redo_log_location must also be set (e.g., '+RECO' or '/u03/redo,/u04/redo')."
    }
  }

  metadata_startup_script = templatefile("${path.module}/scripts/setup.sh.tpl", {
    gcs_source             = var.gcs_source
    database_vm_nodes_json = jsonencode(local.database_vm_nodes)
    common_flags           = local.common_flags
    deployment_name        = local.deployment_id
    delete_control_node    = var.delete_control_node
    assign_public_ip       = var.assign_public_ip
    create_firewall        = var.create_firewall
  })

  metadata = {
    enable-oslogin = "TRUE"
  }

  tags = [local.control_tag]

  depends_on = [
    google_compute_instance_from_template.database_vm,
    google_compute_attached_disk.pool_disks,
  ]
}

# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TLS Infrastructure & Identity (Data Guard / Secret Manager Architecture)

# Look up the existing DNS zone by its resource name (Conditional)
data "google_dns_managed_zone" "selected_zone" {
  count   = var.enable_tls ? 1 : 0
  name    = var.dns_zone_name
  project = var.project_id
}

# 1. Generate Private Keys for each node (Stored securely in Secret Manager)
resource "tls_private_key" "oracle_db_key" {
  for_each  = var.enable_tls ? local.instances : {}
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. Create Certificate Signing Requests (CSR) for each node
resource "tls_cert_request" "oracle_db_csr" {
  for_each        = var.enable_tls ? local.instances : {}
  private_key_pem = tls_private_key.oracle_db_key[each.key].private_key_pem

  subject {
    common_name  = each.key
    organization = "Oracle Database Internal"
  }

  dns_names = [
    "${each.key}.${trimsuffix(data.google_dns_managed_zone.selected_zone[0].dns_name, ".")}"
  ]
}

# 3. Issue Certificates via Google CAS for each node
resource "google_privateca_certificate" "oracle_db_cert" {
  for_each = var.enable_tls ? local.instances : {}

  pool     = split("/", var.cas_pool_id)[5]
  location = split("/", var.cas_pool_id)[3]
  project  = var.project_id
  # Since certificate IDs are immutable across deployment deletions, add a random suffix
  name     = "${substr(each.key, max(0, length(each.key) - 54), 54)}-${random_id.suffix.hex}"
  pem_csr  = tls_cert_request.oracle_db_csr[each.key].cert_request_pem
  lifetime = "${365 * 24 * 60 * 60}s"
}

# 4. Create DNS A Records for each node
resource "google_dns_record_set" "db_a_record" {
  for_each     = var.enable_tls ? local.instances : {}
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${each.key}.${data.google_dns_managed_zone.selected_zone[0].dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance_from_template.database_vm[each.key].network_interface[0].network_ip]
}

# 5. Generate Wallet Passwords for each node
resource "random_password" "wallet_password" {
  for_each = var.enable_tls ? local.instances : {}
  length   = 16
  special  = true
}

# -----------------------------------------------------------------------------
# Secrets Management (Secure Storage per Node)
# -----------------------------------------------------------------------------

resource "google_secret_manager_secret" "db_tls_secret" {
  for_each  = var.enable_tls ? local.instances : {}
  secret_id = "${each.key}-tls-secret"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_tls_secret_val" {
  for_each = var.enable_tls ? local.instances : {}
  secret   = google_secret_manager_secret.db_tls_secret[each.key].id

  secret_data = jsonencode({
    key  = tls_private_key.oracle_db_key[each.key].private_key_pem
    cert = "${google_privateca_certificate.oracle_db_cert[each.key].pem_certificate}\n${join("\n", google_privateca_certificate.oracle_db_cert[each.key].pem_certificate_chain)}"
    pwd  = random_password.wallet_password[each.key].result
  })
}

# Grant VM Service Account access ONLY to its specific node-level TLS secret
resource "google_secret_manager_secret_iam_member" "vm_access_tls_secret" {
  for_each  = var.enable_tls ? local.instances : {}
  secret_id = google_secret_manager_secret.db_tls_secret[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.vm_service_account}"
}

# This rule is deleted by the startup script upon deployment completion.
resource "google_compute_firewall" "control_ssh" {
  count       = var.create_firewall ? 1 : 0
  name        = "ora-ssh-${google_compute_instance.control_node.name}"
  project     = var.project_id
  network     = local.network
  description = "Temporary rule for deployment ${local.deployment_id}: Allows Control Node SSH access to Database VMs for initial provisioning."

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "icmp"
  }

  source_tags = [local.control_tag]
  target_tags = [local.db_tag]
}

resource "google_compute_firewall" "db_sync" {
  count       = (local.is_multi_instance && var.create_firewall) ? 1 : 0
  name        = "oracle-${local.deployment_id}-db-sync"
  project     = var.project_id
  network     = local.network
  description = "Deployment ${local.deployment_id}: Allows inter-database communication on the Oracle listener port for Data Guard synchronization."
  allow {
    protocol = "tcp"
    ports    = [var.enable_tls ? var.tls_listener_port : var.ora_listener_port]
  }
  allow {
    protocol = "icmp"
  }

  source_tags = [local.db_tag]
  target_tags = [local.db_tag]
}

resource "google_artifact_registry_repository" "os_package_repos" {
  # Only create repositories if the guard is true and the image family is supported
  for_each = (var.enable_ar_repo && contains(keys(local.os_upstreams), var.source_image_family)) ? toset(local.os_repo_types) : []

  project       = var.project_id
  location      = local.region
  repository_id = "${local.deployment_id}-${each.key}"
  description   = "Remote repo for ${local.deployment_id} ${each.key} packages"
  format        = "YUM"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    common_repository {
      uri = local.os_upstreams[var.source_image_family][each.key]
    }
  }
}

output "control_node_log_url" {
  description = "Logs Explorer URL with Oracle Toolkit output"
  value       = "https://console.cloud.google.com/logs/query;query=resource.labels.instance_id%3D${urlencode(google_compute_instance.control_node.instance_id)};duration=P30D?project=${urlencode(var.project_id)}"
}

output "project_id" {
  description = "GCP project ID."
  value       = var.project_id
}

output "database_vm_names" {
  description = "Names of the created database VMs from instance templates"
  value       = [for vm in google_compute_instance_from_template.database_vm : vm.name]
}

output "storage_pool_zone1_self_link" {
  description = "Self-link of the Hyperdisk Storage Pool in zone1 (null if storage pool is not enabled)"
  value       = length(google_compute_storage_pool.zone1) > 0 ? google_compute_storage_pool.zone1[0].id : null
}

output "storage_pool_zone2_self_link" {
  description = "Self-link of the Hyperdisk Storage Pool in zone2 (null if storage pool is not enabled or single-instance)"
  value       = length(google_compute_storage_pool.zone2) > 0 ? google_compute_storage_pool.zone2[0].id : null
}

output "storage_backend" {
  description = "Active storage backend for the Oracle DATA/RECO disk groups."
  value       = lower(var.storage_backend)
}

output "gcnv_host_map" {
  description = "Per-host GCNV map (iSCSI portals + multipath WWID->alias) passed to the iscsi-multipath role. Empty unless storage_backend=gcnv."
  value       = local.gcnv_host_map
}

output "gcnv_storage_pool_location" {
  description = "Location of the provisioned GCNV Flex pool (null unless storage_backend=gcnv)."
  value       = try(module.netapp_iscsi[0].storage_pool_location, null)
}
