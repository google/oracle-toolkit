output "bucket_name" {
  description = "The name of the GCS bucket"
  value       = var.create_bucket ? google_storage_bucket.zdm_bucket[0].name : var.bucket_name
}

output "bucket_url" {
  description = "The URL of the GCS bucket"
  value       = var.create_bucket ? google_storage_bucket.zdm_bucket[0].url : "gs://${var.bucket_name}"
}
