terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.38.0"
    }
  }
}

# Configure the Google Provider
provider "google" {
  project = "nodal-talon-445602-m1"
  region  = "us-central1"
}
