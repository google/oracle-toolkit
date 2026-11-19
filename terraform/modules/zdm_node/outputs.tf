output "zdm_vm_name" {
  description = "The name of the ZDM VM instance"
  value       = google_compute_instance.zdm_vm.name
}

output "zdm_vm_private_ip" {
  description = "The private IP address of the ZDM VM instance"
  value       = google_compute_instance.zdm_vm.network_interface[0].network_ip
}

output "zdm_sa_email" {
  description = "The email of the ZDM Service Account"
  value       = var.create_service_account ? google_service_account.zdm_sa[0].email : "${var.instance_name}-sa@${var.project_id}.iam.gserviceaccount.com"
}
