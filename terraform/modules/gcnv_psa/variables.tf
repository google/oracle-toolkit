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

variable "create_psa" {
  type        = bool
  description = "When true, reserve an internal range and create the NetApp Volumes service networking connection. When false, you must already have PSA to netapp.servicenetworking.goog (see README)."
}

variable "network_project_id" {
  type        = string
  description = "Project that owns the VPC (Shared VPC host if applicable)."
}

variable "network_name" {
  type = string
}

variable "psa_range_name" {
  type    = string
  default = "netapp-psa-range"
}

variable "psa_prefix_length" {
  type    = number
  default = 24
}

variable "psa_reserved_cidr" {
  type        = string
  default     = null
  description = "Optional explicit base address for the reserved range; leave null to let GCP choose."
}
