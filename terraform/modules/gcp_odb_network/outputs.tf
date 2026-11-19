output "odb_network_id" {
  description = "The ID of the created ODB Network"
  value       = google_oracle_database_odb_network.odb_network.odb_network_id
}

output "id" {
  description = "The full GCP resource ID of the ODB Network"
  value       = google_oracle_database_odb_network.odb_network.id
}

output "state" {
  description = "Current lifecycle state of the ODB Network"
  value       = google_oracle_database_odb_network.odb_network.state
}
