output "gke_cluster_endpoint" {
  description = "The GKE control plane API endpoint"
  value       = google_container_cluster.gke_cluster.endpoint
}

output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.gke_cluster.name
}

output "zdm_deployment_name" {
  description = "The name of the ZDM deployment inside GKE"
  value       = "zdm-deployment"
}

output "gcs_bucket_name" {
  description = "The name of the GCS bucket"
  value       = module.storage.bucket_name
}

output "gke_cluster_ca_certificate" {
  description = "The GKE cluster CA certificate"
  value       = google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate
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
