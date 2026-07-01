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

output "storage_pool_location" {
  value = google_netapp_storage_pool.pool.location
}

# Deterministic host group name per node key. Each Host Group is created here
# with a placeholder IQN; the gcnv-provision Ansible role updates it with the
# node's real initiator IQN during host prep.
output "host_group_names" {
  value = local.host_group_names
}

# Per-LUN facts consumed by main.tf: portals + WWID for the install host map, and
# volume/block-device names for the gcnv-provision fulfillment plan.
output "iscsi_mount" {
  value = {
    for k, v in google_netapp_volume.iscsi :
    k => {
      volume_name       = v.name
      block_device_name = local.block_device_names[k]
      ip_address        = try(v.mount_options[0].ip_address, null)
      identifier        = try(v.block_devices[0].identifier, null)
    }
  }
}
