output "global_endpoint_id" {
  value = google_compute_global_network_endpoint_group.neg[0].id
}

output "zonal_endpoint_id" {
  value = google_compute_network_endpoint_group.neg[0].id
}

output "regional_endpoint_id" {
  value = google_compute_region_network_endpoint_group.neg[0].id
}