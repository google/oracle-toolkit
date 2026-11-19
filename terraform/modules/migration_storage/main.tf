resource "google_storage_bucket" "zdm_bucket" {
  count                       = var.create_bucket ? 1 : 0
  name                        = var.bucket_name
  project                     = var.project_id
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition {
      age = 30 # Auto-delete dumps/backups older than 30 days
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "zdm_sa_access" {
  bucket = var.create_bucket ? google_storage_bucket.zdm_bucket[0].name : var.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.zdm_service_account_email}"
}
