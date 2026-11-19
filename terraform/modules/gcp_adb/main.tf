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

resource "google_oracle_database_autonomous_database" "adb" {
  autonomous_database_id = var.autonomous_database_id
  location               = var.location
  project                = var.adb_project
  database               = var.autonomous_database_id
  display_name           = var.autonomous_database_id
  admin_password         = var.adb_admin_pw
  odb_network            = "projects/${var.vpc_project}/locations/${var.location}/odbNetworks/${var.odb_network_id}"
  odb_subnet             = "projects/${var.vpc_project}/locations/${var.location}/odbNetworks/${var.odb_network_id}/odbSubnets/${var.odb_subnet_id}"

  properties {
    compute_count                   = var.ecpu_count
    data_storage_size_gb            = var.data_storage_size_gb
    data_storage_size_tb            = var.data_storage_size_tb
    db_version                      = var.db_version
    db_workload                     = var.workload_type
    db_edition                      = var.db_edition
    license_type                    = var.license_type
    private_endpoint_label          = var.autonomous_database_id
    backup_retention_period_days    = var.backup_retention_period_days
    is_auto_scaling_enabled         = var.is_auto_scaling_enabled
    is_storage_auto_scaling_enabled = var.is_storage_auto_scaling_enabled
  }

  deletion_protection = var.deletion_protection

  lifecycle {
    ignore_changes = [
      properties[0].compute_count,
      properties[0].data_storage_size_gb,
      properties[0].data_storage_size_tb,
      properties[0].db_version,
      properties[0].db_edition
    ]
  }
}
