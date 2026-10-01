# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "google_compute_network" "vpc_network" {
  name    = var.network_name
  project = var.vpc_project
}

resource "google_oracle_database_odb_network" "odb_network" {
  odb_network_id  = var.odb_network_id
  location        = var.location
  project         = var.vpc_project
  network         = data.google_compute_network.vpc_network.id
  gcp_oracle_zone = var.gcp_oracle_zone
  labels = {
    terraform_created = "true"
  }
  deletion_protection = var.deletion_protection
}
