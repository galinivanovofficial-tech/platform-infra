# Daily disk snapshots of the web server: taken at 05:00 UTC, kept 14 days,
# and kept even if the disk is deleted. Crash-consistent (guest_flush = false).
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
