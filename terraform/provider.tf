terraform {
  required_version = "~> 1.11.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  # backend "gcs" {
  #   bucket = "hub-spoke-tf-state"
  #   prefix = "state.tf"
  # }
}

# Configure the Google Provider
provider "google" {
  project = "encoded-alpha-457108-e8"
  region  = "us-central1"
}

provider "vault" {}