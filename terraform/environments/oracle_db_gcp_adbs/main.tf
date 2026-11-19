# Copyright 2025 Google LLC
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

terraform {
  required_version = ">= 1.5.7"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0.0, < 8.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# 1. Base VPC Network & Subnet
resource "google_compute_network" "vpc_network" {
  count                   = var.create_vpc ? 1 : 0
  name                    = var.vpc_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "subnet" {
  count         = var.create_vpc ? 1 : 0
  name          = "${var.vpc_name}-subnet"
  ip_cidr_range = var.gcp_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network[0].id
  project       = var.project_id
}

locals {
  vpc_name = var.create_vpc ? google_compute_network.vpc_network[0].name : var.vpc_name
}

# 2. Oracle Database@Google Cloud Peered ODB Network
module "odb_network" {
  source          = "../../modules/gcp_odb_network"
  network_name    = local.vpc_name
  vpc_project     = var.project_id
  odb_network_id  = var.odb_network_id
  location        = var.region
  gcp_oracle_zone = var.zone
}

# 3. Delegated Client Subnet (TCPS Port 1522 Private Endpoint)
module "odb_client_subnet" {
  source            = "../../modules/gcp_odb_subnet"
  odb_subnet_id     = var.odb_client_subnet_id
  location          = var.region
  vpc_project       = var.project_id
  odb_network_id    = module.odb_network.odb_network_id
  subnet_cidr_range = var.odb_client_subnet_cidr
  subnet_purpose    = "CLIENT_SUBNET"
}

# 4. Autonomous Database Serverless (ADB-S)
module "autonomous_database" {
  source                          = "../../modules/gcp_adb"
  autonomous_database_id          = var.autonomous_database_id
  location                        = var.region
  adb_project                     = var.project_id
  vpc_project                     = var.project_id
  odb_network_id                  = module.odb_network.odb_network_id
  odb_subnet_id                   = module.odb_client_subnet.odb_subnet_id
  adb_admin_pw                    = var.adb_admin_password
  ecpu_count                      = var.ecpu_count
  data_storage_size_tb            = var.data_storage_size_tb
  db_version                      = var.db_version
  workload_type                   = var.workload_type
  db_edition                      = var.db_edition
  license_type                    = var.license_type
  backup_retention_period_days    = var.backup_retention_period_days
  is_auto_scaling_enabled         = var.is_auto_scaling_enabled
  is_storage_auto_scaling_enabled = var.is_storage_auto_scaling_enabled
  deletion_protection             = var.deletion_protection
}
