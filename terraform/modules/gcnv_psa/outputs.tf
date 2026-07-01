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

output "reserved_range_name" {
  value       = try(google_compute_global_address.psa[0].name, null)
  description = "Name passed to service networking; null when create_psa is false."
}

output "reserved_range_cidr" {
  value       = try("${google_compute_global_address.psa[0].address}/${google_compute_global_address.psa[0].prefix_length}", null)
  description = "Allocated PSA CIDR when create_psa is true."
}
