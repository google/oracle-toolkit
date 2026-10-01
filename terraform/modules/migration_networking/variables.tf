variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "create_networking" {
  description = "Set to false if the VPC network and subnets already exist and should only be referenced"
  type        = bool
  default     = true
}


variable "region" {
  description = "GCP Region for subnets"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "zdm-migration-vpc"
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
  default     = "zdm-migration-subnet"
}

variable "subnet_cidr" {
  description = "The CIDR range for the subnet"
  type        = string
  default     = "10.140.0.0/20"
}

variable "source_db_ips" {
  description = "List of Source Database IP addresses or CIDR blocks for firewall rules"
  type        = list(string)
  default     = []
}

variable "target_db_ips" {
  description = "List of Target Database IP addresses or CIDR blocks for firewall rules"
  type        = list(string)
  default     = []
}

variable "create_odb_subnet" {
  description = "Set to true to create a dedicated subnetwork for Oracle Database@Google Cloud (ODB@GCP)"
  type        = bool
  default     = false
}

variable "odb_subnet_cidr" {
  description = "The CIDR range for the ODB delegated subnet"
  type        = string
  default     = "10.156.0.0/24"
}

variable "odb_subnet_name" {
  description = "The name of the ODB delegated subnet"
  type        = string
  default     = "zdm-odb-subnet"
}

