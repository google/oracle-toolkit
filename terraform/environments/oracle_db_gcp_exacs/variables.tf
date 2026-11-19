variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region for ODB@GCP deployment"
  default     = "europe-west3"
}

variable "zone" {
  type        = string
  description = "GCP Zone for Exadata Infrastructure"
  default     = "europe-west3-a"
}

variable "create_vpc" {
  type        = bool
  description = "Whether to create a new VPC or use existing"
  default     = true
}

variable "vpc_name" {
  type        = string
  description = "VPC Network name"
  default     = "ora-exacs-vpc"
}

variable "gcp_subnet_cidr" {
  type        = string
  description = "CIDR range for primary GCP subnet"
  default     = "10.140.0.0/20"
}

variable "odb_network_id" {
  type        = string
  description = "Resource ID for ODB Network"
  default     = "ora-exacs-odb-net"
}

variable "odb_client_subnet_id" {
  type        = string
  description = "Resource ID for Client ODB Subnet"
  default     = "ora-exacs-client-subnet"
}

variable "odb_client_subnet_cidr" {
  type        = string
  description = "CIDR range for delegated Client Subnet"
  default     = "10.150.20.0/24"
}

variable "odb_backup_subnet_id" {
  type        = string
  description = "Resource ID for Backup ODB Subnet"
  default     = "ora-exacs-backup-subnet"
}

variable "odb_backup_subnet_cidr" {
  type        = string
  description = "CIDR range for delegated Backup Subnet"
  default     = "10.150.21.0/24"
}

variable "cloud_exadata_infrastructure_id" {
  type        = string
  description = "Name/ID of Cloud Exadata Infrastructure"
  default     = "exa-infra-primary"
}

variable "exadata_shape" {
  type        = string
  description = "Shape: Exadata.X11M"
  default     = "Exadata.X11M"
}

variable "compute_count" {
  type        = number
  description = "Number of compute servers (min 2)"
  default     = 2
}

variable "storage_count" {
  type        = number
  description = "Number of storage servers (min 3)"
  default     = 3
}

variable "cloud_vm_cluster_id" {
  type        = string
  description = "Resource ID for Exadata VM Cluster"
  default     = "exa-vmcluster-primary"
}

variable "license_type" {
  type        = string
  description = "BRING_YOUR_OWN_LICENSE or LICENSE_INCLUDED"
  default     = "BRING_YOUR_OWN_LICENSE"
}

variable "ssh_public_keys" {
  type        = set(string)
  description = "SSH public keys for cluster VM nodes"
}

variable "cpu_core_count" {
  type        = number
  description = "Total number of ECPUs across cluster"
  default     = 32
}

variable "memory_size_gb" {
  type        = number
  description = "Total RAM size in GB"
  default     = 60
}

variable "db_node_storage_size_gb" {
  type        = number
  description = "Local node storage in GB"
  default     = 120
}

variable "data_storage_size_tb" {
  type        = number
  description = "Usable DATA storage capacity in TB"
  default     = 2
}

variable "gi_version" {
  type        = string
  description = "Grid Infrastructure version (19.0.0.0 or 23.0.0.0)"
  default     = "19.0.0.0"
}

variable "hostname_prefix" {
  type        = string
  description = "Hostname prefix for cluster nodes"
  default     = "exanode"
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection"
  default     = true
}
