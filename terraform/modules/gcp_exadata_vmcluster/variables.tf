variable "location" {
  type        = string
  description = "GCP region where services are hosted"
}

variable "exa_infra_project" {
  type        = string
  description = "The ID of the project in which the Exadata infrastructure belongs"
}

variable "cloud_exadata_infrastructure_id" {
  type        = string
  description = "The name of the Exadata infrastructure"
}

variable "cloud_vm_cluster_id" {
  type        = string
  description = "The name of the Exadata VM Cluster"
}

variable "exa_vm_project" {
  type        = string
  description = "The ID of the project in which the Exadata VM cluster belongs"
}

variable "vpc_project" {
  type        = string
  description = "Project ID for the shared VPC"
}

variable "odb_network_id" {
  type        = string
  description = "The name of the ODB Network"
}

variable "odb_client_subnet_id" {
  type        = string
  description = "The name of the ODB Subnet used for the client network"
}

variable "odb_backup_subnet_id" {
  type        = string
  description = "The name of the ODB Subnet used for the backup network"
}

variable "license_type" {
  type        = string
  description = "Either BRING_YOUR_OWN_LICENSE or LICENSE_INCLUDED"
  default     = "BRING_YOUR_OWN_LICENSE"
}

variable "ssh_public_keys" {
  type        = set(string)
  description = "SSH public keys for VM cluster nodes"
}

variable "cpu_core_count" {
  type        = number
  description = "Number of ECPUs assigned in total to all VMs in the cluster"
  default     = 32
}

variable "memory_size_gb" {
  type        = number
  description = "Amount of memory in GB assigned in total to all VMs in the cluster"
  default     = 60
}

variable "db_node_storage_size_gb" {
  type        = number
  description = "Amount of local storage in GB assigned in total to all VMs in the cluster"
  default     = 120
}

variable "data_storage_size_tb" {
  type        = number
  description = "Data storage size in TB"
  default     = 2
}

variable "gi_version" {
  type        = string
  description = "The Grid Infrastructure (GI) version of the Exadata VM Cluster"
  default     = "19.0.0.0"
}

variable "hostname_prefix" {
  type        = string
  description = "The hostname prefix of the Exadata VM Cluster"
}

variable "deletion_protection" {
  type        = bool
  description = "When set to true resources will be protected from accidental deletion"
  default     = true
}
