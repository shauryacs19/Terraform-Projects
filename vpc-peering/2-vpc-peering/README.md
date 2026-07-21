# Cross-Region VPC Peering

Private, cross-region connectivity between two isolated VPCs (`ap-south-1` and
`ap-south-2`) using an AWS VPC peering connection, provisioned with Terraform.
Traffic between the VPCs traverses the AWS backbone over private IPs — never
the public internet. Validated with live ICMP and HTTP between instances in
different regions.

> Part of the [VPC Peering series](../README.md): **2-VPC (this)** ·
> [3-VPC full mesh](../3-vpc-full-mesh/) · [3-VPC transit gateway](../3-vpc-transit-gateway/)

## Architecture

<img src="Screenshots/architecture.png" width="640">

## AWS Services Used

| Service | Purpose |
|---|---|
| **VPC Peering** | Private cross-region link between the two VPCs |
| **Route Tables** | Direct peer-CIDR traffic through the peering connection |
| **Security Groups** | Allow ICMP/TCP inbound from the peer VPC CIDR |
| VPC | Two isolated networks — `10.0.0.0/16` and `10.1.0.0/16` |
| Subnets | One public `/24` per VPC |
| Internet Gateway | Outbound access for instance bootstrap and SSH |
| EC2 | Endpoints used only to validate connectivity |
| S3 | Remote, encrypted Terraform state backend |

## Core Concepts

### Cross-Region VPC Peering

- Private, one-to-one link between two VPCs; traffic stays on the AWS backbone over private IPs.
- **Non-transitive** — a connection joins only its own two VPCs.
- Cross-region uses a requester/accepter handshake; the peer region must explicitly accept (no auto-accept).
- Requires **non-overlapping** CIDR ranges.
- Cross-region limits: security groups cannot reference peer SGs (use CIDRs), MTU is capped at 1500, and data transfer is billed per GB.

<img src="Screenshots/07-peering-connection-mumbai-view.png" width="560">

*Requester Mumbai (`10.0.0.0/16`) ↔ accepter Hyderabad (`10.1.0.0/16`), status **Active** — cross-region peering established.*

<table><tr>
<td><img src="Screenshots/01-primary-to-secondary-ping-curl.png" width="400"></td>
<td><img src="Screenshots/02-secondary-to-primary-ping-curl.png" width="400"></td>
</tr></table>

*Both instances ping and curl each other by private IP (0% loss) — traffic routes over the peering connection, not the internet.*

### Route Tables

- Map a destination CIDR to a target; each subnet uses exactly one table; the most-specific route wins.
- A peering connection is inert until **each side** adds a route to the peer's CIDR through it.
- Routing is directional — both VPCs need their own route.

<img src="Screenshots/05-primary-route-table.png" width="560">

*Peer CIDR (`10.1.0.0/16`) routed to the peering connection — what makes peering functional.*

### Security Groups

- Stateful, allow-only firewall at the instance; return traffic is permitted automatically.
- To allow cross-VPC traffic, admit the peer VPC's CIDR — ICMP for reachability, TCP for the application.
- Across regions, rules must be CIDR-based (SG references don't work); SSH is scoped separately.

<img src="Screenshots/09-primary-security-group.png" width="560">

*Inbound ICMP + all-TCP from the peer CIDR (`10.1.0.0/16`) — admits cross-VPC traffic.*

## Project Implementation

- Two VPCs in `ap-south-1` and `ap-south-2` with non-overlapping CIDRs.
- Cross-region peering via the requester / accepter handshake.
- Route tables on both sides directing the peer CIDR through the peering connection.
- Security groups allowing ICMP + TCP from the peer VPC CIDR.
- Fixed private IPs (`10.0.1.10` / `10.1.1.10`) for stable validation.
- Two regions managed from one Terraform configuration; remote encrypted state.

## Key Learnings

- Peering is **non-transitive** and needs routes **and** SG rules on both sides.
- **Non-overlapping CIDRs** are mandatory.
- Cross-region peering cannot use SG references — rules are CIDR-based, and MTU is capped at 1500.
- Ping succeeding while curl fails isolates a security-group/service issue from routing.

## Repository Structure

```
2-vpc-peering/
├── main.tf         # VPCs, subnets, IGWs, route tables, peering, security groups, EC2
├── data.tf         # AMI and Availability Zone lookups
├── variables.tf    # Regions, CIDRs, key names
├── outputs.tf      # Instance private/public IPs
├── providers.tf    # Multi-region provider aliases
├── backend.tf      # Remote S3 state
└── Screenshots/    # Console/terminal evidence
```
