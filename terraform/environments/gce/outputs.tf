output "vpc_network_name" {
  description = "The name of the VPC network"
  value       = module.networking.network_name
}

output "zdm_node_private_ip" {
  description = "The private IP address of the ZDM VM instance"
  value       = module.zdm_node.zdm_vm_private_ip
}

output "gcs_bucket_name" {
  description = "The name of the GCS bucket"
  value       = module.storage.bucket_name
}

output "target_database_private_ip" {
  description = "The private IP address of the newly provisioned Oracle GCE target database"
  value       = var.target_type == "gce" ? module.oracle_target_db[0].target_private_ip : ""
}

output "target_database_instance_name" {
  description = "The VM instance name of the target database on GCE"
  value       = var.target_type == "gce" ? module.oracle_target_db[0].target_instance_name : ""
}

output "odb_network_id" {
  description = "The ID of the provisioned Oracle Database@Google Cloud ODB Network"
  value       = var.create_odb_infrastructure ? module.gcp_odb_network[0].odb_network_id : ""
}

output "odb_db_system_id" {
  description = "The ID of the provisioned Base DB System (DBCS)"
  value       = (var.target_type == "dbcs" && var.create_target_dbsystem) ? module.gcp_dbsystem[0].db_system_id : ""
}

output "odb_exadata_vm_cluster_id" {
  description = "The ID of the provisioned Exadata VM Cluster"
  value       = (var.target_type == "exacs" && var.create_target_exadata) ? module.gcp_exadata_vmcluster[0].vm_cluster_id : ""
}

output "odb_autonomous_database_id" {
  description = "The ID of the provisioned Autonomous Database"
  value       = (var.target_type == "adb" && var.create_target_adb) ? module.gcp_adb[0].autonomous_database_id : ""
}
