output "exadata_infrastructure_id" {
  description = "The ID of the created Exadata Infrastructure"
  value       = google_oracle_database_cloud_exadata_infrastructure.exadata_infrastructure.cloud_exadata_infrastructure_id
}

output "id" {
  description = "The full GCP resource ID of the Exadata Infrastructure"
  value       = google_oracle_database_cloud_exadata_infrastructure.exadata_infrastructure.id
}

output "db_servers" {
  description = "List of DB Servers provisioned within the Exadata Infrastructure"
  value       = data.google_oracle_database_db_servers.db_servers.db_servers
}
