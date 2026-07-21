# VPC Peering — Connecting VPCs on AWS with Terraform

A three-part series on connecting Amazon VPCs, from a simple two-VPC peering to
transitive connectivity across three VPCs — with and without a Transit Gateway.
Each part is a self-contained Terraform project with its own README.

## The three versions

| # | Project | Topology | Transitive? | Status |
|---|---|---|---|---|
| 1 | **[2-vpc-peering](2-vpc-peering/)** | Direct cross-region peering between 2 VPCs | n/a (only 2) | ✅ Deployed & verified |
| 2 | **[3-vpc-full-mesh](3-vpc-full-mesh/)** | 3 VPCs, full mesh — peer every pair (no Transit Gateway) | ✅ (via full mesh) | ✅ Deployed & verified |
| 3 | **[3-vpc-transit-gateway](3-vpc-transit-gateway/)** | 3 VPCs attached to a central Transit Gateway hub | ✅ (native) | 📐 Design / planned |

> **Why three versions:** VPC peering is non-transitive (A↔B and B↔C does not
> give A↔C). The full mesh works around this by peering every pair; a Transit
> Gateway solves it natively. Concept details live in each sub-project's README.

## Conventions

- Each sub-project manages its **own** remote Terraform state (distinct S3
  key) and its own `terraform.tfvars` / key pairs.
- Secrets (`*.pem`, `terraform.tfvars`, state, `.terraform/`) are git-ignored —
  never committed.
