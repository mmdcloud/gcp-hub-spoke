output "global_endpoint_id" {
  value = try(google_compute_global_network_endpoint_group.neg[0].id, null)
}

output "zonal_endpoint_id" {
  value = try(google_compute_network_endpoint_group.neg[0].id, null)
}

output "regional_endpoint_id" {
  value = try(google_compute_region_network_endpoint_group.neg[0].id, null)
}