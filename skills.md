# skills.md — aj-tf-module-vpc

## Purpose
Provisions AWS VPC infrastructure. Supports three modes: standalone single VPC, and blue/green dual-VPC for zero-downtime cluster replacement.

## Type
`tf-module`

## Stable ref
```
source = "github.com/ajaylakma/aj-tf-module-vpc?ref=vpc-01"
```

## Deployment modes
- `standalone` — single VPC with public, private, and data subnet tiers
- `blue-green` — dual VPC pair for blue/green EKS cluster strategy

## Key inputs
| Variable | Description |
|---|---|
| `vpc_name` | Name prefix for the VPC |
| `environment` | dev \| staging \| uat \| prod |
| `team` | Owning team slug |
| `eks_deployment_mode` | standalone \| blue-green |
| `az_count` | Number of AZs to span |
| `standalone_vpc_cidr` | CIDR for standalone mode |
| `blue_vpc_cidr` / `green_vpc_cidr` | CIDRs for blue/green mode |

## Key outputs
| Output | Description |
|---|---|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `data_subnet_ids` | Data tier subnet IDs |
| `nat_gateway_ids` | NAT gateway IDs |
| `eks_deployment_mode` | Mode in use |

## AWS tags applied
`Env`, `Team`, `ManagedBy`, `CostCenter`, `Model`, `Customer`

## Branching convention
- `main` — active development
- `vpc-01` — stable pinned release

## CI checks
fmt, validate, plan (dry-run), tfsec/checkov

## Agentic capabilities
- Detect CIDR overlap across blue/green VPCs
- Validate subnet tier sizing vs az_count
- Generate PR to bump vpc-01 branch after main is stable
- Flag missing required tags in variables
