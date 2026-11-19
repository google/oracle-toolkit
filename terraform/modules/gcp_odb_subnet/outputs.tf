output "odb_subnet_id" {
  description = "The ID of the created ODB Subnet"
  value       = google_oracle_database_odb_subnet.odb_subnet.odb_subnet_id
}

output "id" {
  description = "The full GCP resource ID of the ODB Subnet"
  value       = google_oracle_database_odb_subnet.odb_subnet.id
}

output "state" {
  description = "Current lifecycle state of the ODB Subnet"
  value       = google_oracle_database_odb_subnet.odb_subnet.state
}
