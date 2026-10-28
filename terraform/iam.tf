# Dedicated identity for the web server, with only the permissions it needs
# (instead of the default compute service account, which has broad project access).
resource "google_service_account" "web" {
  account_id   = "ivth-legion-web"
  display_name = "Web server (ivth-legion)"
  description  = "Runs the website VM: writes backups, logs and metrics only"
}

# Can ADD backup files to the backup bucket, but cannot read, overwrite or delete them.
resource "google_storage_bucket_iam_member" "web_backup_writer" {
  bucket = google_storage_bucket.db_backups.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.web.email}"
}

# Keeps the Ops Agent working: write logs and metrics.
resource "google_project_iam_member" "web_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.web.email}"
}

resource "google_project_iam_member" "web_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.web.email}"
}