output "autonomous_database_id" {
  description = "The ID of the created Autonomous Database"
  value       = google_oracle_database_autonomous_database.adb.autonomous_database_id
}

output "id" {
  description = "The full GCP resource ID of the Autonomous Database"
  value       = google_oracle_database_autonomous_database.adb.id
}

output "state" {
  description = "Current lifecycle state of the Autonomous Database"
  value       = google_oracle_database_autonomous_database.adb.state
}
