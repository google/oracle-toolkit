terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}


module "networking" {
  source            = "../../modules/networking"
  project_id        = var.project_id
  region            = var.region
  create_networking = var.create_networking
  network_name      = "zdm-gce-vpc"
  subnet_name       = "zdm-gce-subnet"
  subnet_cidr       = "10.140.0.0/20"
  source_db_ips     = var.source_db_ips
  create_odb_subnet = var.target_type != "gce" ? true : false
  odb_subnet_cidr   = var.odb_subnet_cidr
  
  target_db_ips = (
    var.target_type == "gce" ? concat(var.target_db_ips, [module.oracle_target_db[0].target_private_ip]) :
    var.target_type == "exacs" ? var.exacs_target_node_ips :
    var.target_type == "dbcs" ? var.dbcs_target_db_ips :
    var.target_db_ips
  )
}

module "oracle_target_db" {
  count          = var.target_type == "gce" ? 1 : 0
  source         = "../../modules/oracle_gce_target"
  project_id     = var.project_id
  zone           = var.zone
  instance_name  = "oracle-gce-target-db"
  subnet_name    = module.networking.subnet_name
  ssh_public_key = var.ssh_public_key
  u01_disk_size  = var.u01_disk_size
  data_disk_size = var.data_disk_size
  reco_disk_size = var.reco_disk_size
}

module "zdm_node" {
  source                 = "../../modules/zdm_node"
  project_id             = var.project_id
  zone                   = var.zone
  network_name           = module.networking.network_name
  subnet_name            = module.networking.subnet_name
  instance_name          = "zdm-gce-service-node"
  zdm_software_bucket    = var.zdm_software_bucket
  zdm_software_zip       = var.zdm_software_zip
  ssh_public_key         = var.ssh_public_key
  install_docker         = var.install_docker
  create_service_account = var.create_service_accounts
}

module "storage" {
  source                    = "../../modules/storage"
  project_id                = var.project_id
  region                    = var.region
  bucket_name               = var.bucket_name
  create_bucket             = var.create_bucket
  zdm_service_account_email = module.zdm_node.zdm_sa_email
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

