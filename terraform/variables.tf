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
