variable "autonomous_database_id" {
  type        = string
  description = "The name/ID of the Autonomous Database"
}

variable "location" {
  type        = string
  description = "GCP region where services are hosted"
}

variable "adb_project" {
  type        = string
  description = "The ID of the project in which the ADB belongs"
}

variable "adb_admin_pw" {
  type        = string
  description = "The admin password of your Autonomous Database"
  sensitive   = true
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

variable "ecpu_count" {
  type        = number
  description = "The number of ECPUs available to the instance"
  default     = 2
}

variable "data_storage_size_gb" {
  type        = number
  description = "Data storage size in GB"
  default     = 20
}

variable "data_storage_size_tb" {
  type        = number
  description = "Data storage size in TB (optional)"
  default     = null
}

variable "db_version" {
  type        = string
  description = "Oracle Database version (19c, 23ai)"
  default     = "19c"
}

variable "workload_type" {
  type        = string
  description = "Workload type: OLTP, DW, AJD, APEX"
  default     = "OLTP"
}

variable "db_edition" {
  type        = string
  description = "Database Edition: STANDARD_EDITION or ENTERPRISE_EDITION"
  default     = "ENTERPRISE_EDITION"
}

variable "license_type" {
  type        = string
  description = "License model: BRING_YOUR_OWN_LICENSE or LICENSE_INCLUDED"
  default     = "BRING_YOUR_OWN_LICENSE"
}

variable "backup_retention_period_days" {
  type        = number
  description = "Retention period for automated backups in days"
  default     = 60
}

variable "is_auto_scaling_enabled" {
  type        = bool
  description = "Enable compute auto scaling"
  default     = true
}

variable "is_storage_auto_scaling_enabled" {
  type        = bool
  description = "Enable storage auto scaling"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "When set to true resources will be protected from accidental deletion"
  default     = true
}
