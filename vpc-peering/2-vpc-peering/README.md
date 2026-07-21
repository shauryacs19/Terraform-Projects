# Cross-Region VPC Peering

Private, cross-region connectivity between two isolated VPCs (`ap-south-1` and
`ap-south-2`) using an AWS VPC peering connection, provisioned with Terraform.
Traffic between the VPCs traverses the AWS backbone over private IPs — never
the public internet. Validated with live ICMP and HTTP between instances in
different regions.

> Part of the [VPC Peering series](../README.md): **2-VPC (this)** ·
> [3-VPC full mesh](../3-vpc-full-mesh/) · [3-VPC transit gateway](../3-vpc-transit-gateway/)

## Architecture

![Architecture](Screenshots/architecture.png)

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
| Provider aliases | Manage two regions from one configuration |

## Core Concepts

### Cross-Region VPC Peering

- **What:** one-to-one, non-transitive link between two VPCs, routing over the AWS backbone on private IPs.
- **Why here:** join two regionally-isolated VPCs without exposing traffic to the internet.
- **AWS:** `aws_vpc_peering_connection` (requester, `peer_region`) + `aws_vpc_peering_connection_accepter`; `auto_accept = false` — cross-region can't auto-accept in one step.
- **Requires:** non-overlapping CIDRs.
- **Interview:** non-transitive (A↔B + B↔C ≠ A↔C); SG references don't work cross-region — use CIDRs; MTU capped at 1500; cross-region transfer billed per GB.

![Peering active](Screenshots/07-peering-connection-mumbai-view.png)
*Requester Mumbai (`10.0.0.0/16`) ↔ accepter Hyderabad (`10.1.0.0/16`), status **Active** — cross-region peering established.*

![Primary to secondary](Screenshots/01-primary-to-secondary-ping-curl.png)
![Secondary to primary](Screenshots/02-secondary-to-primary-ping-curl.png)
*Both instances ping and curl each other by private IP (0% loss) — traffic routes over the peering connection, not the internet.*

### Route Tables

- **What:** destination-CIDR → target rules; one table per subnet; longest-prefix match wins.
- **Why here:** a peering connection carries no traffic until each side routes the peer CIDR to it.
- **AWS:** standalone `aws_route` with `vpc_peering_connection_id` on **both** tables, plus a default route to the IGW.
- **Best practice:** never mix inline `route {}` blocks with `aws_route` resources (perpetual conflicts).
- **Interview:** routes required on **both** sides; a peering connection alone does nothing without them.

![Route table](Screenshots/05-primary-route-table.png)
*Peer CIDR (`10.1.0.0/16`) → peering connection (`pcx-…`) — the route that makes peering functional.*

### Security Groups

- **What:** stateful, allow-only instance firewall; rules evaluated as a union; return traffic implicit.
- **Why here:** each SG must admit inbound from the peer VPC CIDR (ICMP + TCP).
- **AWS:** `aws_security_group` ingress with `cidr_blocks = [peer_vpc_cidr]`.
- **Best practice:** reference peer **CIDRs** (SG references fail cross-region); scope SSH separately.
- **Interview:** stateful (return auto-allowed); allow-only (NACLs for deny); cross-region forces CIDR-based rules.

![Security group](Screenshots/09-primary-security-group.png)
*Inbound ICMP + all-TCP from the peer CIDR (`10.1.0.0/16`) — admits cross-VPC traffic.*

## Project Implementation

- Two VPCs in `ap-south-1` and `ap-south-2` with non-overlapping CIDRs.
- Cross-region peering via the requester / accepter pattern (`auto_accept = false`).
- Route tables on both sides directing the peer CIDR through the peering connection.
- Security groups allowing ICMP + TCP from the peer VPC CIDR.
- Fixed private IPs (`10.0.1.10` / `10.1.1.10`) for stable validation.
- Multi-region provider aliases; remote encrypted S3 state.

## Key Learnings

- Peering is **non-transitive** and needs routes **and** SG rules on both sides.
- **Non-overlapping CIDRs** are mandatory for peering.
- Cross-region peering **cannot** use SG references — rules must be CIDR-based.
- Isolating ICMP vs TCP (ping works, curl fails) pinpoints SG/service vs routing issues.
- Mixing inline routes with `aws_route` resources causes route conflicts.

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
