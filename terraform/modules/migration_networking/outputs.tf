output "network_id" {
  description = "The ID of the VPC network"
  value       = var.create_networking ? google_compute_network.vpc[0].id : "projects/${var.project_id}/global/networks/${var.network_name}"
}

output "network_name" {
  description = "The name of the VPC network"
  value       = var.create_networking ? google_compute_network.vpc[0].name : var.network_name
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = var.create_networking ? google_compute_subnetwork.subnet[0].id : "projects/${var.project_id}/regions/${var.region}/subnetworks/${var.subnet_name}"
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = var.create_networking ? google_compute_subnetwork.subnet[0].name : var.subnet_name
}

output "subnet_cidr" {
  description = "The CIDR range of the subnet"
  value       = var.create_networking ? google_compute_subnetwork.subnet[0].ip_cidr_range : var.subnet_cidr
}

output "odb_subnet_name" {
  description = "The name of the ODB delegated subnet"
  value       = var.create_odb_subnet ? (var.create_networking ? google_compute_subnetwork.odb_subnet[0].name : var.odb_subnet_name) : ""
}

output "odb_subnet_cidr" {
  description = "The CIDR range of the ODB delegated subnet"
  value       = var.create_odb_subnet ? (var.create_networking ? google_compute_subnetwork.odb_subnet[0].ip_cidr_range : var.odb_subnet_cidr) : ""
}

