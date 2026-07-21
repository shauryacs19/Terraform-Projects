# Cross-Region VPC Peering on AWS with Terraform

> Infrastructure-as-Code project that provisions two isolated VPCs in **two
> different AWS regions** and connects them privately using a **cross-region
> VPC peering connection**, verified with live traffic between EC2 instances
> over private IPs.

| | |
|---|---|
| **Cloud Provider** | Amazon Web Services (AWS) |
| **IaC Tool** | Terraform (`~> 6.0` AWS provider) |
| **Regions** | `ap-south-1` (Mumbai) · `ap-south-2` (Hyderabad) |
| **State Backend** | Amazon S3 (remote, encrypted) |
| **Status** | Deployed & verified — 0% packet loss, HTTP reachable over peering |

---

## Table of Contents

1. [Overview](#overview)
2. [Objectives](#objectives)
3. [Architecture](#architecture)
4. [AWS Services & Concepts](#aws-services--concepts)
5. [Technology Stack](#technology-stack)
6. [Repository Structure](#repository-structure)
7. [Prerequisites](#prerequisites)
8. [Configuration Reference](#configuration-reference)
9. [Deployment Guide](#deployment-guide)
10. [Verification](#verification)
11. [Screenshots](#screenshots)
12. [Troubleshooting & Lessons Learned](#troubleshooting--lessons-learned)
13. [Cost Considerations](#cost-considerations)
14. [Cleanup](#cleanup)

---

## Overview

By default, every Amazon VPC is a completely isolated network — two VPCs cannot
communicate, even within the same account, and especially not across regions.
This project demonstrates how to join two such networks into a single routable
address space using **VPC peering**, while each VPC retains its own CIDR block,
subnet, internet gateway, route table and security boundary.

Two EC2 instances — one in each region — run Apache and are proven to reach
each other over the peering link using **private IP addresses only**. Traffic
travels across the AWS global backbone and never touches the public internet.

## Objectives

- Provision two VPCs with **non-overlapping CIDR blocks** in two different AWS
  regions using a single Terraform configuration.
- Establish a **cross-region VPC peering connection** using the requester /
  accepter pattern.
- Configure **route tables** and **security groups** on both sides so the VPCs
  can route to and accept traffic from one another.
- Bootstrap an EC2 web server in each VPC via **user data** (cloud-init).
- **Verify** private connectivity end-to-end with `ping` (ICMP) and `curl`
  (HTTP) across the peering connection.
- Manage everything with **remote, encrypted Terraform state** in S3.

## Architecture

```mermaid
flowchart LR
    subgraph P["Primary VPC — ap-south-1 (10.0.0.0/16)"]
        PIGW[Internet Gateway]
        PRT[Route Table]
        PSN["Subnet 10.0.1.0/24"]
        PEC2["EC2 · Apache\n10.0.1.10"]
        PSG[Security Group]
        PSN --- PEC2
        PEC2 -.-> PSG
        PSN --- PRT
        PRT --- PIGW
    end

    subgraph S["Secondary VPC — ap-south-2 (10.1.0.0/16)"]
        SIGW[Internet Gateway]
        SRT[Route Table]
        SSN["Subnet 10.1.1.0/24"]
        SEC2["EC2 · Apache\n10.1.1.10"]
        SSG[Security Group]
        SSN --- SEC2
        SEC2 -.-> SSG
        SSN --- SRT
        SRT --- SIGW
    end

    PEER{{VPC Peering Connection\nrequester ↔ accepter}}
    PRT -->|"route 10.1.0.0/16"| PEER
    SRT -->|"route 10.0.0.0/16"| PEER
    PEER === S

    Internet((Internet))
    PIGW --- Internet
    SIGW --- Internet
```

**Traffic flow:** the primary route table sends anything destined for
`10.1.0.0/16` into the peering connection; the secondary route table does the
reverse for `10.0.0.0/16`. Each security group explicitly allows inbound
traffic from the *other* VPC's CIDR. So a request from `10.0.1.10` to
`10.1.1.10` is routed over the peering link, admitted by the secondary security
group, and answered by Apache — entirely over private IPs.

## AWS Services & Concepts

### Amazon VPC (Virtual Private Cloud)
A VPC is a logically isolated virtual network in AWS in which you control the
IP range, subnets, routing and gateways. VPCs are **region-scoped** and
isolated by default. This project creates two VPCs with **non-overlapping
CIDRs** (`10.0.0.0/16`, `10.1.0.0/16`) — non-overlapping ranges are a hard
requirement for peering, since overlapping addresses make routing ambiguous.

*Features used:* `enable_dns_support` and `enable_dns_hostnames`; two VPCs
created through separate provider aliases (one per region).

### Subnets
A subnet is a sub-range of a VPC's CIDR bound to a single Availability Zone.
Each VPC here has one **public** subnet (its route table has a path to an
Internet Gateway).

*Features used:* `cidrsubnet(vpc_cidr, 8, 1)` to carve a `/24` out of the
`/16`; `map_public_ip_on_launch = true`; AZ chosen dynamically via the
`aws_availability_zones` data source.

### Internet Gateway (IGW)
A horizontally-scaled, highly-available component that enables communication
between a VPC and the internet, performing NAT for instances with public IPs.

*Features used:* one IGW per VPC — needed so instances can install Apache on
first boot and so you can SSH in from your workstation.

### Route Tables & Routes
A route table is a set of rules mapping a **destination CIDR** to a **target**
(IGW, peering connection, etc.). Every subnet is associated with exactly one
route table; the most specific matching route wins (longest-prefix match).

*Features used:* **standalone `aws_route` resources** (never mixed with inline
`route {}` blocks — mixing the two styles on one table causes Terraform to
conflict on every apply); a default route (`0.0.0.0/0 → IGW`) and a peering
route per VPC; `aws_route_table_association` binding each subnet to its table.

### VPC Peering Connection
A direct, private network link between two VPCs so resources communicate using
private IPs as if on the same network. Traffic stays on the AWS backbone.
Peering is **non-transitive** and requires **non-overlapping CIDRs**. This
project uses **cross-region** peering:

*Features used:* `aws_vpc_peering_connection` on the requester with
`peer_region` set (makes it cross-region); `auto_accept = false` plus a
separate `aws_vpc_peering_connection_accepter` running in the peer region
(cross-region peering cannot be auto-accepted in one step); routes on **both**
sides pointing at the connection.

### Security Groups
A **stateful** virtual firewall attached to an instance's network interface.
Return traffic for allowed inbound flows is permitted automatically. Security
groups are **allow-only** and evaluated as the union of all rules.

*Features used:* SSH (TCP 22) from anywhere; ICMP from the peer CIDR (enables
`ping`); All TCP (0–65535) from the peer CIDR (enables `curl`/HTTP); all
outbound allowed.

### Amazon EC2 (Elastic Compute Cloud)
Resizable virtual servers booted from an AMI, running in a subnet and protected
by security groups.

*Features used:* AMI resolved dynamically via the `aws_ami` data source (latest
Ubuntu 24.04 LTS per region); `user_data` cloud-init script that installs and
starts Apache on first boot (**runs only once, at first boot**); fixed
`private_ip` (`10.0.1.10` / `10.1.1.10`) for stable addressing across rebuilds;
region-specific key pairs for SSH.

### Terraform Multi-Provider (Provider Aliases)
Because the VPCs live in different regions, the AWS provider is declared twice
with different `alias` values (`primary` → `ap-south-1`, `secondary` →
`ap-south-2`); each resource selects its region via `provider = aws.primary` or
`provider = aws.secondary`. This is the standard pattern for managing multiple
regions/accounts from one configuration.

### Terraform Remote State (S3 Backend)
Terraform records managed resources in a *state file*. Storing it remotely in
S3 means it survives a wiped machine and can be shared across runs.

*Features used:* remote S3 backend keyed under `vpc-peering/terraform.tfstate`,
with encryption at rest enabled.

## Technology Stack

| Layer | Technology |
|---|---|
| Cloud | AWS (VPC, EC2, Internet Gateway, Route Tables, Security Groups, VPC Peering) |
| IaC | Terraform, HCL, AWS provider `~> 6.0` |
| State | Amazon S3 (remote backend, encrypted) |
| Compute OS | Ubuntu 24.04 LTS |
| Web server | Apache HTTP Server (via cloud-init user data) |

## Repository Structure

```
.
├── main.tf                  # VPCs, subnets, IGWs, route tables/routes, peering, SGs, EC2 instances
├── data.tf                  # AMI and Availability Zone data sources (per region)
├── local.tf                 # user_data bootstrap scripts (install + start Apache)
├── variables.tf             # Input variables (regions, CIDRs, instance type, key names)
├── outputs.tf               # Instance public/private IPs
├── providers.tf             # AWS provider aliases (primary / secondary regions)
├── backend.tf               # Remote state backend + required providers
├── terraform.tfvars         # Variable values (git-ignored)
├── terraform.tfvars.example # Example variable values
├── Screenshots/             # Console + terminal evidence
└── README.md
```

## Prerequisites

- An AWS account with permissions for VPC, EC2 and S3.
- **Terraform** ≥ 1.5 and the **AWS CLI**, both configured with credentials.
- An existing **S3 bucket** for remote state (referenced in `backend.tf`).
- **EC2 key pairs** created in *both* regions (`ap-south-1` and `ap-south-2`)
  for SSH access, with the corresponding `.pem` files available locally.
- Region **`ap-south-2` (Hyderabad) enabled** on the account (opt-in region).

## Configuration Reference

### Input Variables (`variables.tf`)

| Variable | Description | Default |
|---|---|---|
| `environment` | Environment tag applied to resources | `development` |
| `primary` | Primary region | `ap-south-1` |
| `secondary` | Secondary region | `ap-south-2` |
| `primary_vpc_cidr` | CIDR block for the primary VPC | `10.0.0.0/16` |
| `secondary_vpc_cidr` | CIDR block for the secondary VPC | `10.1.0.0/16` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `primary_key_name` | Key pair name in the primary region | `vpc-peering-demo` |
| `secondary_key_name` | Key pair name in the secondary region | `vpc-peering-demo` |

> **Note on key pairs:** the key-pair *names* are the same in both regions, but
> key pairs are region-specific, so each region has its own key material. Use
> the `.pem` file that matches the region you are connecting to.

### Outputs (`outputs.tf`)

| Output | Description |
|---|---|
| `primary_instance_private_ip` | Private IP of the primary instance (`10.0.1.10`) |
| `primary_instance_public_ip` | Public IP of the primary instance (for SSH) |
| `secondary_instance_private_ip` | Private IP of the secondary instance (`10.1.1.10`) |
| `secondary_instance_public_ip` | Public IP of the secondary instance (for SSH) |

## Deployment Guide

1. **Clone and initialize**
   ```bash
   terraform init
   ```
2. **Set variables** — copy the example and adjust as needed:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. **Review the plan**
   ```bash
   terraform plan
   ```
4. **Apply**
   ```bash
   terraform apply
   ```
5. **Read the outputs**
   ```bash
   terraform output
   ```

> The Apache install runs on first boot via cloud-init and takes ~1–2 minutes.
> If `curl` refuses or hangs immediately after launch, wait until
> `cloud-init status` reports `done` on the target instance.

## Verification

SSH into the primary instance (public IP + matching key), then reach the
secondary over its **private** IP across the peering link:

```bash
# from the primary instance (10.0.1.10):
ping 10.1.1.10          # ICMP over peering  → 0% packet loss
curl http://10.1.1.10   # HTTP over peering  → "Secondary VPC Instance - ap-south-2"
```

And the reverse from the secondary instance:

```bash
# from the secondary instance (10.1.1.10):
ping 10.0.1.10
curl http://10.0.1.10   # "Primary VPC Instance - ap-south-1"
```

**Success criteria:** clean pings (0% loss) **and** each instance returns the
peer's Apache page over the private IP — proving the two regions are joined
into one routable network.

## Screenshots

### Cross-region connectivity (proof it works)

Ping (ICMP) and curl (HTTP) between the instances over their **private IPs**,
across the peering connection — 0% packet loss and each instance serving the
other its Apache page.

**Primary → Secondary** (`10.0.1.10` → `10.1.1.10`)

![Primary to secondary ping and curl](Screenshots/01-primary-to-secondary-ping-curl.png)

**Secondary → Primary** (`10.1.1.10` → `10.0.1.10`)

![Secondary to primary ping and curl](Screenshots/02-secondary-to-primary-ping-curl.png)

### VPCs

Non-overlapping `10.0.0.0/16` (Mumbai) and `10.1.0.0/16` (Hyderabad), each with
a `/24` subnet, a route table and an IGW.

| Primary VPC — ap-south-1 | Secondary VPC — ap-south-2 |
|---|---|
| ![Primary VPC resource map](Screenshots/03-primary-vpc-resource-map.png) | ![Secondary VPC resource map](Screenshots/04-secondary-vpc-resource-map.png) |

### Route Tables

Each table has three routes: `local`, the default `0.0.0.0/0 → IGW`, and the
peering route to the other VPC's CIDR via `pcx-0404d189eb1663c8c` — all
**Active**.

| Primary route table | Secondary route table |
|---|---|
| ![Primary route table](Screenshots/05-primary-route-table.png) | ![Secondary route table](Screenshots/06-secondary-route-table.png) |

### VPC Peering Connection

Status **Active**, requester in Mumbai (`10.0.0.0/16`) and accepter in
Hyderabad (`10.1.0.0/16`) — confirming a cross-region peering.

| Requester side (Mumbai) | Accepter side (Hyderabad) |
|---|---|
| ![Peering connection Mumbai view](Screenshots/07-peering-connection-mumbai-view.png) | ![Peering connection Hyderabad view](Screenshots/08-peering-connection-hyderabad-view.png) |

### Security Groups

Inbound rules on each SG: **SSH (22)** from anywhere, **ICMP** from the peer
CIDR, and **All TCP (0–65535)** from the peer CIDR — the last is what lets
HTTP flow between the VPCs.

| Primary SG (source `10.1.0.0/16`) | Secondary SG (source `10.0.0.0/16`) |
|---|---|
| ![Primary security group](Screenshots/09-primary-security-group.png) | ![Secondary security group](Screenshots/10-secondary-security-group.png) |

## Troubleshooting & Lessons Learned

| Symptom | Root cause | Fix |
|---|---|---|
| `curl` refused but `ping` works | No web server listening — `user_data` was never attached to the instance | Reference `user_data` on the instance and recreate it |
| Apache missing on a running box | `user_data` only runs at **first boot**; instance was launched before it was wired in | Recreate the instance (`terraform apply -replace=...`) |
| IPs change on every apply | No fixed `private_ip`; addresses reassigned each rebuild | Set a fixed `private_ip` per instance |
| `RouteAlreadyExists` on apply | Inline `route {}` blocks mixed with standalone `aws_route` on the same table | Use one style only — all standalone `aws_route` |
| Intermittent ping | Testing against a stale IP from a previous rebuild | Read the current IP from `terraform output` |
| SSH `Permission denied` | On Windows, an over-permissive `.pem` is ignored by OpenSSH; or wrong region's key | Restrict the key with `icacls`; use the `.pem` matching that region |

**Key takeaways**
- Non-overlapping CIDRs are mandatory for peering.
- Cross-region peering needs the requester + accepter two-resource pattern.
- `ping` working while `curl` fails means the network path is fine — look at
  the service or the TCP rule, not the peering.
- Key pairs are region-specific even when they share a name.

## Cost Considerations

- **EC2:** two `t3.micro` instances (free-tier eligible in each region within
  limits; otherwise on-demand hourly).
- **VPC peering:** no hourly charge for the connection itself, but
  **cross-region data transfer is billed** in both directions.
- **S3:** negligible cost for the small remote state object.
- VPCs, subnets, route tables, IGWs and security groups incur no direct charge.

> Run `terraform destroy` when finished to avoid ongoing charges.

## Cleanup

```bash
terraform destroy
```

This removes both instances, the peering connection, security groups, route
tables, IGWs, subnets and VPCs across both regions. The remote state object and
the state bucket are **not** managed by this configuration and remain.
