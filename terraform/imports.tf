# Level 1: adopt the server that was created by hand in the console.
# An import block tells Terraform "this resource already exists - take it over, don't create it".
# Run once with:  terraform plan -generate-config-out=generated.tf
# Terraform then reads the real VM and writes its configuration for us.
import {
  to = google_compute_instance.web
  id = "projects/${var.project_id}/zones/${var.zone}/instances/${var.instance_name}"
}

# The firewall rules that control who can reach the VM.
import {
  to = google_compute_firewall.allow_http
  id = "projects/${var.project_id}/global/firewalls/default-allow-http"
}

import {
  to = google_compute_firewall.allow_https
  id = "projects/${var.project_id}/global/firewalls/default-allow-https"
}

import {
  to = google_compute_firewall.allow_ssh
  id = "projects/${var.project_id}/global/firewalls/default-allow-ssh"
}
