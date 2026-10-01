variable "odb_subnet_id" {
  type        = string
  description = "The name of the ODB Subnet"
}

variable "location" {
  type        = string
  description = "GCP region where services are hosted"
}

variable "vpc_project" {
  type        = string
  description = "The ID of the project in which the resource belongs"
}

variable "odb_network_id" {
  type        = string
  description = "The name of the ODB Network"
}

variable "subnet_cidr_range" {
  type        = string
  description = "The CIDR range used for the ODB Subnet"
}

variable "subnet_purpose" {
  type        = string
  description = "The purpose of the ODB Subnet (e.g. CLIENT_SUBNET or BACKUP_SUBNET)"
  default     = "CLIENT_SUBNET"
}

variable "deletion_protection" {
  type        = bool
  description = "When set to true resources will be protected from accidental deletion"
  default     = true
}
