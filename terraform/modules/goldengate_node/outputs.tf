output "ogg_private_ip" {
  description = "The private IP address of the GoldenGate GCE instance"
  value       = google_compute_instance.ogg_instance.network_interface[0].network_ip
}

output "ogg_instance_name" {
  description = "The VM instance name of the GoldenGate Node"
  value       = google_compute_instance.ogg_instance.name
}
