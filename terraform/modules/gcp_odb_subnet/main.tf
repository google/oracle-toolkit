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

resource "google_oracle_database_odb_subnet" "odb_subnet" {
  odb_subnet_id = var.odb_subnet_id
  location      = var.location
  project       = var.vpc_project
  odbnetwork    = var.odb_network_id
  cidr_range    = var.subnet_cidr_range
  purpose       = var.subnet_purpose
  labels = {
    terraform_created = "true"
  }
  deletion_protection = var.deletion_protection
}
