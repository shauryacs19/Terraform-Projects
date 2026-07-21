# VPC Peering — Connecting VPCs on AWS with Terraform

A three-part series on connecting Amazon VPCs, from a simple two-VPC peering to
transitive connectivity across three VPCs — with and without a Transit Gateway.
Each part is a self-contained Terraform project with its own README.

## The three versions

| # | Project | Topology | Transitive? | Status |
|---|---|---|---|---|
| 1 | **[2-vpc-peering](2-vpc-peering/)** | Direct cross-region peering between 2 VPCs | n/a (only 2) | ✅ Deployed & verified |
| 2 | **[3-vpc-full-mesh](3-vpc-full-mesh/)** | 3 VPCs, full mesh — peer every pair (no Transit Gateway) | ✅ (via full mesh) | 🚧 Work in progress |
| 3 | **[3-vpc-transit-gateway](3-vpc-transit-gateway/)** | 3 VPCs attached to a central Transit Gateway hub | ✅ (native) | 📐 Design / planned |

## How they differ

- **[2-VPC peering](2-vpc-peering/)** — the foundation. Two VPCs in different
  regions, joined by a single peering connection, with EC2 web servers proven
  reachable over private IPs. This is the fully working, verified demo.

- **[3-VPC full mesh](3-vpc-full-mesh/)** — because VPC peering is
  **non-transitive**, reaching all three VPCs requires peering **every pair**
  directly (`A↔B`, `B↔C`, `A↔C` = 3 connections). Shows the pattern — and why
  it doesn't scale (N(N−1)/2 connections).

- **[3-VPC Transit Gateway](3-vpc-transit-gateway/)** — a Transit Gateway hub
  gives **transitive** routing with just **one attachment per VPC** (linear,
  not quadratic). The right tool once you outgrow a handful of VPCs.

## Key concept

> **VPC peering is non-transitive.** A↔B and B↔C does **not** give you A↔C.
> Full mesh works around this by peering every pair; a Transit Gateway solves
> it natively with a hub that routes between all attachments.

## Conventions

- Each sub-project manages its **own** remote Terraform state (distinct S3
  key) and its own `terraform.tfvars` / key pairs.
- Secrets (`*.pem`, `terraform.tfvars`, state, `.terraform/`) are git-ignored —
  never committed.
