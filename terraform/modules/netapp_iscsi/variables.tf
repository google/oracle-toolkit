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

variable "name_prefix" {
  type        = string
  description = "Prefix for pool-adjacent resource names (host groups, volumes)."
  default     = "ora"
}

variable "pool_name" {
  type    = string
  default = "ora-flex-unified-pool"
}

variable "pool_location" {
  type        = string
  description = "Zonal or regional location for the Flex pool (must match GCNV API, e.g. us-west1-b)."
}

variable "pool_capacity_gib" {
  type    = number
  default = 2048
}

variable "pool_service_level" {
  type    = string
  default = "FLEX"
}

variable "pool_type" {
  type    = string
  default = "UNIFIED"
}

variable "custom_performance_enabled" {
  type        = bool
  description = "Enable explicit throughput/IOPS on the pool (Flex custom performance)."
  default     = true
}

variable "pool_ready_wait" {
  type        = string
  description = "Short delay after pool create before volumes (GCNV eventual consistency)."
  default     = "60s"
}

variable "host_os_type" {
  type    = string
  default = "LINUX"
}

variable "project_id" {
  type        = string
  description = "Project that owns the GCNV pool and volumes (the deployment/service project)."
}

variable "network_name" {
  type = string
}

variable "network_project_id" {
  type        = string
  description = "Project ID that owns the VPC network (Shared VPC host project if applicable)."
}

variable "storage_node_keys" {
  type        = set(string)
  description = <<-EOT
    Set of logical node keys (e.g. "<instance>-1", "<instance>-2"). Each key gets its own LUN set
    cloned from lun_layout — required for Data Guard so LUNs are not shared across hosts. Each key
    also gets its own Host Group (created with a placeholder IQN and attached to its LUNs); the
    gcnv-provision Ansible role updates the Host Group with the real IQN during host prep.
  EOT
}

variable "lun_layout" {
  type = map(number)
  default = {
    u01  = 200
    data = 300
    log  = 200
  }
  description = "GiB per LUN type; applied to every storage node key (u01 binaries, data ASM DG, log ASM DG)."
}

variable "total_throughput_mibps" {
  type    = number
  default = 64
}

variable "total_iops" {
  type    = number
  default = 1024
}
