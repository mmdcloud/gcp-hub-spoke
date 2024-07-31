variable "region" {
  type    = string
  default = "us-central1"
}

variable "ip_cidr_range1" {
  type        = list(string)
  description = "List of The range of internal addresses that are owned by this subnetwork."
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "ip_cidr_range2" {
  type        = list(string)
  description = "List of The range of internal addresses that are owned by this subnetwork."
  default     = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
}
