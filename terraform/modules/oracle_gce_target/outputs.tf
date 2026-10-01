output "target_private_ip" {
  description = "The private IP address of the Oracle GCE target database instance"
  value       = google_compute_instance.oracle_target.network_interface[0].network_ip
}

output "target_instance_name" {
  description = "The instance name of the GCE target database"
  value       = google_compute_instance.oracle_target.name
}
