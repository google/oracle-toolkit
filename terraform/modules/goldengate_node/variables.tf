variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "zone" {
  description = "GCP Zone to deploy the GoldenGate instance"
  type        = string
}

variable "instance_name" {
  description = "Name of the GoldenGate VM instance"
  type        = string
  default     = "goldengate-hub-node"
}

variable "machine_type" {
  description = "Machine type for the GoldenGate GCE instance"
  type        = string
  default     = "n2-standard-4"
}

variable "subnet_name" {
  description = "Name of the VPC Subnet to attach the instance network interface to"
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key to associate with the VM user"
  type        = string
}

variable "disk_size" {
  description = "Size in GB for GoldenGate installation and trail storage"
  type        = number
  default     = 100
}
