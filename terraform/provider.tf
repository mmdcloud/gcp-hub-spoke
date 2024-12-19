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
  project = "our-mediator-443812-i8"
  region  = "us-central1"
}
