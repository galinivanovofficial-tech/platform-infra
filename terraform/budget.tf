# Cost guard: the project should stay inside the free tier ($0).
# Emails as soon as any real cost appears, and again at 50% and 100% of $1.
resource "google_project_service" "cloudresourcemanager" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "billingbudgets" {
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

data "google_project" "this" {}

resource "google_billing_budget" "free_tier_guard" {
  provider        = google.billing
  billing_account = var.billing_account
  display_name    = "free-tier-guard"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "1"
    }
  }

  threshold_rules {
    threshold_percent = 0.01
  }
  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 1.0
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email.id]
    disable_default_iam_recipients   = false
  }

  depends_on = [google_project_service.billingbudgets]
}