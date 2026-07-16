output "instance1_ip" {
  value = module.instance1.network_ip
}

output "instance2_ip" {
  value = module.instance2.network_ip
}

output "psc_consumer_ip" {
  value = google_compute_address.psc_consumer_ip.address
}

output "vpn_consumer_ip" {
  value = module.vpn_consumer_instance.network_ip
}