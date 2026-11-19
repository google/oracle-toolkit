variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "region" {
  description = "The GCP Region"
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "The GCP Zone"
  type        = string
  default     = "europe-west3-a"
}

variable "create_networking" {
  description = "Set to false if the VPC network and subnets already exist and should only be referenced"
  type        = bool
  default     = true
}

variable "create_service_accounts" {
  description = "Set to false if service accounts already exist and should only be referenced"
  type        = bool
  default     = true
}


variable "bucket_name" {
  description = "Name of the GCS bucket for ZDM backups and dumps"
  type        = string
}

variable "create_bucket" {
  description = "Set to false if the GCS bucket already exists and should only be reused (IAM role granted)"
  type        = bool
  default     = true
}


variable "zdm_software_bucket" {
  description = "Bucket containing ZDM software ZIP (optional)"
  type        = string
  default     = ""
}

variable "zdm_software_zip" {
  description = "ZIP filename of ZDM software (optional)"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Public SSH key for logging into the ZDM VM instance"
  type        = string
}

variable "source_db_ips" {
  description = "IP addresses of source database instances"
  type        = list(string)
  default     = []
}

variable "target_db_ips" {
  description = "IP addresses of target database instances (optional if provisioned externally)"
  type        = list(string)
  default     = []
}

variable "u01_disk_size" {
  description = "Size in GB for /u01 installation binary disk"
  type        = number
  default     = 100
}

variable "data_disk_size" {
  description = "Size in GB for database datafiles disk"
  type        = number
  default     = 200
}

variable "reco_disk_size" {
  description = "Size in GB for redo/recovery files disk"
  type        = number
  default     = 100
}

variable "target_type" {
  description = "The target database deployment model (gce, adb-s, exacs, dbcs)"
  type        = string
  default     = "gce"
}

variable "odb_subnet_cidr" {
  description = "The CIDR range for Oracle Database@Google Cloud delegated subnet"
  type        = string
  default     = "10.150.20.0/24"
}

variable "exacs_target_node_ips" {
  description = "List of private node IPs for Exadata VM Cluster nodes"
  type        = list(string)
  default     = []
}

variable "dbcs_target_db_ips" {
  description = "List of private node IPs for target DBCS nodes"
  type        = list(string)
  default     = []
}

variable "adb_target_endpoint" {
  description = "Connection service name for target Autonomous Database"
  type        = string
  default     = ""
}

variable "install_docker" {
  description = "Set to true to install Docker on the ZDM VM instance"
  type        = bool
  default     = false
}

# Optional Oracle Database@Google Cloud creation variables
variable "create_odb_infrastructure" {
  description = "Set to true to provision Oracle Database@Google Cloud ODB Network and Subnets via Terraform"
  type        = bool
  default     = false
}

variable "odb_network_id" {
  description = "Name/ID of the Oracle Database@Google Cloud ODB Network"
  type        = string
  default     = "odb-network"
}

variable "odb_client_subnet_id" {
  description = "Name/ID of the Oracle Database@Google Cloud Client Subnet"
  type        = string
  default     = "odb-client-subnet"
}

variable "odb_backup_subnet_id" {
  description = "Name/ID of the Oracle Database@Google Cloud Backup Subnet"
  type        = string
  default     = "odb-backup-subnet"
}

variable "odb_client_subnet_cidr" {
  description = "CIDR block for Oracle Database@Google Cloud Client Subnet"
  type        = string
  default     = "10.150.20.0/24"
}

variable "odb_backup_subnet_cidr" {
  description = "CIDR block for Oracle Database@Google Cloud Backup Subnet"
  type        = string
  default     = "10.150.21.0/24"
}

variable "create_target_dbsystem" {
  description = "Set to true to provision a Base Database Service (DBCS) instance in GCP"
  type        = bool
  default     = false
}

variable "db_system_id" {
  description = "ID of the target DBCS DB System"
  type        = string
  default     = "odb-db-system"
}

variable "db_admin_pw" {
  description = "Admin password for target DB System SYS/SYSTEM accounts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tde_pw" {
  description = "TDE Wallet password for target DB System"
  type        = string
  default     = ""
  sensitive   = true
}

variable "create_target_exadata" {
  description = "Set to true to provision Exadata Infrastructure and VM Cluster in GCP"
  type        = bool
  default     = false
}

variable "cloud_exadata_infrastructure_id" {
  description = "ID of the target Exadata Infrastructure"
  type        = string
  default     = "exa-infra-1"
}

variable "cloud_vm_cluster_id" {
  description = "ID of the target Exadata VM Cluster"
  type        = string
  default     = "exa-vmcluster-1"
}

variable "create_target_adb" {
  description = "Set to true to provision Autonomous Database (ADB) in GCP"
  type        = bool
  default     = false
}

variable "autonomous_database_id" {
  description = "ID of the target Autonomous Database"
  type        = string
  default     = "odb-adb-1"
}

variable "adb_admin_pw" {
  description = "Admin password for Autonomous Database"
  type        = string
  default     = ""
  sensitive   = true
}
