variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "zone" {
  description = "GCP Zone to deploy the target database instance"
  type        = string
}

variable "instance_name" {
  description = "Name of the target database VM instance"
  type        = string
  default     = "oracle-gce-target-db"
}

variable "machine_type" {
  description = "Machine type for the Oracle GCE target instance"
  type        = string
  default     = "n2-standard-8"
}

variable "subnet_name" {
  description = "Name of the VPC Subnet to attach the instance network interface to"
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key to associate with the VM user"
  type        = string
}

variable "u01_disk_size" {
  description = "Size in GB for the /u01 Oracle installation binary disk"
  type        = number
  default     = 100
}

variable "data_disk_size" {
  description = "Size in GB for the Oracle Data files disk"
  type        = number
  default     = 200
}

variable "reco_disk_size" {
  description = "Size in GB for the Oracle Redo/Recovery files disk"
  type        = number
  default     = 100
}
