# Full-Mesh VPC Peering (3 VPCs, no Transit Gateway)

Transitive-style reachability across three VPCs in three regions
(`ap-south-1`, `ap-south-2`, `ap-southeast-1`) using **only VPC peering**.
Because peering is non-transitive, every pair is peered directly — a full mesh
of three connections. Validated with all-to-all private connectivity between
instances in every region.

> Part of the [VPC Peering series](../README.md):
> [2-VPC](../2-vpc-peering/) · **3-VPC full mesh (this)** ·
> [3-VPC transit gateway](../3-vpc-transit-gateway/)

## Architecture

![Architecture](architecture-3vpc-full-mesh.png)

## AWS Services Used

| Service | Purpose |
|---|---|
| **VPC Peering** | Three connections (A↔B, A↔C, B↔C) forming a full mesh |
| **Route Tables** | Route each peer CIDR through the correct peering connection |
| **Security Groups** | Allow ICMP/TCP from **all** peer VPC CIDRs |
| VPC | Three isolated networks — `10.0.0.0/16`, `10.1.0.0/16`, `10.2.0.0/16` |
| Subnets | One public `/24` per VPC |
| Internet Gateway | Outbound access for instance bootstrap and SSH |
| EC2 | Endpoints used only to validate connectivity |
| Key Pairs | Per-region key pair (least privilege) via `aws_key_pair` |
| S3 | Remote, encrypted Terraform state backend |
| Provider aliases | Manage three regions from one configuration |

## Core Concepts

### Full-Mesh VPC Peering

- **What:** peering is non-transitive, so N VPCs need **N(N−1)/2** direct connections to be mutually reachable.
- **Why here:** three VPCs must all reach each other without a Transit Gateway → 3 edges (A↔B, A↔C, B↔C).
- **AWS:** three `aws_vpc_peering_connection` + accepter pairs (cross-region, `auto_accept = false`).
- **Scaling:** 3 VPCs → 3, 4 → 6, 5 → 10 connections; a mesh stops being practical fast.
- **Interview:** non-transitivity is *the* reason a mesh is required; Transit Gateway scales linearly (one attachment per VPC); cross-region → CIDR-based SG rules, MTU 1500.

![Primary–Tertiary peering](Screenshots/07-peering-primary-tertiary-active.png)
![Secondary–Tertiary peering](Screenshots/08-peering-secondary-tertiary-active.png)
*The two tertiary edges — Mumbai↔Singapore and Hyderabad↔Singapore — status **Active**, completing the mesh alongside Mumbai↔Hyderabad.*

![Primary reaches both peers](Screenshots/01-primary-reaches-both-peers.png)
![Secondary reaches both peers](Screenshots/02-secondary-reaches-both-peers.png)
![Tertiary reaches both peers](Screenshots/03-tertiary-reaches-both-peers.png)
*Each instance pings and curls **both** other regions by private IP (0% loss) — every VPC reaches every other across the mesh.*

### Route Tables

- **What:** destination-CIDR → target rules; one table per subnet; longest-prefix wins.
- **Why here:** in a mesh each VPC must route to **every** other VPC's CIDR, each via its own peering connection.
- **AWS:** each route table carries **two** peer routes (plus the IGW default).
- **Best practice:** standalone `aws_route` (never inline); a route per peer CIDR on every table.
- **Interview:** routing isn't transitive either — a missing peer route silently breaks one direction.

![Tertiary route table](Screenshots/05-tertiary-route-table.png)
*The tertiary table forwards **both** peer CIDRs (`10.0.0.0/16`, `10.1.0.0/16`) to their peering connections.*

### Security Groups

- **What:** stateful, allow-only instance firewall; rules are a union; return traffic implicit.
- **Why here:** each instance must accept traffic from **both** other VPCs.
- **AWS:** `aws_security_group` ingress with `cidr_blocks = [peer_a_cidr, peer_b_cidr]` for ICMP and TCP.
- **Best practice:** enumerate **all** peer CIDRs — copying a 2-VPC rule that lists only one peer is a common mesh bug.
- **Interview:** one missing peer CIDR drops that peer's traffic; cross-region can't use SG references.

![Tertiary security group](Screenshots/06-tertiary-security-group.png)
*Inbound ICMP + all-TCP from **both** peer CIDRs — required so the instance accepts traffic from every other VPC.*

## Project Implementation

- Three VPCs across `ap-south-1`, `ap-south-2`, `ap-southeast-1` with non-overlapping CIDRs.
- Full mesh of three cross-region peering connections (requester/accepter pattern).
- Each route table routes to both peer CIDRs via the correct peering connection.
- Each security group admits ICMP + TCP from both peer VPC CIDRs.
- Per-region key pairs (`aws_key_pair`) — least-privilege SSH isolation.
- Multi-region provider aliases; remote encrypted S3 state.

## Key Learnings

- Peering is **non-transitive** — a full mesh peers every pair (**N(N−1)/2** connections).
- Each route table needs an explicit route to **every** peer CIDR.
- Each security group must allow **all** peer CIDRs — listing only one is a silent mesh bug.
- The mesh does not scale; **Transit Gateway** gives transitive routing at linear cost.
- Cross-region peering restricts SG rules to CIDRs and caps MTU at 1500.

## Repository Structure

```
3-vpc-full-mesh/
├── main.tf         # 3× VPC, subnet, IGW, route table, SG, EC2; 3 peering edges; key pairs
├── data.tf         # AMI and Availability Zone lookups (per region)
├── variables.tf    # Regions, CIDRs, per-region key names/paths
├── outputs.tf      # Instance private/public IPs
├── providers.tf    # Three-region provider aliases
├── backend.tf      # Remote S3 state (own key)
├── keys/           # Per-region SSH public keys (private keys git-ignored)
└── Screenshots/    # Console/terminal evidence
```
