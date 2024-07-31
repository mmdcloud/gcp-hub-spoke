resource "google_compute_network" "vpc1" {
  name                            = "vpc1"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
}

resource "google_compute_subnetwork" "vpc1-subnets" {
  count                    = 3
  name                     = "vpc1-subnet${count.index + 1}"
  ip_cidr_range            = var.ip_cidr_range1[count.index]
  region                   = var.region
  network                  = google_compute_network.vpc1.id
  private_ip_google_access = true
}

resource "google_compute_network" "vpc2" {
  name                            = "vpc2"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
}

resource "google_compute_subnetwork" "vpc2-subnets" {
  count                    = 3
  name                     = "vpc2-subnet${count.index + 1}"
  ip_cidr_range            = var.ip_cidr_range2[count.index]
  region                   = var.region
  network                  = google_compute_network.vpc2.id
  private_ip_google_access = true
}

resource "google_network_connectivity_hub" "hub" {
  name        = "hub"
  description = "A sample hub"
  labels = {
    name = "hub"
  }
}

resource "google_network_connectivity_spoke" "spoke1" {
  name     = "spoke1"
  location = "global"
  hub      = google_network_connectivity_hub.hub.id
  linked_vpc_network {
    uri = google_compute_network.vpc1.self_link
  }
}

resource "google_network_connectivity_spoke" "spoke2" {
  name     = "spoke2"
  location = "global"
  hub      = google_network_connectivity_hub.hub.id
  linked_vpc_network {
    uri = google_compute_network.vpc2.self_link
  }
}

resource "google_compute_instance" "instance1" {
  name         = "instance1"
  machine_type = "e2-micro"
  zone         = "us-central1-a"
  network_interface {
    network    = google_compute_network.vpc1.id
    subnetwork = google_compute_subnetwork.vpc1-subnets[0].id
  }
  metadata_startup_script = "sudo apt-get update; sudo apt-get install nginx"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
    }
  }
  deletion_protection       = false
  allow_stopping_for_update = true
}

resource "google_compute_instance" "instance2" {

  name                    = "instance2"
  machine_type            = "e2-micro"
  zone                    = "us-central1-a"
  metadata_startup_script = "sudo apt-get update; sudo apt-get install nginx"
  network_interface {
    network    = google_compute_network.vpc2.id
    subnetwork = google_compute_subnetwork.vpc2-subnets[0].id
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
    }
  }
  deletion_protection       = false
  allow_stopping_for_update = true
}
