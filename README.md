# tf-module-vpc

Terraform module for AWS VPC with production-grade 3 AZ high-availability design, optimized for EKS.

---

## Overview

This module provisions VPC infrastructure with a toggle between two deployment modes:

| Mode | VPCs created | Use case |
|---|---|---|
| `standalone` | 1 VPC | Single EKS cluster — in-place upgrades |
| `blue_green` | 3 VPCs (blue + green + data) | Zero-downtime cluster swap via full VPC isolation |

---

## EKS Deployment Modes

### `standalone` — in-place upgrades

Single VPC with all tiers. Upgrade EKS in place — rolling node group updates, managed node group version bumps.

```mermaid
flowchart TD
    Internet(["🌐 Internet"])

    subgraph VPC["VPC  10.100.0.0/16"]
        subgraph AZ1["Availability Zone 1"]
            pub1["Public Subnet\n10.100.0.0/27\nALB · NAT GW"]
            priv1["Private Subnet\n10.100.0.128/25\nEKS Nodes"]
            data1["Data Subnet\n10.100.6.0/26\nRDS · Redis"]
        end
        subgraph AZ2["Availability Zone 2"]
            pub2["Public Subnet\n10.100.0.32/27\nALB · NAT GW"]
            priv2["Private Subnet\n10.100.1.0/25\nEKS Nodes"]
            data2["Data Subnet\n10.100.6.64/26\nRDS · Redis"]
        end
        subgraph AZ3["Availability Zone 3"]
            pub3["Public Subnet\n10.100.0.64/27\nALB · NAT GW"]
            priv3["Private Subnet\n10.100.1.128/25\nEKS Nodes"]
            data3["Data Subnet\n10.100.6.128/26\nRDS · Redis"]
        end
    end

    Internet -->|inbound| pub1 & pub2 & pub3
    pub1 -->|ALB → pods| priv1
    pub2 -->|ALB → pods| priv2
    pub3 -->|ALB → pods| priv3
    priv1 <-->|internal| data1
    priv2 <-->|internal| data2
    priv3 <-->|internal| data3
```

### `blue_green` — zero-downtime cluster swap

Three separate, fully isolated VPCs. Blue and green each have their own IGW, NAT Gateways, public and private subnets. Both peer to a shared data VPC so RDS/Redis is not duplicated.

```mermaid
flowchart TD
    Internet(["🌐 Internet"])

    subgraph BlueVPC["Blue VPC  10.100.0.0/16"]
        direction TB
        subgraph BAZ1["AZ 1"]
            bpub1["Public\nALB · NAT GW"]
            bpriv1["Private\nEKS Blue Nodes"]
        end
        subgraph BAZ2["AZ 2"]
            bpub2["Public\nALB · NAT GW"]
            bpriv2["Private\nEKS Blue Nodes"]
        end
        subgraph BAZ3["AZ 3"]
            bpub3["Public\nALB · NAT GW"]
            bpriv3["Private\nEKS Blue Nodes"]
        end
    end

    subgraph DataVPC["Shared Data VPC  10.102.0.0/16"]
        ddata1["Data Subnet AZ1\nRDS · Redis"]
        ddata2["Data Subnet AZ2"]
        ddata3["Data Subnet AZ3"]
    end

    subgraph GreenVPC["Green VPC  10.101.0.0/16  (green_enabled = true)"]
        direction TB
        subgraph GAZ1["AZ 1"]
            gpub1["Public\nALB · NAT GW"]
            gpriv1["Private\nEKS Green Nodes"]
        end
        subgraph GAZ2["AZ 2"]
            gpub2["Public\nALB · NAT GW"]
            gpriv2["Private\nEKS Green Nodes"]
        end
        subgraph GAZ3["AZ 3"]
            gpub3["Public\nALB · NAT GW"]
            gpriv3["Private\nEKS Green Nodes"]
        end
    end

    Internet -->|inbound| bpub1 & bpub2 & bpub3
    Internet -->|inbound| gpub1 & gpub2 & gpub3
    BlueVPC  <-->|VPC Peering| DataVPC
    GreenVPC <-->|VPC Peering| DataVPC
```

**Upgrade lifecycle:**

| Step | Action |
|---|---|
| Day 0 | `green_enabled = false` — Blue VPC + Data VPC provisioned, peered |
| Upgrade | `green_enabled = true` — Green VPC provisioned, peered to Data VPC |
| Cutover | New EKS cluster in Green validated → ALB/DNS flipped Blue → Green |
| Teardown | Blue VPC destroyed entirely — true isolation, no shared blast radius |

---

## Usage

### Standalone mode

```hcl
module "vpc" {
  source = "./aj-tf-module-vpc"

  vpc_name            = "myapp"
  environment         = "prod"
  eks_deployment_mode = "standalone"
  eks_cluster_name    = "myapp-prod"

  standalone_vpc_cidr             = "10.100.0.0/16"
  standalone_public_subnet_cidrs  = ["10.100.0.0/27",   "10.100.0.32/27",  "10.100.0.64/27"]
  standalone_private_subnet_cidrs = ["10.100.0.128/25", "10.100.1.0/25",   "10.100.1.128/25"]
  standalone_data_subnet_cidrs    = ["10.100.6.0/26",   "10.100.6.64/26",  "10.100.6.128/26"]
}
```

### Blue/Green mode — Day 0 (blue only)

```hcl
module "vpc" {
  source = "./aj-tf-module-vpc"

  vpc_name              = "myapp"
  environment           = "prod"
  eks_deployment_mode   = "blue_green"
  eks_blue_cluster_name = "myapp-prod-blue"
  green_enabled         = false

  blue_vpc_cidr            = "10.100.0.0/16"
  blue_public_subnet_cidrs = ["10.100.0.0/27",   "10.100.0.32/27",  "10.100.0.64/27"]
  blue_private_subnet_cidrs = ["10.100.0.128/25", "10.100.1.0/25",  "10.100.1.128/25"]

  data_vpc_cidr      = "10.102.0.0/16"
  data_subnet_cidrs  = ["10.102.0.0/26", "10.102.0.64/26", "10.102.0.128/26"]
}
```

### Blue/Green mode — Upgrade day (green_enabled = true)

```hcl
module "vpc" {
  source = "./aj-tf-module-vpc"

  vpc_name               = "myapp"
  environment            = "prod"
  eks_deployment_mode    = "blue_green"
  eks_blue_cluster_name  = "myapp-prod-blue"
  eks_green_cluster_name = "myapp-prod-green"
  green_enabled          = true                  # ← flip this

  blue_vpc_cidr             = "10.100.0.0/16"
  blue_public_subnet_cidrs  = ["10.100.0.0/27",   "10.100.0.32/27",  "10.100.0.64/27"]
  blue_private_subnet_cidrs = ["10.100.0.128/25", "10.100.1.0/25",   "10.100.1.128/25"]

  green_vpc_cidr             = "10.101.0.0/16"
  green_public_subnet_cidrs  = ["10.101.0.0/27",   "10.101.0.32/27",  "10.101.0.64/27"]
  green_private_subnet_cidrs = ["10.101.0.128/25", "10.101.1.0/25",   "10.101.1.128/25"]

  data_vpc_cidr     = "10.102.0.0/16"
  data_subnet_cidrs = ["10.102.0.0/26", "10.102.0.64/26", "10.102.0.128/26"]
}
```

---

## Inputs

### Shared

| Name | Required | Default | Description |
|---|---|---|---|
| `vpc_name` | yes | — | Drives all resource naming |
| `aws_region` | no | `us-east-1` | AWS region |
| `environment` | no | `dev` | Environment label |
| `eks_deployment_mode` | no | `blue_green` | `standalone` or `blue_green` |
| `az_count` | no | `3` | Number of AZs (2–3) |
| `availability_zones` | no | us-east-1a/b/c | AZ list |
| `team` | no | `infra-core` | Tag |
| `cost_center` | no | `infra-2026-q1` | Tag |
| `common_tags` | no | see vars | Merged into provider default_tags |
| `tags` | no | `{}` | Additional tags |

### `standalone` mode

| Name | Required | Description |
|---|---|---|
| `standalone_vpc_cidr` | yes | VPC CIDR |
| `standalone_public_subnet_cidrs` | yes | One per AZ |
| `standalone_private_subnet_cidrs` | yes | One per AZ |
| `standalone_data_subnet_cidrs` | yes | One per AZ |
| `eks_cluster_name` | no | EKS cluster name for subnet tags |

### `blue_green` mode

| Name | Required | Description |
|---|---|---|
| `green_enabled` | no (`false`) | Set `true` to provision green VPC |
| `blue_vpc_cidr` | yes | Blue VPC CIDR |
| `blue_public_subnet_cidrs` | yes | One per AZ |
| `blue_private_subnet_cidrs` | yes | One per AZ |
| `green_vpc_cidr` | when green_enabled | Green VPC CIDR |
| `green_public_subnet_cidrs` | when green_enabled | One per AZ |
| `green_private_subnet_cidrs` | when green_enabled | One per AZ |
| `data_vpc_cidr` | yes | Shared data VPC CIDR |
| `data_subnet_cidrs` | yes | One per AZ |
| `eks_blue_cluster_name` | no | Blue cluster name for subnet tags |
| `eks_green_cluster_name` | no | Green cluster name for subnet tags |

---

## Outputs

### `standalone` mode

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `data_subnet_ids` | Data subnet IDs |
| `nat_gateway_ids` | NAT Gateway IDs |
| `nat_public_ips` | NAT public IPs |
| `private_route_table_ids` | Private route table IDs |

### `blue_green` mode

| Name | Description |
|---|---|
| `blue_vpc_id` | Blue VPC ID |
| `blue_public_subnet_ids` | Blue public subnet IDs |
| `blue_private_subnet_ids` | Blue private subnet IDs |
| `blue_data_peering_id` | Blue ↔ Data peering connection ID |
| `green_vpc_id` | Green VPC ID (null when green_enabled = false) |
| `green_public_subnet_ids` | Green public subnet IDs |
| `green_private_subnet_ids` | Green private subnet IDs |
| `green_data_peering_id` | Green ↔ Data peering connection ID |
| `data_vpc_id` | Shared data VPC ID |
| `data_vpc_subnet_ids` | Shared data subnet IDs (RDS/Redis) |

All outputs are `null` or `[]` when not applicable to the active mode.

---

## Cost Note

NAT Gateways: ~$32/month each. 3 AZs × 3 VPCs (blue_green with green enabled) = up to 9 NAT GWs (~$288/month). Green VPC is provisioned only during upgrades — destroy it after cutover to eliminate the cost.

Use `az_count = 2` for non-prod to reduce costs further.
