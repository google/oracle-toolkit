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
  description = "The name/ID of the Exadata infrastructure"
}

variable "gcp_oracle_zone" {
  type        = string
  description = "The zone where the Exadata infrastructure will reside"
}

variable "shape" {
  type        = string
  description = "The shape for the Exadata infrastructure (e.g. Exadata.X11M)"
  default     = "Exadata.X11M"
}

variable "compute_count" {
  type        = number
  description = "The number of compute servers used by the infrastructure"
  default     = 2
}

variable "storage_count" {
  type        = number
  description = "The number of storage servers used by the infrastructure"
  default     = 3
}

variable "deletion_protection" {
  type        = bool
  description = "When set to true resources will be protected from accidental deletion"
  default     = true
}
