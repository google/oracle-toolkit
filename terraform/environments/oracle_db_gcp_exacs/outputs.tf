output "exadata_infrastructure_id" {
  description = "The ID of the Exadata Infrastructure"
  value       = module.exadata_infrastructure.cloud_exadata_infrastructure_id
}

output "exadata_vm_cluster_id" {
  description = "The ID of the Exadata VM Cluster"
  value       = module.exadata_vmcluster.cloud_vm_cluster_id
}

output "odb_network_id" {
  description = "The ID of the ODB Network"
  value       = module.odb_network.odb_network_id
}

output "odb_client_subnet_id" {
  description = "The ID of the Client ODB Subnet"
  value       = module.odb_client_subnet.odb_subnet_id
}

output "odb_backup_subnet_id" {
  description = "The ID of the Backup ODB Subnet"
  value       = module.odb_backup_subnet.odb_subnet_id
}
