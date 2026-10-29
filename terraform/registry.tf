# Level 2: private registry for the website's container images.

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "web" {
  repository_id = "web"
  location      = var.region
  format        = "DOCKER"
  description   = "Container images of the website"

  # Keep the 5 newest images, delete anything older than 30 days (stays in the free tier).
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "2592000s"
    }
  }

  depends_on = [google_project_service.artifactregistry]
}

# The server can pull (read) images, nothing more.
resource "google_artifact_registry_repository_iam_member" "web_reader" {
  location   = google_artifact_registry_repository.web.location
  repository = google_artifact_registry_repository.web.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.web.email}"
}

output "image_repo" {
  description = "Where website images are pushed"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.web.repository_id}"
}