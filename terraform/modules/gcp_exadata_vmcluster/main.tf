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

data "google_oracle_database_cloud_exadata_infrastructure" "exadata_infrastructure" {
  location                        = var.location
  project                         = var.exa_infra_project
  cloud_exadata_infrastructure_id = var.cloud_exadata_infrastructure_id
}

data "google_oracle_database_db_servers" "db_servers" {
  depends_on                   = [data.google_oracle_database_cloud_exadata_infrastructure.exadata_infrastructure]
  location                     = var.location
  project                      = var.exa_infra_project
  cloud_exadata_infrastructure = var.cloud_exadata_infrastructure_id
}

resource "google_oracle_database_cloud_vm_cluster" "exadata_vm_cluster" {
  depends_on = [data.google_oracle_database_cloud_exadata_infrastructure.exadata_infrastructure]

  cloud_vm_cluster_id    = var.cloud_vm_cluster_id
  display_name           = var.cloud_vm_cluster_id
  location               = var.location
  project                = var.exa_vm_project
  exadata_infrastructure = "projects/${var.exa_infra_project}/locations/${var.location}/cloudExadataInfrastructures/${var.cloud_exadata_infrastructure_id}"
  odb_network            = "projects/${var.vpc_project}/locations/${var.location}/odbNetworks/${var.odb_network_id}"
  odb_subnet             = "projects/${var.vpc_project}/locations/${var.location}/odbNetworks/${var.odb_network_id}/odbSubnets/${var.odb_client_subnet_id}"
  backup_odb_subnet      = "projects/${var.vpc_project}/locations/${var.location}/odbNetworks/${var.odb_network_id}/odbSubnets/${var.odb_backup_subnet_id}"

  properties {
    license_type            = var.license_type
    ssh_public_keys         = var.ssh_public_keys
    cpu_core_count          = var.cpu_core_count
    memory_size_gb          = var.memory_size_gb
    db_node_storage_size_gb = var.db_node_storage_size_gb
    db_server_ocids         = [for server in data.google_oracle_database_db_servers.db_servers.db_servers : server.properties[0].ocid]
    data_storage_size_tb    = var.data_storage_size_tb
    gi_version              = var.gi_version
    hostname_prefix         = var.hostname_prefix
  }

  deletion_protection = var.deletion_protection
}
