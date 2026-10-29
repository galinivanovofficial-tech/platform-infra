variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Region of the VM (the e2-micro free tier is us-west1, us-central1 or us-east1)"
  type        = string
}

variable "zone" {
  description = "Zone of the VM, e.g. us-central1-a"
  type        = string
}

variable "instance_name" {
  description = "Name of the existing web server VM"
  type        = string
}
variable "environment" {
  description = "Deployment environment, used in resource labels"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging"], var.environment)
    error_message = "environment must be either \"production\" or \"staging\"."
  }
}
variable "site_host" {
  description = "Public hostname of the website"
  type        = string
  default     = "ivthlegion-136-71-178-20.sslip.io"
}

variable "alert_email" {
  description = "Where alerts are sent (kept in terraform.tfvars, not in Git)"
  type        = string
}
variable "billing_account" {
  description = "Billing account ID the budget watches"
  type        = string
}
variable "github_repo" {
  description = "GitHub repository (owner/name) allowed to deploy"
  type        = string
  default     = "galinivanovofficial-tech/IVth-Legion-Website"
}