# VPC1 
module "vpc1" {
  source                          = "./modules/vpc"
  vpc_name                        = "connectivity-vpc1"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  ip_cidr_ranges                  = var.ip_cidr_range1
  region                          = var.region
  private_ip_google_access        = false
  firewall_data = [
    {
      name          = "connectivity-vpc1-firewall"
      source_ranges = [module.instance2.network_ip]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "connectivity-vpc1-firewall-ssh"
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  ]
}

# VPC2 
module "vpc2" {
  source                          = "./modules/vpc"
  vpc_name                        = "connectivity-vpc2"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  ip_cidr_ranges                  = var.ip_cidr_range2
  region                          = var.region
  private_ip_google_access        = false
  firewall_data = [
    {
      name          = "connectivity-vpc2-firewall"
      source_ranges = [module.instance1.network_ip]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "connectivity-vpc2-firewall-ssh"
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  ]
}

module "hub-spoke" {
  source          = "./modules/hub-spoke"
  hub_name        = "hub"
  hub_description = "A sample hub"
  spokes = [
    {
      spoke_name             = "spoke1"
      location               = "global"
      linked_vpc_network_uri = module.vpc1.self_link
    },
    {
      spoke_name             = "spoke2"
      location               = "global"
      linked_vpc_network_uri = module.vpc2.self_link
    }
  ]
}

resource "google_compute_address" "instance1_ip" {
  name = "instance1-address"
}

# Instance 1
module "instance1" {
  source                    = "./modules/compute"
  name                      = "connectivity-instance1"
  machine_type              = "e2-micro"
  zone                      = "us-central1-a"
  metadata_startup_script   = "sudo apt-get update; sudo apt-get install nginx -y"
  deletion_protection       = false
  allow_stopping_for_update = true
  image                     = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
  network_interfaces = [
    {
      network    = module.vpc1.vpc_id
      subnetwork = module.vpc1.subnets[0].id
      access_configs = [
        {
          nat_ip = google_compute_address.instance1_ip.address
        }
      ]
    }
  ]
}

resource "google_compute_address" "instance2_ip" {
  name = "instance2-address"
}

# Instance 2
module "instance2" {
  source                    = "./modules/compute"
  name                      = "connectivity-instance2"
  machine_type              = "e2-micro"
  zone                      = "us-central1-a"
  metadata_startup_script   = "sudo apt-get update; sudo apt-get install nginx -y"
  deletion_protection       = false
  allow_stopping_for_update = true
  image                     = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
  network_interfaces = [
    {
      network    = module.vpc2.vpc_id
      subnetwork = module.vpc2.subnets[0].id
      access_configs = [
        {
          nat_ip = google_compute_address.instance2_ip.address
        }
      ]
    }
  ]
}