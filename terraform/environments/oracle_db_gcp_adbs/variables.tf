variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region (e.g. europe-west3, us-central1)"
  default     = "europe-west3"
}

variable "zone" {
  type        = string
  description = "GCP Zone"
  default     = "europe-west3-a"
}

variable "create_vpc" {
  type        = bool
  description = "Whether to create a new VPC"
  default     = true
}

variable "vpc_name" {
  type        = string
  description = "VPC network name"
  default     = "ora-adbs-vpc"
}

variable "gcp_subnet_cidr" {
  type        = string
  description = "CIDR range for GCP subnet"
  default     = "10.140.0.0/20"
}

variable "odb_network_id" {
  type        = string
  description = "Resource ID for ODB Network"
  default     = "ora-adbs-odb-net"
}

variable "odb_client_subnet_id" {
  type        = string
  description = "Resource ID for delegated Client Subnet"
  default     = "ora-adbs-client-subnet"
}

variable "odb_client_subnet_cidr" {
  type        = string
  description = "CIDR range for delegated Client Subnet"
  default     = "10.150.20.0/24"
}

variable "autonomous_database_id" {
  type        = string
  description = "Resource ID for Autonomous Database"
  default     = "adbs-primary"
}

variable "adb_admin_password" {
  type        = string
  description = "Admin password for Autonomous Database"
  sensitive   = true
}

variable "ecpu_count" {
  type        = number
  description = "Allocated ECPUs"
  default     = 4
}

variable "data_storage_size_tb" {
  type        = number
  description = "Storage capacity in TB"
  default     = 1
}

variable "db_version" {
  type        = string
  description = "Oracle DB Version (19c or 23ai)"
  default     = "19c"
}

variable "workload_type" {
  type        = string
  description = "OLTP (ATP) or DW (ADW)"
  default     = "OLTP"
}

variable "db_edition" {
  type        = string
  description = "ENTERPRISE_EDITION or STANDARD_EDITION"
  default     = "ENTERPRISE_EDITION"
}

variable "license_type" {
  type        = string
  description = "BRING_YOUR_OWN_LICENSE or LICENSE_INCLUDED"
  default     = "BRING_YOUR_OWN_LICENSE"
}

variable "backup_retention_period_days" {
  type        = number
  description = "Backup retention in days"
  default     = 60
}

variable "is_auto_scaling_enabled" {
  type        = bool
  description = "Enable compute auto-scaling"
  default     = true
}

variable "is_storage_auto_scaling_enabled" {
  type        = bool
  description = "Enable storage auto-scaling"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection"
  default     = true
}
