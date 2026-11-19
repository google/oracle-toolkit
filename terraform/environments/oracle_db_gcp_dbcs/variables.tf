variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region"
  default     = "europe-west3"
}

variable "zone" {
  type        = string
  description = "GCP Zone"
  default     = "europe-west3-a"
}

variable "create_vpc" {
  type        = bool
  description = "Whether to create VPC"
  default     = true
}

variable "vpc_name" {
  type        = string
  description = "VPC Name"
  default     = "ora-dbcs-vpc"
}

variable "gcp_subnet_cidr" {
  type        = string
  description = "GCP Subnet CIDR"
  default     = "10.140.0.0/20"
}

variable "odb_network_id" {
  type        = string
  description = "ODB Network ID"
  default     = "ora-dbcs-odb-net"
}

variable "odb_client_subnet_id" {
  type        = string
  description = "ODB Subnet ID"
  default     = "ora-dbcs-subnet"
}

variable "odb_client_subnet_cidr" {
  type        = string
  description = "ODB Subnet CIDR range"
  default     = "10.150.20.0/24"
}

variable "db_system_id" {
  type        = string
  description = "Resource ID for DB System"
  default     = "dbcs-primary"
}

variable "ssh_public_keys" {
  type        = set(string)
  description = "SSH public keys for host login"
}

variable "ecpu_core_count" {
  type        = number
  description = "ECPU core count"
  default     = 4
}

variable "hostname_prefix" {
  type        = string
  description = "Hostname prefix"
  default     = "dbcsnode"
}

variable "shape" {
  type        = string
  description = "Shape"
  default     = "odb.standard"
}

variable "data_storage_size_gb" {
  type        = number
  description = "Storage size in GB"
  default     = 256
}

variable "initial_data_storage_size_gb" {
  type        = number
  description = "Initial storage size in GB"
  default     = 256
}

variable "db_edition" {
  type        = string
  description = "Database Edition"
  default     = "ENTERPRISE_EDITION"
}

variable "license_type" {
  type        = string
  description = "License type"
  default     = "BRING_YOUR_OWN_LICENSE"
}

variable "db_version" {
  type        = string
  description = "Oracle DB Version (19c or 23ai)"
  default     = "19c"
}

variable "db_name" {
  type        = string
  description = "Database Name"
  default     = "ORCL"
}

variable "db_unique_name" {
  type        = string
  description = "Database Unique Name"
  default     = "ORCL_GCP"
}

variable "admin_pw" {
  type        = string
  description = "Admin password"
  sensitive   = true
}

variable "tde_pw" {
  type        = string
  description = "TDE Wallet password"
  sensitive   = true
}

variable "db_id" {
  type        = string
  description = "Database ID"
  default     = "orcl"
}

variable "enable_unified_auditing" {
  type        = bool
  description = "Enable unified auditing"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection"
  default     = true
}
