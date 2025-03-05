variable "hub_name" {}
variable "hub_description" {}
variable "spokes" {
  type = list(object({
    location               = string
    spoke_name             = string
    linked_vpc_network_uri = string
  }))
}
