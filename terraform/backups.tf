# Bucket for hourly application-level database backups (clean SQLite copies).
# Private, versioned, and old backups are deleted automatically.
resource "google_storage_bucket" "db_backups" {
  name     = "${var.project_id}-db-backups"
  location = upper(var.region)

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    purpose     = "db-backups"
    managed_by  = "terraform"
  }
}