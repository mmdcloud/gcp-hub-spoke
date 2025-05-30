# GCP Hub and Spoke Network Architecture

This repository contains Terraform code to deploy a Hub and Spoke network topology in Google Cloud Platform (GCP). The implementation includes three VPCs (one hub and two spokes) with a virtual machine instance in each network, demonstrating secure and efficient network connectivity patterns.

![Hub and Spoke Architecture Diagram](https://storage.googleapis.com/your-bucket/hub-spoke-architecture.png)

## Architecture Overview

This implementation creates:

1. **Hub VPC** - Central network that serves as the connectivity hub
2. **Spoke VPC 1** - First spoke network for workload isolation
3. **Spoke VPC 2** - Second spoke network for workload isolation
4. **VM Instances** - One compute instance in each VPC for testing connectivity
5. **VPC Network Peering** - Connections between the hub and each spoke
6. **Cloud NAT** - For instances without public IPs to access the internet
7. **Firewall Rules** - Secure communication between networks

## Prerequisites

- Google Cloud Platform account
- Project with billing enabled
- [Terraform](https://www.terraform.io/downloads.html) (v1.0.0+)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- Appropriate permissions (`roles/compute.networkAdmin`, `roles/compute.instanceAdmin.v1`)

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/gcp-hub-spoke.git
cd gcp-hub-spoke
```

### 2. Configure authentication

```bash
gcloud auth application-default login
```

### 3. Update variables

Edit `terraform.tfvars` to match your environment:

```hcl
project_id           = "your-project-id"
region               = "us-central1"
hub_subnet_cidr      = "10.0.0.0/24"
spoke1_subnet_cidr   = "10.1.0.0/24"
spoke2_subnet_cidr   = "10.2.0.0/24"
```

### 4. Initialize and apply Terraform

```bash
terraform init
terraform plan
terraform apply
```

## Network Configuration Details

### Hub VPC

The hub VPC serves as the central connectivity point and includes:

- Primary subnet (`10.0.0.0/24`)
- Firewall rules for SSH access and internal communication
- A VM instance with an internal IP address
- NAT router for outbound connectivity

### Spoke VPCs

Each spoke VPC represents an isolated workload environment and includes:

- Dedicated subnet (Spoke 1: `10.1.0.0/24`, Spoke 2: `10.2.0.0/24`)
- Firewall rules allowing traffic from the hub
- A VM instance for testing connectivity
- VPC peering connection to the hub

### Network Peering

VPC Network Peering connects the networks with the following configuration:
- Hub to Spoke 1 peering
- Hub to Spoke 2 peering
- Custom routes exchange enabled
- Private IP access for services

## Testing Connectivity

After deployment, you can verify the connectivity between instances:

1. SSH into the hub instance
   ```bash
   gcloud compute ssh hub-vm --project=your-project-id --zone=us-central1-a
   ```

2. Test connectivity to spoke instances
   ```bash
   # From hub-vm
   ping 10.1.0.2  # Spoke 1 VM
   ping 10.2.0.2  # Spoke 2 VM
   ```

3. Verify routing between spokes (requires additional configuration)
   ```bash
   # From spoke1-vm
   ping 10.2.0.2  # Spoke 2 VM (only works with transitive routing enabled)
   ```

## Module Structure

```
├── main.tf           # Main configuration file
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── modules/
│   ├── vpc/          # VPC network module
│   ├── firewall/     # Firewall rules module
│   ├── nat/          # Cloud NAT module
│   ├── peering/      # VPC peering module
│   └── instance/     # Compute instance module
├── scripts/          # Helper scripts
└── examples/         # Example configurations
```

## Advanced Configuration

### Enabling Transitivity Between Spokes

By default, spoke networks cannot communicate directly with each other. To enable transitivity:

1. Deploy Cloud VPN or SD-WAN in the hub
2. Configure appropriate routes
3. Update firewall rules to allow traffic

See the `examples/transitive-routing` directory for configuration examples.

### Custom Network Policies

To implement network policies:

```hcl
module "network_policies" {
  source      = "./modules/network-policies"
  project_id  = var.project_id
  enable_ids  = true
  enable_fw_insights = true
}
```

## Monitoring and Logging

The deployment includes basic monitoring and logging:

- VPC Flow Logs enabled on all networks
- Firewall rule logging for denied traffic
- Custom dashboard for network metrics

Access these in the Google Cloud Console under "Networking" and "Monitoring".

## Cost Optimization

Estimated monthly costs:
- VPC Network: Free tier + usage
- VM Instances: ~$25/month each (n1-standard-1)
- Cloud NAT: ~$1/month + data processing
- Network Egress: Variable based on usage

Total: ~$80-100/month for the basic setup

## Cleanup

To avoid incurring charges, destroy the resources when not needed:

```bash
terraform destroy
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
