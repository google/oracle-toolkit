variable "network_name" {
  type        = string
  description = "The name of the VPC network used by the ODB Network"
}

variable "vpc_project" {
  type        = string
  description = "The ID of the project in which the resource belongs."
}

variable "odb_network_id" {
  type        = string
  description = "The name of the ODB Network"
}

variable "location" {
  type        = string
  description = "GCP region where services are hosted"
}

variable "gcp_oracle_zone" {
  type        = string
  description = "The zone where the ODB Network will reside"
  default     = "Any"
}

variable "deletion_protection" {
  type        = bool
  description = "When set to true resources will be protected from accidental deletion"
  default     = true
}
