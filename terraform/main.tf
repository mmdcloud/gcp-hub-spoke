data "google_project" "project" {}

# -----------------------------------------------------------------------------------------
# Registering vault provider
# -----------------------------------------------------------------------------------------
data "vault_generic_secret" "vpn_shared_secret" {
  path = "secret/vpn-shared-secret"
}

data "google_compute_image" "ubuntu_2404" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

#---------------------------------------------------------------
# VPC1
#---------------------------------------------------------------
module "vpc1" {
  source                          = "./modules/vpc"
  vpc_name                        = "vpc1"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "vpc1-subnet"
      region                   = var.vpc1_region
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = var.vpc1_subnet_cidr
    }
  ]
  firewall_data = [
    {
      name          = "vpc1-instance1-ssh"
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["vpc1-instance"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
    {
      name          = "vpc1-instance2-firewall"
      source_ranges = [var.vpc2_subnet_cidr]
      target_tags   = ["vpc1-instance"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "vpc1-psc-instance-ping"
      source_ranges = [var.consumer_subnet_cidr]
      target_tags   = ["vpc1-instance"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "psc-vpc1-firewall"
      source_ranges = [google_compute_address.psc_consumer_ip.address]
      target_tags   = ["vpc1-instance"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["80"]
        }
      ]
    },
    {
      name          = "vpc1-vpn-allow"
      target_tags   = ["vpc1-instance"]
      source_ranges = [var.vpn_consumer_subnet_cidr]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    }
  ]
}

module "instance1" {
  source                    = "./modules/compute"
  name                      = "connectivity-instance1"
  machine_type              = var.machine_type
  zone                      = "${var.vpc1_region}-a"
  metadata_startup_script   = var.instance_startup_script
  deletion_protection       = false # should be true for production
  allow_stopping_for_update = true
  image                     = data.google_compute_image.ubuntu_2404.self_link
  network_interfaces = [
    {
      network        = module.vpc1.vpc_id
      subnetwork     = module.vpc1.subnets[0].id
      access_configs = []
    }
  ]
  tags = ["vpc1-instance"]
}

#---------------------------------------------------------------
# VPC2
#---------------------------------------------------------------
module "vpc2" {
  source                          = "./modules/vpc"
  vpc_name                        = "vpc2"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "vpc2-subnet"
      region                   = var.vpc2_region
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = var.vpc2_subnet_cidr
    }
  ]
  firewall_data = [
    {
      name          = "vpc2-instance2-ssh"
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["vpc2-instance"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
    {
      name          = "vpc2-instance1-firewall"
      source_ranges = [var.vpc1_subnet_cidr]
      target_tags   = ["vpc2-instance"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "vpc2-psc-instance-ping"
      source_ranges = [var.consumer_subnet_cidr]
      target_tags   = ["vpc2-instance"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "psc-vpc2-firewall"
      source_ranges = [google_compute_address.psc_consumer_ip.address]
      target_tags   = ["vpc2-instance"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["80"]
        }
      ]
    },
    {
      name          = "vpc2-vpn-allow"
      target_tags   = ["vpc2-instance"]
      source_ranges = [var.vpn_consumer_subnet_cidr]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    }
  ]
}

module "instance2" {
  source                    = "./modules/compute"
  name                      = "connectivity-instance2"
  machine_type              = var.machine_type
  zone                      = "${var.vpc2_region}-a"
  metadata_startup_script   = var.instance_startup_script
  deletion_protection       = false # should be true for production
  allow_stopping_for_update = true
  image                     = data.google_compute_image.ubuntu_2404.self_link
  network_interfaces = [
    {
      network        = module.vpc2.vpc_id
      subnetwork     = module.vpc2.subnets[0].id
      access_configs = []
    }
  ]
  tags = ["vpc2-instance"]
}

#---------------------------------------------------------------
# Private Service Connect Configuration
#---------------------------------------------------------------
module "consumer_vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "consumer-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "consumer-subnet"
      region                   = var.psc_region
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = var.consumer_subnet_cidr
    }
  ]
  firewall_data = [
    {
      name          = "psc-consumer-ssh"
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["psc-instance"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
    {
      name          = "psc-instance1-firewall"
      source_ranges = [var.vpc1_subnet_cidr]
      target_tags   = ["psc-instance"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "psc-instance2-firewall"
      source_ranges = [var.vpc2_subnet_cidr]
      target_tags   = ["psc-instance"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name               = "psc-consumer-instance-firewall"
      direction          = "INGRESS"
      source_ranges      = [var.vpc1_subnet_cidr]
      destination_ranges = [google_compute_address.psc_consumer_ip.address]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["80"]
        }
      ]
    },
    {
      name          = "psc-vpn-allow"
      target_tags   = ["psc-instance"]
      source_ranges = [var.vpn_consumer_subnet_cidr]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    }
  ]
}

module "producer_vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "producer-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "producer-subnet"
      region                   = var.psc_region
      purpose                  = "PRIVATE"
      private_ip_google_access = true
      role                     = "ACTIVE"
      ip_cidr_range            = var.producer_subnet_cidr
    },
    {
      name                     = "psc-subnet"
      region                   = var.psc_region
      purpose                  = "PRIVATE_SERVICE_CONNECT"
      private_ip_google_access = true
      role                     = "ACTIVE"
      ip_cidr_range            = var.producer_psc_subnet_cidr
    },
    {
      name                     = "proxy-only-subnet"
      region                   = var.psc_region
      purpose                  = "REGIONAL_MANAGED_PROXY"
      private_ip_google_access = false
      role                     = "ACTIVE"
      ip_cidr_range            = var.producer_proxy_subnet_cidr
    }
  ]
  firewall_data = []
}

module "artifact_registry" {
  source        = "./modules/artifact-registry"
  location      = var.psc_region
  description   = "nodeapp code repository"
  repository_id = var.artifact_repository_id
}

resource "null_resource" "build_and_push_image" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "bash ${path.cwd}/../src/artifact_push.sh ${var.psc_region} ${data.google_project.project.project_id}"
  }

  depends_on = [
    module.artifact_registry
  ]
}

module "cloud_run_service_account" {
  source        = "./modules/service-account"
  account_id    = "cloud-run-sa"
  display_name  = "Cloud Run Service Account"
  project_id    = data.google_project.project.project_id
  member_prefix = "serviceAccount"
  permissions = [
    "roles/artifactregistry.reader"
  ]
}

module "cloud_run_service" {
  source                           = "./modules/cloud-run"
  deletion_protection              = false # should be true for production
  ingress                          = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  service_account                  = module.cloud_run_service_account.sa_email
  location                         = var.psc_region
  min_instance_count               = var.cloud_run_min_instances
  max_instance_count               = var.cloud_run_max_instances
  max_instance_request_concurrency = var.cloud_run_concurrency
  name                             = var.cloud_run_service_name
  volumes                          = []
  traffic = [
    {
      traffic_type         = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
      traffic_type_percent = 100
    }
  ]
  containers = [
    {
      port              = var.cloud_run_container_port
      env               = []
      volume_mounts     = []
      cpu_idle          = true
      startup_cpu_boost = true
      image             = "${var.psc_region}-docker.pkg.dev/${data.google_project.project.project_id}/${var.artifact_repository_id}/${var.cloud_run_service_name}:latest"
    }
  ]
  depends_on = [null_resource.build_and_push_image]
}

resource "google_cloud_run_service_iam_member" "cloud_run_access" {
  count    = var.cloud_run_allow_unauthenticated ? 1 : 0
  location = var.psc_region
  project  = var.project_id
  service  = module.cloud_run_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

module "service_neg" {
  source       = "./modules/network_endpoint_groups"
  neg_name     = "service-neg"
  neg_type     = "SERVERLESS"
  location     = var.psc_region
  service_name = module.cloud_run_service.name
}

module "lb" {
  source             = "./modules/load-balancer"
  project_id         = var.project_id
  name               = "internal-lb"
  load_balancer_type = "INTERNAL"
  region             = var.psc_region
  network            = module.producer_vpc.self_link
  subnetwork         = module.producer_vpc.subnets[0].id

  backends = {
    lb = {
      is_default          = true
      protocol            = "HTTP"
      port_name           = "http"
      is_serverless_neg   = true
      manage_health_check = false
      groups = [
        { group = module.service_neg.id }
      ]
    }
  }

  enable_ssl              = false
  enable_http             = true
  managed_ssl_certificate = false
  enable_cloud_armor      = false
  depends_on              = [module.cloud_run_service]
}

resource "google_compute_service_attachment" "psc_attachment" {
  name                  = "psc-attachment"
  region                = var.psc_region
  description           = "Private Service Connect attachment for Cloud Run"
  project               = var.project_id
  enable_proxy_protocol = false
  connection_preference = "ACCEPT_AUTOMATIC"
  nat_subnets           = [module.producer_vpc.subnets[1].id]
  target_service        = module.lb.http_forwarding_rule_id
}

resource "google_compute_address" "psc_consumer_ip" {
  project      = var.project_id
  name         = "psc-consumer-ip"
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  region       = var.psc_region
  subnetwork   = module.consumer_vpc.subnets[0].id
}

resource "google_compute_forwarding_rule" "psc_consumer_forwarding_rule" {
  name                  = "psc-consumer-forwarding-rule"
  project               = var.project_id
  region                = var.psc_region
  load_balancing_scheme = ""
  target                = "projects/${var.project_id}/regions/${var.psc_region}/serviceAttachments/${google_compute_service_attachment.psc_attachment.name}"
  ip_address            = google_compute_address.psc_consumer_ip.self_link
  network               = module.consumer_vpc.vpc_id
}

module "consumer_instance" {
  source                    = "./modules/compute"
  name                      = "psc-instance"
  machine_type              = var.machine_type
  zone                      = "${var.psc_region}-a"
  metadata_startup_script   = var.instance_startup_script
  deletion_protection       = false # should be true for production
  allow_stopping_for_update = true
  image                     = data.google_compute_image.ubuntu_2404.self_link
  network_interfaces = [
    {
      network        = module.consumer_vpc.vpc_id
      subnetwork     = module.consumer_vpc.subnets[0].id
      access_configs = []
    }
  ]
  tags = ["psc-instance"]
}

# --------------------------------------------------------------------------
# VPN Configuration
# --------------------------------------------------------------------------
module "vpn_shared_secret" {
  source      = "./modules/secret-manager"
  secret_data = tostring(data.vault_generic_secret.vpn_shared_secret.data["secret"])
  secret_id   = "vpn_shared_secret"
}

module "vpn_producer_vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "vpn-producer-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "vpn-producer-subnet"
      region                   = var.vpn_region
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = var.vpn_producer_subnet_cidr
    }
  ]
  firewall_data = [
    {
      name          = "vpn-producer-ssh"
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["vpn-producer-instance"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
    {
      name          = "vpn-producer-vpc-allow-from-consumer-vpn"
      target_tags   = ["vpn-producer-instance"]
      source_ranges = [var.vpn_consumer_subnet_cidr]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "vpn-producer-instance1-firewall"
      source_ranges = [var.vpc1_subnet_cidr]
      target_tags   = ["vpn-producer-instance"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    }
  ]
}

module "vpn_consumer_vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "vpn-consumer-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "vpn-consumer-subnet"
      region                   = var.vpn_region
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = var.vpn_consumer_subnet_cidr
    }
  ]
  firewall_data = [
    {
      name          = "vpn-consumer-ssh"
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["vpn-consumer-instance"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
    {
      name          = "vpn-instance1-firewall"
      source_ranges = [var.vpc1_subnet_cidr]
      target_tags   = ["vpn-consumer-instance"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "vpn-instance2-firewall"
      source_ranges = [var.vpc2_subnet_cidr]
      target_tags   = ["vpn-consumer-instance"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "consumer-instance-vpn-firewall"
      source_ranges = [google_compute_address.psc_consumer_ip.address]
      target_tags   = ["vpn-consumer-instance"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["80"]
        }
      ]
    },
    {
      name          = "vpn-consumer-vpc-allow-from-producer-vpn"
      target_tags   = ["vpn-consumer-instance"]
      source_ranges = [var.vpn_producer_subnet_cidr]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    }
  ]
}

resource "google_compute_ha_vpn_gateway" "producer_gateway" {
  region     = var.vpn_region
  name       = "producer-vpn-gw"
  network    = module.vpn_producer_vpc.vpc_id
  stack_type = "IPV4_ONLY"
}

resource "google_compute_ha_vpn_gateway" "consumer_gateway" {
  region     = var.vpn_region
  name       = "consumer-vpn-gw"
  network    = module.vpn_consumer_vpc.vpc_id
  stack_type = "IPV4_ONLY"
}

# --- Cloud Routers (needed for dynamic/BGP routing over HA VPN) ---
resource "google_compute_router" "producer_router" {
  name    = "producer-router"
  region  = var.vpn_region
  network = module.vpn_producer_vpc.vpc_id
  bgp {
    asn = var.producer_bgp_asn
  }
}

resource "google_compute_router" "consumer_router" {
  name    = "consumer-router"
  region  = var.vpn_region
  network = module.vpn_consumer_vpc.vpc_id
  bgp {
    asn               = var.consumer_bgp_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"] # keep advertising vpn_consumer_vpc's own subnet too

    advertised_ip_ranges {
      range       = var.vpc1_subnet_cidr
      description = "vpc1 subnet via NCC hub"
    }
  }
}

# --- VPN Tunnels (single interface pair; see note below for full HA) ---
resource "google_compute_vpn_tunnel" "producer_to_consumer" {
  name                  = "producer-to-consumer-tunnel-0"
  region                = var.vpn_region
  vpn_gateway           = google_compute_ha_vpn_gateway.producer_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.consumer_gateway.id
  shared_secret         = module.vpn_shared_secret.secret_data
  router                = google_compute_router.producer_router.id
  vpn_gateway_interface = 0
}

resource "google_compute_vpn_tunnel" "producer_to_consumer_2" {
  name                  = "producer-to-consumer-tunnel-1"
  region                = var.vpn_region
  vpn_gateway           = google_compute_ha_vpn_gateway.producer_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.consumer_gateway.id
  shared_secret         = module.vpn_shared_secret.secret_data
  router                = google_compute_router.producer_router.id
  vpn_gateway_interface = 1
}

resource "google_compute_vpn_tunnel" "consumer_to_producer" {
  name                  = "consumer-to-producer-tunnel-0"
  region                = var.vpn_region
  vpn_gateway           = google_compute_ha_vpn_gateway.consumer_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.producer_gateway.id
  shared_secret         = module.vpn_shared_secret.secret_data
  router                = google_compute_router.consumer_router.id
  vpn_gateway_interface = 0
}

resource "google_compute_vpn_tunnel" "consumer_to_producer_2" {
  name                  = "consumer-to-producer-tunnel-1"
  region                = var.vpn_region
  vpn_gateway           = google_compute_ha_vpn_gateway.consumer_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.producer_gateway.id
  shared_secret         = module.vpn_shared_secret.secret_data
  router                = google_compute_router.consumer_router.id
  vpn_gateway_interface = 1
}

# --- Router interfaces + BGP peers (this is what actually exchanges routes) ---
resource "google_compute_router_interface" "producer_interface" {
  name       = "producer-router-if-0"
  router     = google_compute_router.producer_router.name
  region     = var.vpn_region
  ip_range   = var.producer_router_interface_ip_range
  vpn_tunnel = google_compute_vpn_tunnel.producer_to_consumer.name
}

resource "google_compute_router_peer" "producer_peer" {
  name            = "producer-router-peer-0"
  router          = google_compute_router.producer_router.name
  region          = var.vpn_region
  peer_ip_address = var.producer_peer_ip_address
  peer_asn        = var.consumer_bgp_asn
  interface       = google_compute_router_interface.producer_interface.name
}

resource "google_compute_router_interface" "producer_interface_2" {
  name       = "producer-router-if-1"
  router     = google_compute_router.producer_router.name
  region     = var.vpn_region
  ip_range   = var.producer_router_interface_ip_range_2
  vpn_tunnel = google_compute_vpn_tunnel.producer_to_consumer_2.name
}

resource "google_compute_router_peer" "producer_peer_2" {
  name            = "producer-router-peer-1"
  router          = google_compute_router.producer_router.name
  region          = var.vpn_region
  peer_ip_address = var.producer_peer_ip_address_2
  peer_asn        = var.consumer_bgp_asn
  interface       = google_compute_router_interface.producer_interface_2.name
}

resource "google_compute_router_interface" "consumer_interface" {
  name       = "consumer-router-if-0"
  router     = google_compute_router.consumer_router.name
  region     = var.vpn_region
  ip_range   = var.consumer_router_interface_ip_range
  vpn_tunnel = google_compute_vpn_tunnel.consumer_to_producer.name
}

resource "google_compute_router_peer" "consumer_peer" {
  name            = "consumer-router-peer-0"
  router          = google_compute_router.consumer_router.name
  region          = var.vpn_region
  peer_ip_address = var.consumer_peer_ip_address
  peer_asn        = var.producer_bgp_asn
  interface       = google_compute_router_interface.consumer_interface.name
}

resource "google_compute_router_interface" "consumer_interface_2" {
  name       = "consumer-router-if-1"
  router     = google_compute_router.consumer_router.name
  region     = var.vpn_region
  ip_range   = var.consumer_router_interface_ip_range_2
  vpn_tunnel = google_compute_vpn_tunnel.consumer_to_producer_2.name
}

resource "google_compute_router_peer" "consumer_peer_2" {
  name            = "consumer-router-peer-1"
  router          = google_compute_router.consumer_router.name
  region          = var.vpn_region
  peer_ip_address = var.consumer_peer_ip_address_2
  peer_asn        = var.producer_bgp_asn
  interface       = google_compute_router_interface.consumer_interface_2.name
}

module "vpn_consumer_instance" {
  source                    = "./modules/compute"
  name                      = "vpn-consumer-instance"
  machine_type              = var.machine_type
  zone                      = "${var.vpn_region}-a"
  metadata_startup_script   = var.instance_startup_script
  deletion_protection       = false # should be true for production
  allow_stopping_for_update = true
  image                     = data.google_compute_image.ubuntu_2404.self_link
  network_interfaces = [
    {
      network        = module.vpn_consumer_vpc.vpc_id
      subnetwork     = module.vpn_consumer_vpc.subnets[0].id
      access_configs = []
    }
  ]
  tags = ["vpn-consumer-instance"]
}

module "vpn_producer_instance" {
  source                    = "./modules/compute"
  name                      = "vpn-producer-instance"
  machine_type              = var.machine_type
  zone                      = "${var.vpn_region}-a"
  metadata_startup_script   = var.instance_startup_script
  deletion_protection       = false # should be true for production
  allow_stopping_for_update = true
  image                     = data.google_compute_image.ubuntu_2404.self_link
  network_interfaces = [
    {
      network        = module.vpn_producer_vpc.vpc_id
      subnetwork     = module.vpn_producer_vpc.subnets[0].id
      access_configs = []
    }
  ]
  tags = ["vpn-producer-instance"]
}

# -----------------------------------------------------------------------------------------
# Cloud SQL Configuration
# -----------------------------------------------------------------------------------------
module "cloudsql_vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "cloudsql-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "cloudsql-subnet"
      region                   = var.cloudsql_vpc_region
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = var.cloudsql_vpc_subnet_cidr
    }
  ]
  firewall_data = []
}

module "sql_password_secret" {
  source      = "./modules/secret-manager"
  secret_data = tostring(data.vault_generic_secret.sql.data["password"])
  secret_id   = "db-password-secret"
}

module "sql_username_secret" {
  source      = "./modules/secret-manager"
  secret_data = tostring(data.vault_generic_secret.sql.data["username"])
  secret_id   = "db-username-secret"
}

module "db" {
  source                      = "./modules/cloud-sql"
  name                        = "db-instance"
  db_name                     = "db-instance"
  db_user                     = module.sql_username_secret.secret_data
  db_version                  = "MYSQL_8_0"
  location                    = var.cloudsql_vpc_region
  tier                        = "db-custom-2-8192"
  availability_type           = "REGIONAL"
  disk_size                   = 100 # GB
  disk_type                   = "PD_SSD"
  disk_autoresize             = true
  disk_autoresize_limit       = 500 # GB
  ipv4_enabled                = false
  deletion_protection_enabled = false # true for production
  backup_configuration = [
    {
      enabled                        = true
      binary_log_enabled             = true
      start_time                     = "03:00"
      location                       = var.cloudsql_vpc_region
      point_in_time_recovery_enabled = false
      backup_retention_settings = [
        {
          retained_backups = 30
          retention_unit   = "COUNT"
        }
      ]
    }
  ]
  database_flags = [
    {
      name  = "general_log"
      value = "off"
    },
    {
      name  = "log_queries_not_using_indexes"
      value = "on"
    },
    {
      name  = "max_connections"
      value = "1000"
    },
    {
      name  = "skip_show_database"
      value = "on"
    },
    {
      name  = "slow_query_log"
      value = "on"
    },
    {
      name  = "long_query_time"
      value = "2"
    },
    {
      name  = "log_output"
      value = "FILE"
    }
  ]
  vpc_self_link = module.cloudsql_vpc.self_link
  vpc_id        = module.cloudsql_vpc.vpc_id
  password      = module.sql_password_secret.secret_data
  depends_on    = [module.sql_password_secret, module.sql_username_secret]
}

#---------------------------------------------------------------
# Hub-Spoke: all four VPCs attached as spokes to the same hub
#---------------------------------------------------------------
module "hub-spoke" {
  source          = "./modules/hub-spoke"
  hub_name        = var.hub_name
  hub_description = var.hub_description
  export_psc      = true
  spokes = [
    {
      spoke_name = "vpc1-spoke"
      location   = "global"
      linked_vpc_network = {
        uri = module.vpc1.self_link
      }
    },
    {
      spoke_name = "vpc2-spoke"
      location   = "global"
      linked_vpc_network = {
        uri = module.vpc2.self_link
      }
    },
    {
      spoke_name = "psc-spoke"
      location   = "global"
      linked_vpc_network = {
        uri = module.consumer_vpc.self_link
      }
    },
    {
      spoke_name = "spoke-vpn-consumer"
      location   = "global"
      linked_vpc_network = {
        uri = module.vpn_consumer_vpc.self_link
      }
    },
    {
      spoke_name = "cloudsql-spoke"
      location   = "global"
      linked_producer_vpc_network = {
        uri = module.cloudsql_vpc.self_link
      }
    },
    # --- VPN tunnel spokes ---    
    {
      spoke_name = "spoke-vpn-consumer-hybrid"
      location   = var.vpn_region
      linked_vpn_tunnels = {
        uris = [
          google_compute_vpn_tunnel.consumer_to_producer.id,
          google_compute_vpn_tunnel.consumer_to_producer_2.id,
        ]
        site_to_site_data_transfer = true
        include_import_ranges      = ["ALL_IPV4_RANGES"]
      }
    }
  ]
}