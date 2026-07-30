# ---------------------------------------------------------------
# Core
# ---------------------------------------------------------------
project_id = "encoded-alpha-457108-e8"
region     = "us-central1"

# ---------------------------------------------------------------
# Compute instances
# ---------------------------------------------------------------
machine_type            = "e2-micro"
instance_image          = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
instance_startup_script = "sudo apt-get update; sudo apt-get install nginx -y"

# ---------------------------------------------------------------
# VPC1 / VPC2
# ---------------------------------------------------------------
vpc1_subnet_cidr = "10.1.0.0/24"
vpc2_subnet_cidr = "10.2.0.0/24"

# ---------------------------------------------------------------
# Private Service Connect
# ---------------------------------------------------------------
consumer_subnet_cidr       = "10.3.0.0/24"
producer_subnet_cidr       = "10.4.0.0/24"
producer_psc_subnet_cidr   = "10.20.0.0/24"
producer_proxy_subnet_cidr = "10.129.0.0/23"

artifact_repository_id   = "nodeapp"
cloud_run_service_name   = "nodeapp"
cloud_run_min_instances  = 2
cloud_run_max_instances  = 5
cloud_run_concurrency    = 80
cloud_run_container_port = 8080

# ---------------------------------------------------------------
# VPN
# ---------------------------------------------------------------
vpn_producer_subnet_cidr = "10.5.0.0/24"
vpn_consumer_subnet_cidr = "10.6.0.0/24"

producer_bgp_asn = 65001
consumer_bgp_asn = 65002

producer_router_interface_ip_range = "169.254.0.1/30"
consumer_router_interface_ip_range = "169.254.0.2/30"
producer_peer_ip_address           = "169.254.0.2"
consumer_peer_ip_address           = "169.254.0.1"

# ---------------------------------------------------------------
# Hub-Spoke
# ---------------------------------------------------------------
hub_name        = "hub"
hub_description = "A sample hub"