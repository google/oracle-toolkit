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

resource "google_oracle_database_cloud_exadata_infrastructure" "exadata_infrastructure" {
  cloud_exadata_infrastructure_id = var.cloud_exadata_infrastructure_id
  display_name                    = var.cloud_exadata_infrastructure_id
  location                        = var.location
  project                         = var.exa_infra_project
  gcp_oracle_zone                 = var.gcp_oracle_zone

  properties {
    shape         = var.shape
    compute_count = var.compute_count
    storage_count = var.storage_count
  }

  deletion_protection = var.deletion_protection
}

data "google_oracle_database_db_servers" "db_servers" {
  depends_on                   = [google_oracle_database_cloud_exadata_infrastructure.exadata_infrastructure]
  location                     = var.location
  project                      = var.exa_infra_project
  cloud_exadata_infrastructure = var.cloud_exadata_infrastructure_id
}
