terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}


# 1. Network Setup
module "networking" {
  source            = "../../modules/networking"
  project_id        = var.project_id
  region            = var.region
  create_networking = var.create_networking
  network_name      = "zdm-gke-vpc"
  subnet_name       = "zdm-gke-subnet"
  subnet_cidr       = "10.148.0.0/20"
  source_db_ips     = var.source_db_ips
  create_odb_subnet = var.target_type != "gce" ? true : false
  odb_subnet_cidr   = var.odb_subnet_cidr

  target_db_ips = (
    var.target_type == "exacs" ? var.exacs_target_node_ips :
    var.target_type == "dbcs" ? var.dbcs_target_db_ips :
    var.target_db_ips
  )
}

# 2. GKE Private Cluster
resource "google_container_cluster" "gke_cluster" {
  name                = "zdm-gke-cluster"
  location            = var.zone
  project             = var.project_id
  deletion_protection = false

  network    = module.networking.network_name
  subnetwork = module.networking.subnet_name

  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/14"
    services_ipv4_cidr_block = "/20"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep control plane endpoint public for easy access
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
}

# Node Pool
resource "google_container_node_pool" "node_pool" {
  name       = "zdm-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.gke_cluster.name
  project    = var.project_id
  node_count = 1

  node_config {
    preemptible  = false
    machine_type = "e2-standard-4"

    service_account = var.create_service_accounts ? google_service_account.gke_node_sa[0].email : "zdm-gke-node-sa@${var.project_id}.iam.gserviceaccount.com"
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

resource "google_service_account" "gke_node_sa" {
  count        = var.create_service_accounts ? 1 : 0
  account_id   = "zdm-gke-node-sa"
  display_name = "Service Account for GKE Node VM"
  project      = var.project_id
}

# 3. ZDM Service Account & Workload Identity Setup
resource "google_service_account" "zdm_gke_sa" {
  count        = var.create_service_accounts ? 1 : 0
  account_id   = "zdm-gke-sa"
  display_name = "GCP Service Account for ZDM GKE Container"
  project      = var.project_id
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  count              = var.create_service_accounts ? 1 : 0
  service_account_id = google_service_account.zdm_gke_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[zdm-migration/zdm-k8s-sa]"

  depends_on = [
    google_container_cluster.gke_cluster
  ]
}

module "storage" {
  source                    = "../../modules/storage"
  project_id                = var.project_id
  region                    = var.region
  bucket_name               = var.bucket_name
  create_bucket             = var.create_bucket
  zdm_service_account_email = var.create_service_accounts ? google_service_account.zdm_gke_sa[0].email : "zdm-gke-sa@${var.project_id}.iam.gserviceaccount.com"
}

# Optional Oracle Database@Google Cloud Infrastructure Modules
module "gcp_odb_network" {
  count           = var.create_odb_infrastructure ? 1 : 0
  source          = "../../modules/gcp_odb_network"
  network_name    = module.networking.network_name
  vpc_project     = var.project_id
  odb_network_id  = var.odb_network_id
  location        = var.region
  gcp_oracle_zone = var.zone
}

module "gcp_odb_client_subnet" {
  count             = var.create_odb_infrastructure ? 1 : 0
  source            = "../../modules/gcp_odb_subnet"
  odb_subnet_id     = var.odb_client_subnet_id
  location          = var.region
  vpc_project       = var.project_id
  odb_network_id    = var.create_odb_infrastructure ? module.gcp_odb_network[0].odb_network_id : var.odb_network_id
  subnet_cidr_range = var.odb_client_subnet_cidr
  subnet_purpose    = "CLIENT_SUBNET"
}

module "gcp_odb_backup_subnet" {
  count             = (var.create_odb_infrastructure && var.create_target_exadata) ? 1 : 0
  source            = "../../modules/gcp_odb_subnet"
  odb_subnet_id     = var.odb_backup_subnet_id
  location          = var.region
  vpc_project       = var.project_id
  odb_network_id    = var.create_odb_infrastructure ? module.gcp_odb_network[0].odb_network_id : var.odb_network_id
  subnet_cidr_range = var.odb_backup_subnet_cidr
  subnet_purpose    = "BACKUP_SUBNET"
}

module "gcp_dbsystem" {
  count            = (var.target_type == "dbcs" && var.create_target_dbsystem) ? 1 : 0
  source           = "../../modules/gcp_dbsystem"
  db_system_id     = var.db_system_id
  location         = var.region
  gcp_oracle_zone  = var.zone
  dbsystem_project = var.project_id
  vpc_project      = var.project_id
  odb_network_id   = var.create_odb_infrastructure ? module.gcp_odb_network[0].odb_network_id : var.odb_network_id
  odb_subnet_id    = var.create_odb_infrastructure ? module.gcp_odb_client_subnet[0].odb_subnet_id : var.odb_client_subnet_id
  ssh_public_keys  = [var.ssh_public_key]
  hostname_prefix  = "dbcs-tgt"
  admin_pw         = var.db_admin_pw
  tde_pw           = var.tde_pw
}

module "gcp_exadata_infra" {
  count                           = (var.target_type == "exacs" && var.create_target_exadata) ? 1 : 0
  source                          = "../../modules/gcp_exadata_infra"
  location                        = var.region
  exa_infra_project               = var.project_id
  cloud_exadata_infrastructure_id = var.cloud_exadata_infrastructure_id
  gcp_oracle_zone                 = var.zone
}

module "gcp_exadata_vmcluster" {
  count                           = (var.target_type == "exacs" && var.create_target_exadata) ? 1 : 0
  source                          = "../../modules/gcp_exadata_vmcluster"
  location                        = var.region
  exa_infra_project               = var.project_id
  exa_vm_project                  = var.project_id
  vpc_project                     = var.project_id
  cloud_exadata_infrastructure_id = var.create_target_exadata ? module.gcp_exadata_infra[0].exadata_infrastructure_id : var.cloud_exadata_infrastructure_id
  cloud_vm_cluster_id             = var.cloud_vm_cluster_id
  odb_network_id                  = var.create_odb_infrastructure ? module.gcp_odb_network[0].odb_network_id : var.odb_network_id
  odb_client_subnet_id            = var.create_odb_infrastructure ? module.gcp_odb_client_subnet[0].odb_subnet_id : var.odb_client_subnet_id
  odb_backup_subnet_id            = (var.create_odb_infrastructure && var.create_target_exadata) ? module.gcp_odb_backup_subnet[0].odb_subnet_id : var.odb_backup_subnet_id
  ssh_public_keys                 = [var.ssh_public_key]
  hostname_prefix                 = "exacs-tgt"
}

module "gcp_adb" {
  count                  = (var.target_type == "adb" && var.create_target_adb) ? 1 : 0
  source                 = "../../modules/gcp_adb"
  autonomous_database_id = var.autonomous_database_id
  location               = var.region
  adb_project            = var.project_id
  adb_admin_pw           = var.adb_admin_pw
  vpc_project            = var.project_id
  odb_network_id         = var.create_odb_infrastructure ? module.gcp_odb_network[0].odb_network_id : var.odb_network_id
  odb_subnet_id          = var.create_odb_infrastructure ? module.gcp_odb_client_subnet[0].odb_subnet_id : var.odb_client_subnet_id
}



