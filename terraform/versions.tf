terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # State lives in a versioned GCS bucket, not on a laptop.
  # The bucket name is passed at init time: terraform init -backend-config="bucket=<name>"
  backend "gcs" {
    prefix = "platform-infra"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
