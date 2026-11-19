output "vm_cluster_id" {
  description = "The ID of the created Exadata VM Cluster"
  value       = google_oracle_database_cloud_vm_cluster.exadata_vm_cluster.cloud_vm_cluster_id
}

output "id" {
  description = "The full GCP resource ID of the Exadata VM Cluster"
  value       = google_oracle_database_cloud_vm_cluster.exadata_vm_cluster.id
}

output "state" {
  description = "Current lifecycle state of the Exadata VM Cluster"
  value       = google_oracle_database_cloud_vm_cluster.exadata_vm_cluster.state
}
