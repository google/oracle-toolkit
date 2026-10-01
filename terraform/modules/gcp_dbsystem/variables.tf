variable "db_system_id" {
  type        = string
  description = "The name/ID of the DB system"
}

variable "location" {
  type        = string
  description = "GCP region where services are hosted"
}

variable "gcp_oracle_zone" {
  type        = string
  description = "Oracle Database@Google Cloud zone where services are hosted"
}

variable "dbsystem_project" {
  type        = string
  description = "The ID of the project in which the DB system belongs"
}

variable "vpc_project" {
  type        = string
  description = "The ID of the project in which the ODB Network belongs"
}

variable "odb_network_id" {
  type        = string
  description = "The name of the ODB Network"
}

variable "odb_subnet_id" {
  type        = string
  description = "Name of the ODB Subnet"
}

variable "ssh_public_keys" {
  type        = set(string)
  description = "SSH public keys for the DB system nodes"
}

variable "ecpu_core_count" {
  type        = number
  description = "The number of ECPUs available to the DB system. Minimum value is 4 and must be a multiple of 4"
  default     = 4
}

variable "hostname_prefix" {
  type        = string
  description = "Hostname prefix for DB system nodes"
}

variable "data_storage_size_gb" {
  type        = number
  description = "Storage size in GB for database data"
  default     = 256
}

variable "initial_data_storage_size_gb" {
  type        = number
  description = "Initial data storage size in GB"
  default     = 256
}

variable "shape" {
  type        = string
  description = "Hardware shape (e.g. VM.Standard.x86)"
  default     = "VM.Standard.x86"
}

variable "db_edition" {
  type        = string
  description = "Database edition (ENTERPRISE_EDITION, HIGH_PERFORMANCE, EXTREME_PERFORMANCE)"
  default     = "ENTERPRISE_EDITION"
}

variable "license_type" {
  type        = string
  description = "License model: BRING_YOUR_OWN_LICENSE or LICENSE_INCLUDED"
  default     = "BRING_YOUR_OWN_LICENSE"
}

variable "db_version" {
  type        = string
  description = "Oracle Database version (19c, 23ai)"
  default     = "19c"
}

variable "db_name" {
  type        = string
  description = "Database Name (DB_NAME)"
  default     = "ORCL"
}

variable "db_unique_name" {
  type        = string
  description = "Database Unique Name (DB_UNIQUE_NAME)"
  default     = "ORCL_tgt"
}

variable "db_id" {
  type        = string
  description = "Database ID / SID"
  default     = "orcl"
}

variable "admin_pw" {
  type        = string
  description = "SYS / SYSTEM admin password"
  sensitive   = true
}

variable "tde_pw" {
  type        = string
  description = "Transparent Data Encryption wallet password"
  sensitive   = true
}

variable "enable_unified_auditing" {
  type        = bool
  description = "Enable unified auditing on the database"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "When set to true resources will be protected from accidental deletion"
  default     = true
}
