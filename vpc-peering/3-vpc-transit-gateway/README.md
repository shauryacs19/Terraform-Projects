# 3-VPC Connectivity with AWS Transit Gateway

> Connect **three** VPCs so every VPC can reach every other — using an **AWS
> Transit Gateway** as a central hub. Unlike raw VPC peering, a Transit Gateway
> provides **transitive** routing, so you don't need a connection per pair.

| | |
|---|---|
| **Cloud Provider** | Amazon Web Services (AWS) |
| **IaC Tool** | Terraform (`~> 6.0` AWS provider) |
| **Topology** | Hub-and-spoke — 1 Transit Gateway, 3 attachments |
| **Status** | 📐 Design / planned (no Terraform yet) |

> **Part of the [VPC Peering series](../README.md):**
> [2-VPC](../2-vpc-peering/) · [3-VPC full mesh](../3-vpc-full-mesh/) ·
> **3-VPC transit gateway (this)**

## Why a Transit Gateway?

VPC peering is **non-transitive** and needs one connection per pair
(**N(N−1)/2** total), which stops scaling. A **Transit Gateway (TGW)** is a
regional hub: every VPC makes **one** attachment to it, and the TGW's route
table forwards traffic between all attachments — so connectivity is
**transitive** and grows **linearly** (N attachments, not N² connections).

| | Full mesh peering | Transit Gateway |
|---|---|---|
| Transitive routing | ❌ (peer every pair) | ✅ (hub routes between all) |
| Connections for N VPCs | N(N−1)/2 | N attachments |
| Best for | 2–3 VPCs, simple | many VPCs, complex topologies |

## Architecture (diagram)

Export the rendered diagram to `architecture-3vpc-transit-gateway.png` and it
will appear here:

<!-- ![3 VPCs via Transit Gateway](architecture-3vpc-transit-gateway.png) -->

### Eraser diagram-as-code

```
// 3-VPC Transitive Routing via AWS Transit Gateway
title Transitive Routing — 3 VPCs via Transit Gateway

Transit Gateway [icon: aws-transit-gateway, color: purple]

VPC A [icon: aws-vpc, color: orange, label: "VPC A · 10.0.0.0/16"] {
  Subnet A [icon: aws-vpc-subnet-private, label: "10.0.1.0/24"] { EC2 A [icon: aws-ec2] }
  RT A [icon: aws-route-table, label: "Route Table"]
}
VPC B [icon: aws-vpc, color: green, label: "VPC B · 10.1.0.0/16"] {
  Subnet B [icon: aws-vpc-subnet-private, label: "10.1.1.0/24"] { EC2 B [icon: aws-ec2] }
  RT B [icon: aws-route-table, label: "Route Table"]
}
VPC C [icon: aws-vpc, color: blue, label: "VPC C · 10.2.0.0/16"] {
  Subnet C [icon: aws-vpc-subnet-private, label: "10.2.1.0/24"] { EC2 C [icon: aws-ec2] }
  RT C [icon: aws-route-table, label: "Route Table"]
}

// one attachment per VPC (linear, not per-pair)
VPC A <> Transit Gateway: TGW attachment
VPC B <> Transit Gateway: TGW attachment
VPC C <> Transit Gateway: TGW attachment

// each VPC route table points the other CIDRs at the TGW
RT A > Transit Gateway: 10.1.0.0/16, 10.2.0.0/16 → TGW
RT B > Transit Gateway: 10.0.0.0/16, 10.2.0.0/16 → TGW
RT C > Transit Gateway: 10.0.0.0/16, 10.1.0.0/16 → TGW

note Transit Gateway's route table connects all attachments, so A↔B↔C all reach each other (transitive).
```

## Terraform approach (when built)

- **`aws_ec2_transit_gateway`** — the hub.
- **`aws_ec2_transit_gateway_vpc_attachment`** — one per VPC (attaches selected
  subnets).
- **VPC route entries** with `transit_gateway_id = ...` pointing each peer CIDR
  at the TGW (instead of `vpc_peering_connection_id`).
- Optional **`aws_ec2_transit_gateway_route_table`** for finer control over
  which attachments can talk to which.

### Multi-region note

A Transit Gateway is **regional**. If the three VPCs span multiple regions
(like the [2-VPC project](../2-vpc-peering/) does), you deploy **one TGW per
region** and join them with **inter-region TGW peering**
(`aws_ec2_transit_gateway_peering_attachment`). For a single-region three-VPC
setup, one TGW is enough.

## Deploy (when built)

Will use its own remote state key
(`vpc-peering-transit-gateway/terraform.tfstate`), independent of the other
projects.
