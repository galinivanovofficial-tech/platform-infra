# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "projects/project-aee592e9-ccea-48e5-bb0/regions/us-central1/resourcePolicies/default-schedule-1"
resource "google_compute_resource_policy" "snapshots" {
  description = null
  name        = "default-schedule-1"
  project     = var.project_id
  region      = var.region
  snapshot_schedule_policy {
    retention_policy {
      max_retention_days    = 14
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "05:00"
      }
    }
    snapshot_properties {
      chain_name        = null
      guest_flush       = false
      labels            = {}
      storage_locations = []
    }
  }
}
