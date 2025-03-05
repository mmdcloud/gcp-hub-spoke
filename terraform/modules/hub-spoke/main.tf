resource "google_network_connectivity_hub" "hub" {
  name        = var.hub_name
  description = var.hub_description
  labels = {
    name = var.hub_name
  }
}

resource "google_network_connectivity_spoke" "spokes" {
  count    = length(var.spokes)
  name     = var.spokes[count.index].spoke_name
  location = var.spokes[count.index].location
  hub      = google_network_connectivity_hub.hub.id
  linked_vpc_network {
    uri = var.spokes[count.index].linked_vpc_network_uri
  }
}
