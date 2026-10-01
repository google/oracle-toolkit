variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for the storage bucket"
  type        = string
}

variable "bucket_name" {
  description = "The name of the GCS bucket for ZDM backups and dumps"
  type        = string
}

variable "zdm_service_account_email" {
  description = "The email of the ZDM Service Account to grant storage admin access"
  type        = string
}

variable "create_bucket" {
  description = "Set to false if the GCS bucket already exists and should only be reused (IAM role granted)"
  type        = bool
  default     = true
}

