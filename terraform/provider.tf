terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Configure the Google Provider
provider "google" {
  project = "orbital-bee-455915-h5"
  region  = "us-central1"
}
