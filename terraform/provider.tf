terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "hub-spoke-tf-state"
    prefix = "state.tf"
  }
}

# Configure the Google Provider
provider "google" {
  project = "encoded-alpha-457108-e8"
  region  = "us-central1"
}

provider "vault" {}