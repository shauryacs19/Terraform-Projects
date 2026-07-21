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

**What it is** — VPC peering is **non-transitive**: a connection carries
traffic only between its two VPCs. To make N VPCs mutually reachable, every
pair must be peered directly — a full mesh of **N(N−1)/2** connections.

**Why it is used here** — Three VPCs must all reach each other without a
Transit Gateway, so three peering connections are provisioned: A↔B, A↔C, B↔C.

**AWS implementation** — Three `aws_vpc_peering_connection` + accepter pairs
(cross-region requester/accepter, `auto_accept = false`), one per edge of the
mesh.

**Best practices** — Non-overlapping CIDRs across all VPCs; the mesh is only
practical for a handful of VPCs — move to Transit Gateway beyond that, since
connection count grows quadratically.

**Interview points**
- Non-transitivity is *the* reason a mesh is required — A↔B and B↔C never yields A↔C.
- Mesh scales at N(N−1)/2 (3 VPCs → 3, 4 → 6, 5 → 10); Transit Gateway scales linearly (one attachment per VPC).
- Cross-region peering: CIDR-based SG rules only (no SG references), MTU capped at 1500.

### Route Tables

**What it is** — Destination-CIDR → target rules; one table per subnet;
longest-prefix match wins.

**Why it is used here** — In a mesh, each VPC must route to **every** other
VPC's CIDR, each through its specific peering connection.

**AWS implementation** — Each route table carries **two** peer routes (plus the
IGW default), e.g. the tertiary table routes `10.0.0.0/16` and `10.1.0.0/16` to
their respective `pcx-…` connections.

**Best practices** — Standalone `aws_route` resources (never inline); a route
per peer CIDR on every route table; return routes on both ends of each edge.

**Interview points**
- Every VPC needs an explicit route to every peer — routing is not transitive either.
- A missing peer route silently breaks one direction of a pair.

### Security Groups

**What it is** — Stateful, allow-only instance firewall; rules evaluated as a
union; return traffic implicitly allowed.

**Why it is used here** — Each instance must accept traffic from **both** other
VPCs, so every SG allows the two peer CIDRs (ICMP + TCP).

**AWS implementation** — `aws_security_group` ingress with
`cidr_blocks = [peer_a_cidr, peer_b_cidr]` for ICMP and TCP.

**Best practices** — Enumerate **all** peer CIDRs (a common mesh bug is copying
a 2-VPC rule that lists only one peer); reference CIDRs, not SG IDs, across
regions; scope SSH separately.

**Interview points**
- In a mesh each SG must list every peer CIDR — one missing entry drops that peer's traffic.
- Cross-region/cross-account peering cannot use SG references — CIDRs only.

## Project Implementation

- Three VPCs across `ap-south-1`, `ap-south-2`, `ap-southeast-1` with non-overlapping CIDRs.
- Full mesh of three cross-region peering connections (requester/accepter pattern).
- Each route table routes to both peer CIDRs via the correct peering connection.
- Each security group admits ICMP + TCP from both peer VPC CIDRs.
- Per-region key pairs (`aws_key_pair`) — least-privilege SSH isolation.
- Multi-region provider aliases; remote encrypted S3 state.

## Validation

### Full transitive reachability (all-to-all)
![Primary reaches both peers](Screenshots/01-primary-reaches-both-peers.png)
![Secondary reaches both peers](Screenshots/02-secondary-reaches-both-peers.png)
![Tertiary reaches both peers](Screenshots/03-tertiary-reaches-both-peers.png)

Each instance pings and curls **both** other regions by private IP (0% loss) —
proving every VPC reaches every other VPC across the mesh.

### Cross-region peering connections active
![Primary–Tertiary peering](Screenshots/07-peering-primary-tertiary-active.png)
![Secondary–Tertiary peering](Screenshots/08-peering-secondary-tertiary-active.png)

The two tertiary edges — Mumbai↔Singapore (`10.0.0.0/16`↔`10.2.0.0/16`) and
Hyderabad↔Singapore (`10.1.0.0/16`↔`10.2.0.0/16`) — status **Active**,
completing the mesh alongside the Mumbai↔Hyderabad edge.

### Route table with routes to both peers
![Tertiary route table](Screenshots/05-tertiary-route-table.png)

The tertiary route table forwards **both** peer CIDRs (`10.0.0.0/16`,
`10.1.0.0/16`) to their peering connections — the routing that makes the mesh
work from this VPC.

### Security group admitting all peers
![Tertiary security group](Screenshots/06-tertiary-security-group.png)

Inbound ICMP and all-TCP sourced from **both** peer CIDRs — required so the
instance accepts traffic from every other VPC in the mesh.

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
└── Screenshots/    # Validation evidence
```
