variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "zone" {
  description = "The zone to deploy the ZDM instance in"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network to attach the instance to"
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnet to attach the instance to"
  type        = string
}

variable "instance_name" {
  description = "The name of the ZDM VM instance"
  type        = string
  default     = "zdm-service-node"
}

variable "machine_type" {
  description = "Compute instance machine type"
  type        = string
  default     = "e2-standard-4"
}

variable "zdm_software_bucket" {
  description = "GCS bucket containing the ZDM software ZIP (optional)"
  type        = string
  default     = ""
}

variable "zdm_software_zip" {
  description = "Name of the ZDM software ZIP file in the bucket (optional)"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key to add to the ZDM VM for remote access"
  type        = string
}

variable "install_docker" {
  description = "Whether to install Docker on the ZDM VM (useful for running GoldenGate container)"
  type        = bool
  default     = false
}

variable "create_service_account" {
  description = "Set to false if the service account already exists and should only be referenced"
  type        = bool
  default     = true
}


