output "db_system_id" {
  description = "The ID of the created DB system"
  value       = google_oracle_database_db_system.db_system.db_system_id
}

output "id" {
  description = "The full GCP resource ID of the DB system"
  value       = google_oracle_database_db_system.db_system.id
}

output "state" {
  description = "Current lifecycle state of the DB system"
  value       = google_oracle_database_db_system.db_system.state
}
