# Level 4: know when the site is down before the users do.

# Google checks the site over HTTPS every minute from several regions.
resource "google_monitoring_uptime_check_config" "site" {
  display_name = "Website HTTPS"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.site_host
    }
  }
}

# Where alerts go.
resource "google_monitoring_notification_channel" "email" {
  display_name = "Site owner email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

# Alert when the check fails from more than one region for a minute.
resource "google_monitoring_alert_policy" "site_down" {
  display_name = "Website is down"
  combiner     = "OR"

  conditions {
    display_name = "Uptime check failing"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.site.uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "60s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.host"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

# Alert when no backup has been uploaded for 2 hours (the hourly job stopped or is failing).
resource "google_monitoring_alert_policy" "backup_missing" {
  display_name = "Database backup missing"
  combiner     = "OR"

  conditions {
    display_name = "No backup uploaded for 2 hours"
    condition_absent {
      filter   = "metric.type=\"storage.googleapis.com/api/request_count\" AND resource.type=\"gcs_bucket\" AND resource.label.bucket_name=\"${google_storage_bucket.db_backups.name}\" AND metric.label.method=\"WriteObject\" AND metric.label.response_code=\"OK\""
      duration = "7200s"

      aggregations {
        alignment_period   = "3600s"
        per_series_aligner = "ALIGN_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

# Alert when the server's CPU stays above 80% for 10 minutes (built-in VM metric, no agent needed).
resource "google_monitoring_alert_policy" "cpu_high" {
  display_name = "Server CPU high"
  combiner     = "OR"

  conditions {
    display_name = "CPU above 80% for 10 minutes"
    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\" AND metadata.system_labels.name=\"${var.instance_name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "600s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}