# Copyright 2026 Google LLC
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

data "google_compute_network" "vpc" {
  name    = var.network_name
  project = var.network_project_id
}

locals {
  # Extract region from pool_location (e.g., "us-east1-c" -> "us-east1")
  region = replace(var.pool_location, "/-[a-z]$/", "")

  # GCNV volume names: [a-z][a-z0-9_]{0,62} — no hyphens (API rejects them).
  name_slug = lower(replace(var.name_prefix, "-", "_"))

  volume_specs = merge(flatten([
    for nk in var.storage_node_keys : [
      for lun_name, lun_gb in var.lun_layout : {
        "${nk}-${lun_name}" = {
          host_key = nk
          size_gib = lun_gb
          lun_name = lun_name
        }
      }
    ]
  ])...)

  volume_gcp_names = {
    for k, v in local.volume_specs : k => substr(
      trimsuffix(lower("${local.name_slug}_${replace(lower(k), "-", "_")}"), "_"),
      0,
      63
    )
  }

  block_device_names = {
    for k, v in local.volume_specs : k => substr(
      trimsuffix(lower("${replace(lower(v.lun_name), "-", "_")}_${replace(lower(v.host_key), "-", "_")}"), "_"),
      0,
      62
    )
  }

  # Host group IDs must match [a-z][a-z0-9-]{0,62} (hyphens OK; underscores rejected).
  host_group_prefix = trimsuffix(
    lower(replace(replace(replace(var.name_prefix, "_", "-"), ".", "-"), " ", "-")),
    "-"
  )

  host_group_names = {
    for nk in var.storage_node_keys : nk => substr(
      trimsuffix(
        lower(
          "${local.host_group_prefix}-${replace(replace(replace(lower(nk), "_", "-"), ".", "-"), " ", "-")}-hg"
        ),
        "-"
      ),
      0,
      63
    )
  }
}

resource "google_netapp_storage_pool" "pool" {
  project                    = var.project_id
  name                       = var.pool_name
  location                   = var.pool_location
  custom_performance_enabled = var.custom_performance_enabled
  service_level              = var.pool_service_level
  capacity_gib               = var.pool_capacity_gib
  network                    = data.google_compute_network.vpc.id
  type                       = var.pool_type

  total_throughput_mibps = var.total_throughput_mibps
  total_iops             = var.total_iops
}

resource "time_sleep" "wait_for_pool" {
  depends_on      = [google_netapp_storage_pool.pool]
  create_duration = var.pool_ready_wait
}

resource "google_netapp_host_group" "host_group" {
  for_each = toset(var.storage_node_keys)

  project  = var.project_id
  name     = local.host_group_names[each.key]
  location = local.region
  os_type  = var.host_os_type
  type     = "ISCSI_INITIATOR"
  hosts    = ["iqn.1994-05.com.redhat:dummy"] # Placeholder; each host's real IQN is not known until boot.

  lifecycle {
    ignore_changes = [hosts]
  }

  depends_on = [google_netapp_storage_pool.pool]
}

# iSCSI LUNs are created mapped to the Host Group above. The gcnv-provision
# Ansible role (run during host prep, before iscsi-multipath) reads each VM's
# real initiator IQN and updates its Host Group via `gcloud netapp host-groups
# update`. Terraform ignores hosts drift on the Host Group so that update is
# not reverted on the next apply; host_groups on the Volume itself doesn't
# drift since it always points at the same (Terraform-managed) Host Group.
resource "google_netapp_volume" "iscsi" {
  for_each = local.volume_specs

  project      = var.project_id
  name         = local.volume_gcp_names[each.key]
  location     = google_netapp_storage_pool.pool.location
  capacity_gib = each.value.size_gib
  storage_pool = google_netapp_storage_pool.pool.name

  protocols = ["ISCSI"]

  block_devices {
    name        = local.block_device_names[each.key]
    os_type     = var.host_os_type
    host_groups = [google_netapp_host_group.host_group[each.value.host_key].id]
  }

  lifecycle {
    ignore_changes = [block_devices[0].host_groups]
  }

  depends_on = [
    google_netapp_storage_pool.pool,
    time_sleep.wait_for_pool,
    google_netapp_host_group.host_group,
  ]
}
