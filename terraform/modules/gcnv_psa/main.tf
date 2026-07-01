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

resource "google_compute_global_address" "psa" {
  count = var.create_psa ? 1 : 0

  project       = var.network_project_id
  name          = var.psa_range_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_prefix_length
  network       = data.google_compute_network.vpc.id
  address       = var.psa_reserved_cidr
}

resource "google_service_networking_connection" "psa" {
  count = var.create_psa ? 1 : 0

  network                 = data.google_compute_network.vpc.id
  service                 = "netapp.servicenetworking.goog"
  reserved_peering_ranges = [google_compute_global_address.psa[0].name]
}

resource "google_compute_network_peering_routes_config" "psa_routes" {
  count = var.create_psa ? 1 : 0

  project              = var.network_project_id
  peering              = google_service_networking_connection.psa[0].peering
  network              = data.google_compute_network.vpc.name
  import_custom_routes = true
  export_custom_routes = true
}
