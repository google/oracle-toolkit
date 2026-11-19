output "autonomous_database_id" {
  description = "ID of Autonomous Database"
  value       = module.autonomous_database.autonomous_database_id
}

output "odb_network_id" {
  description = "ID of ODB Network"
  value       = module.odb_network.odb_network_id
}

output "odb_client_subnet_id" {
  description = "ID of Client ODB Subnet"
  value       = module.odb_client_subnet.odb_subnet_id
}
