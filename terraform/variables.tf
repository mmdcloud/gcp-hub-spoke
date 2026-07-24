#---------------------------------------------------------------
# Core
#---------------------------------------------------------------
variable "project_id" {
  description = "GCP project ID that all resources will be deployed into."
  type        = string
}

variable "region" {
  description = "GCP region used for all regional resources (subnets, routers, VPN gateways, Cloud Run, LB, etc.)."
  type        = string
  default     = "us-central1"
}

#---------------------------------------------------------------
# Compute instances (shared across instance1 / instance2 / consumer / vpn-consumer)
#---------------------------------------------------------------
variable "machine_type" {
  description = "Machine type used for all demo compute instances."
  type        = string
  default     = "e2-micro"
}

variable "instance_image" {
  description = "Boot image used for all demo compute instances."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
}

variable "instance_startup_script" {
  description = "Startup script executed on all demo compute instances."
  type        = string
  default     = "sudo apt-get update; sudo apt-get install nginx -y"
}

#---------------------------------------------------------------
# VPC1 / VPC2 (hub-spoke)
#---------------------------------------------------------------
variable "vpc1_subnet_cidr" {
  description = "CIDR range for the vpc1 subnet."
  type        = string
  default     = "10.1.0.0/24"
}

variable "vpc2_subnet_cidr" {
  description = "CIDR range for the vpc2 subnet."
  type        = string
  default     = "10.2.0.0/24"
}

#---------------------------------------------------------------
# Private Service Connect (consumer / producer VPCs)
#---------------------------------------------------------------
variable "consumer_subnet_cidr" {
  description = "CIDR range for the PSC consumer subnet."
  type        = string
  default     = "10.3.0.0/24"
}

variable "producer_subnet_cidr" {
  description = "CIDR range for the PSC producer (PRIVATE) subnet."
  type        = string
  default     = "10.4.0.0/24"
}

variable "producer_psc_subnet_cidr" {
  description = "CIDR range for the PRIVATE_SERVICE_CONNECT (NAT) subnet in the producer VPC."
  type        = string
  default     = "10.20.0.0/24"
}

variable "producer_proxy_subnet_cidr" {
  description = "CIDR range for the REGIONAL_MANAGED_PROXY subnet in the producer VPC."
  type        = string
  default     = "10.129.0.0/23"
}

variable "artifact_repository_id" {
  description = "Artifact Registry repository ID for the nodeapp image."
  type        = string
  default     = "nodeapp"
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service."
  type        = string
  default     = "nodeapp"
}

variable "cloud_run_min_instances" {
  description = "Minimum instance count for the Cloud Run service."
  type        = number
  default     = 2
}

variable "cloud_run_max_instances" {
  description = "Maximum instance count for the Cloud Run service."
  type        = number
  default     = 5
}

variable "cloud_run_concurrency" {
  description = "Max concurrent requests per Cloud Run instance."
  type        = number
  default     = 80
}

variable "cloud_run_container_port" {
  description = "Container port exposed by the Cloud Run service."
  type        = number
  default     = 8080
}

#---------------------------------------------------------------
# VPN (producer / consumer VPCs, routers, tunnels)
#---------------------------------------------------------------
variable "vpn_producer_subnet_cidr" {
  description = "CIDR range for the VPN producer subnet."
  type        = string
  default     = "10.5.0.0/24"
}

variable "vpn_consumer_subnet_cidr" {
  description = "CIDR range for the VPN consumer subnet."
  type        = string
  default     = "10.6.0.0/24"
}

variable "producer_bgp_asn" {
  description = "BGP ASN for the producer-side Cloud Router."
  type        = number
  default     = 65001
}

variable "consumer_bgp_asn" {
  description = "BGP ASN for the consumer-side Cloud Router."
  type        = number
  default     = 65002
}

variable "producer_router_interface_ip_range" {
  description = "Link-local IP range for the producer router interface (BGP session)."
  type        = string
  default     = "169.254.0.1/30"
}

variable "consumer_router_interface_ip_range" {
  description = "Link-local IP range for the consumer router interface (BGP session)."
  type        = string
  default     = "169.254.0.2/30"
}

variable "producer_peer_ip_address" {
  description = "Peer IP address used by the producer router's BGP peer (consumer side link-local address)."
  type        = string
  default     = "169.254.0.2"
}

variable "consumer_peer_ip_address" {
  description = "Peer IP address used by the consumer router's BGP peer (producer side link-local address)."
  type        = string
  default     = "169.254.0.1"
}

#---------------------------------------------------------------
# Hub-Spoke
#---------------------------------------------------------------
variable "hub_name" {
  description = "Network Connectivity Center hub name."
  type        = string
  default     = "hub"
}

variable "hub_description" {
  description = "Description for the Network Connectivity Center hub."
  type        = string
  default     = "A sample hub"
}