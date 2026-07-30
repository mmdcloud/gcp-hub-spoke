# GCP Hybrid Connectivity Architecture (Terraform)

Terraform module set that stands up a hub-and-spoke network on Google Cloud using **Network Connectivity Center (NCC)**, and demonstrates three common connectivity patterns between spokes:

1. **VPC-to-VPC via the NCC hub** (`vpc1` ⇄ `vpc2`)
2. **Private Service Connect (PSC)** — a consumer VPC privately consuming a Cloud Run service published from a producer VPC through an internal L7 load balancer and a PSC service attachment
3. **Site-to-site connectivity via HA VPN with dynamic (BGP) routing** — `vpn-producer-vpc` ⇄ `vpn-consumer-vpc`

All four VPCs (`vpc1`, `vpc2`, `consumer-vpc`, `vpn-consumer-vpc`) are attached as spokes to a single NCC hub, so the pattern can be extended to additional spokes with minimal changes.

---

## Architecture

```
                              ┌─────────────────────────────┐
                              │   Network Connectivity Hub  │
                              └──────────────┬───────────────┘
        ┌───────────────┬────────────────────┼────────────────────┬───────────────┐
        │               │                    │                    │               │
   spoke: vpc1     spoke: vpc2      spoke: consumer-vpc   spoke: vpn-consumer-vpc
   ┌─────────┐    ┌─────────┐       ┌───────────────┐     ┌───────────────────┐
   │instance1│    │instance2│       │ psc-instance   │     │vpn-consumer-inst  │
   └─────────┘    └─────────┘       │       │        │     └─────────┬─────────┘
                                     │  PSC consumer  │               │ HA VPN (BGP)
                                     │  endpoint IP   │               │
                                     └───────┬────────┘     ┌─────────┴─────────┐
                                             PSC             │ vpn-producer-vpc  │
                                     ┌───────┴────────┐      │ (spoke NOT attached│
                                     │  producer-vpc  │      │  to hub — peers    │
                                     │  ┌───────────┐ │      │  directly over VPN)│
                                     │  │  Internal │ │      └────────────────────┘
                                     │  │  L7 ILB   │ │
                                     │  └─────┬─────┘ │
                                     │        │       │
                                     │  Serverless NEG │
                                     │        │       │
                                     │  ┌─────▼─────┐ │
                                     │  │ Cloud Run │ │
                                     │  │  nodeapp  │ │
                                     │  └───────────┘ │
                                     └─────────────────┘
```

> Note: `vpn-producer-vpc` is **not** an NCC spoke — it connects to `vpn-consumer-vpc` (which *is* a spoke) purely over HA VPN with BGP-advertised routes. This mixes a hub-spoke topology with a directly-peered VPN segment, which is a common pattern when one side of a VPN is outside your NCC-managed estate (e.g., on-prem or another org).

---

## What gets deployed

### Core networking
| Resource | Purpose |
|---|---|
| `module.vpc1`, `module.vpc2` | Simple test VPCs, each with one subnet and an instance, used to validate hub-spoke reachability |
| `module.consumer_vpc` | Consumer-side VPC for the PSC demo, hosts the PSC forwarding rule and a test instance |
| `module.producer_vpc` | Producer-side VPC for the PSC demo; contains a private subnet, a `PRIVATE_SERVICE_CONNECT` subnet (NAT pool for PSC), and a `REGIONAL_MANAGED_PROXY` subnet (required for the regional internal L7 ILB) |
| `module.vpn_producer_vpc`, `module.vpn_consumer_vpc` | VPN demo VPCs, each with one subnet and a test instance |
| `module.hub-spoke` | Network Connectivity Center hub with `vpc1`, `vpc2`, `consumer-vpc`, and `vpn-consumer-vpc` registered as spokes |

### Compute
- `module.instance1`, `module.instance2` — test VMs in `vpc1` / `vpc2`
- `module.consumer_instance` — test VM in `consumer-vpc`, tagged `psc-instance`
- `module.vpn_consumer_instance` — test VM in `vpn-consumer-vpc`
- All instances are private only (no `access_configs`) and reachable via IAP/SSH or from peer instances per the firewall rules below

### Private Service Connect chain
- `module.artifact_registry` — Artifact Registry repo, built/pushed via `src/artifact_push.sh`
- `module.cloud_run_service_account` + `module.cloud_run_service` — Cloud Run service (`INGRESS_TRAFFIC_INTERNAL_ONLY`), pulling the pushed image
- `google_cloud_run_service_iam_member.cloud_run_access` — grants `roles/run.invoker` to `allUsers` (traffic is still restricted to internal ingress at the Cloud Run layer; access control effectively lives with the ILB / VPC perimeter, not IAM — see **Security notes**)
- `module.service_neg` — Serverless NEG pointing at the Cloud Run service
- `google_compute_region_backend_service` / `google_compute_region_url_map` / `google_compute_region_target_http_proxy` / `google_compute_forwarding_rule` — regional internal (`INTERNAL_MANAGED`) HTTP load balancer in `producer-vpc` fronting the NEG
- `google_compute_service_attachment.psc_attachment` — publishes the ILB as a PSC service, using the `PRIVATE_SERVICE_CONNECT` subnet as the NAT pool, `connection_preference = ACCEPT_AUTOMATIC`
- `google_compute_address.psc_consumer_ip` + `google_compute_forwarding_rule.psc_consumer_forwarding_rule` — PSC consumer endpoint in `consumer-vpc`, resolving to the producer's service attachment

### HA VPN (BGP)
- `google_compute_ha_vpn_gateway` — one gateway per side (`producer_gateway`, `consumer_gateway`)
- `google_compute_router` — Cloud Router per side, each with its own BGP ASN (`var.producer_bgp_asn`, `var.consumer_bgp_asn`)
- `google_compute_vpn_tunnel` — one tunnel per direction, single interface (`vpn_gateway_interface = 0`)
- `google_compute_router_interface` / `google_compute_router_peer` — BGP session per side, exchanging routes over the tunnel

### Firewalls
Each VPC module is passed a `firewall_data` list. Rules generally follow this pattern per VPC:
- Allow SSH (`22/tcp`) from `0.0.0.0/0` for admin access (see **Security notes** — tighten before production)
- Allow ICMP from the *other* VPCs' test instance IPs, for hub-spoke reachability testing
- Allow `80/tcp` from `google_compute_address.psc_consumer_ip.address`, for PSC path testing
- Allow ICMP from the VPN consumer instance, for VPN path testing

---

## Prerequisites

- Terraform **>= 1.5** and the `google` provider
- A GCP project with billing enabled and these APIs enabled:
  - `compute.googleapis.com`
  - `run.googleapis.com`
  - `artifactregistry.googleapis.com`
  - `networkconnectivity.googleapis.com`
  - `servicenetworking.googleapis.com` (if applicable to your `modules/vpc` and `modules/hub-spoke` implementations)
- Application Default Credentials or a service account with, at minimum:
  - `roles/compute.networkAdmin`
  - `roles/run.admin`
  - `roles/artifactregistry.admin`
  - `roles/networkconnectivity.hubAdmin`
  - `roles/iam.serviceAccountAdmin` (to create the Cloud Run service account)
- `gcloud` and `docker` available locally if `src/artifact_push.sh` builds/pushes the container image during `terraform apply`
- The following local modules present under `./modules/`:
  - `vpc`, `compute`, `artifact-registry`, `service-account`, `cloud-run`, `network_endpoint_groups`, `hub-spoke`

---

## Required variables

Define these in a `terraform.tfvars` (not committed) or via your pipeline's variable injection. Names inferred from usage in `main.tf`:

```hcl
project_id                          = "my-gcp-project"
region                               = "us-central1"
machine_type                         = "e2-medium"
instance_image                       = "debian-cloud/debian-12"
instance_startup_script              = ""   # optional

# VPC CIDRs
vpc1_subnet_cidr                     = "10.0.1.0/24"
vpc2_subnet_cidr                     = "10.0.2.0/24"
consumer_subnet_cidr                 = "10.0.3.0/24"
producer_subnet_cidr                 = "10.0.4.0/24"
producer_psc_subnet_cidr             = "10.0.5.0/28"
producer_proxy_subnet_cidr           = "10.0.6.0/24"

# Cloud Run / Artifact Registry
artifact_repository_id               = "nodeapp-repo"
cloud_run_service_name               = "nodeapp"
cloud_run_container_port             = 8080
cloud_run_min_instances              = 0
cloud_run_max_instances              = 3
cloud_run_concurrency                = 80

# VPN
vpn_producer_subnet_cidr             = "10.0.7.0/24"
vpn_consumer_subnet_cidr             = "10.0.8.0/24"
producer_bgp_asn                     = 65001
consumer_bgp_asn                     = 65002
producer_router_interface_ip_range   = "169.254.0.1/30"
consumer_router_interface_ip_range   = "169.254.0.2/30"
producer_peer_ip_address             = "169.254.0.2"
consumer_peer_ip_address             = "169.254.0.1"

# Hub-spoke
hub_name                             = "central-hub"
hub_description                      = "Central NCC hub for hybrid connectivity demo"
```

> **Note:** This configuration provisions a **single-tunnel HA VPN** (one interface per gateway, one BGP peer per side). This validates connectivity but does **not** meet Google's 99.99% HA VPN SLA, which requires both interfaces on each gateway to be used with a second peer VPN gateway/tunnel pair. See [Production hardening](#production-hardening) below.

---

## Usage

```bash
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Terraform will:
1. Create the four demo VPCs plus the VPN VPCs and their firewall rules
2. Build/push the container image via `src/artifact_push.sh` and create the Artifact Registry repo
3. Deploy the Cloud Run service and the internal L7 ILB in front of it
4. Create the PSC service attachment and the consumer-side PSC endpoint
5. Stand up the HA VPN gateways, tunnels, and BGP sessions
6. Register `vpc1`, `vpc2`, `consumer-vpc`, and `vpn-consumer-vpc` as NCC spokes

### Validating the deployment

**Hub-spoke (vpc1 ⇄ vpc2):**
```bash
gcloud compute ssh connectivity-instance1 --zone=<region>-a --tunnel-through-iap
ping <instance2_internal_ip>
```

**PSC path (consumer → Cloud Run via producer ILB):**
```bash
gcloud compute ssh psc-instance --zone=<region>-a --tunnel-through-iap
curl http://<psc_consumer_ip>:80
```

**VPN path (BGP-routed):**
```bash
gcloud compute routers get-status consumer-router --region=<region>
gcloud compute ssh vpn-consumer-instance --zone=<region>-a --tunnel-through-iap
ping <vpn_producer_instance_internal_ip>
```

---

## Known issues / before you merge

- **Broken reference:** the firewall rule `vpn-psc-firewall` inside `module.vpn_consumer_vpc` references `module.psc_instance.network_ip`, but no module named `psc_instance` is defined anywhere in this configuration (the PSC test VM is `module.consumer_instance`). This will fail to plan as-is — fix the reference (likely intended to be `module.consumer_instance.network_ip`) or remove the rule before applying.
- **Single-tunnel VPN:** as noted above, only one tunnel/interface pair per gateway is configured. Fine for a demo, insufficient for the HA VPN 99.99% SLA.
- **`google_cloud_run_service_iam_member` grants `run.invoker` to `allUsers`:** combined with `ingress = INGRESS_TRAFFIC_INTERNAL_ONLY`, this is safe from the public internet, but it does mean *any* resource with network-level access to the service's internal ingress path can invoke it without further IAM checks. Scope this down (e.g., to a specific service account) if you need invocation-level access control in addition to network isolation.
- **SSH open to `0.0.0.0/0`** on every VPC's firewall rules. Replace with IAP-only ingress (source range `35.235.240.0/20`, no external IP on instances — already the case here) or a bastion/allowlist before treating this as production.
- **`random_id.vpn_shared_secret`** is generated by Terraform and stored in state. Ensure your backend encrypts state at rest (GCS backend with CMEK, or equivalent) and restrict who can read it.

---

## Production hardening

Before using this as a real production topology, consider:

- [ ] Add the second HA VPN interface/tunnel pair on each side for full SLA coverage
- [ ] Move the VPN shared secret to Secret Manager instead of Terraform-generated `random_id`
- [ ] Restrict SSH firewall rules to IAP ranges only; drop `0.0.0.0/0`
- [ ] Add Cloud NAT if any workload needs outbound internet access (none of these VPCs currently have external IPs or a NAT gateway)
- [ ] Enable VPC Flow Logs and Firewall Rules Logging on all `firewall_data` entries
- [ ] Pin the Cloud Run container image to a digest instead of `:latest`
- [ ] Set `min_instance_count > 0` for the Cloud Run service if cold starts are unacceptable
- [ ] Add a `google_project_service` block (or equivalent) to explicitly enable required APIs rather than assuming they're pre-enabled
- [ ] Consider attaching `vpn-producer-vpc` as an NCC spoke as well (or documenting explicitly why it's intentionally excluded) for topology consistency
- [ ] Add monitoring/alerting on VPN tunnel status and BGP session state

---

## Repository layout

```
.
├── main.tf                  # this configuration
├── variables.tf              # variable declarations (see Required variables)
├── outputs.tf                # (recommended) expose service URLs, IPs, hub/spoke IDs
├── modules/
│   ├── vpc/
│   ├── compute/
│   ├── artifact-registry/
│   ├── service-account/
│   ├── cloud-run/
│   ├── network_endpoint_groups/
│   └── hub-spoke/
└── src/
    └── artifact_push.sh      # builds & pushes the nodeapp image
```

## Cleanup

```bash
terraform destroy -var-file=terraform.tfvars
```

Note: `deletion_protection = false` is set on all instances and the Cloud Run service to allow clean teardown in this demo. Re-enable deletion protection for anything long-lived.
