# CLAUDE.md — aj-tf-module-vpc

> Local context file for Claude Code. Not pushed to GitHub.

---

## What This Module Does

Terraform module that provisions production-grade AWS VPC infrastructure with a toggle between two deployment modes:

- **`standalone`** — single VPC for in-place EKS upgrades
- **`blue_green`** — three separate VPCs (blue + green + shared data) for zero-downtime cluster swaps

---

## Architecture

### `standalone` mode

Single VPC containing all tiers. Simple topology, in-place EKS upgrades only.

```
Internet → IGW → Public Subnets (ALB/NAT)
                       ↓
               Private Subnets (EKS nodes)
                       ↓
               Data Subnets (RDS/Redis)
```

### `blue_green` mode

Three isolated VPCs. Blue and green are fully independent cluster environments. Both peer to a shared data VPC so RDS/Redis is not duplicated.

```
Internet → Blue VPC (IGW + NAT + Public + Private)
                       ↓ VPC Peering
               Data VPC (RDS/Redis — no internet)
                       ↑ VPC Peering
Internet → Green VPC (IGW + NAT + Public + Private)  ← provisioned when green_enabled = true
```

**Lifecycle:**
1. `green_enabled = false` → only Blue VPC + Data VPC provisioned
2. Upgrade time: set `green_enabled = true` → Green VPC provisioned, peered to Data VPC
3. Run new EKS cluster in Green, validate, cut ALB/DNS traffic over
4. Destroy Blue VPC entirely (full teardown — true isolation)
5. Green becomes the new live environment

---

## Module Structure

```
aj-tf-module-vpc/
├── main.tf              # orchestrates submodules based on eks_deployment_mode
├── variables.tf         # all input variables (mode-grouped)
├── outputs.tf           # outputs per VPC (null/empty when not provisioned)
├── locals.tf            # name_prefix, azs, mode booleans, full_tags
├── providers.tf         # AWS provider with default_tags
└── modules/
    ├── vpc-standalone/  # single VPC (public + private + data)
    ├── vpc-cluster/     # cluster VPC (public + private + IGW + NAT) — used for both blue and green
    ├── vpc-data/        # shared data VPC (data subnets, no internet)
    └── vpc-peering/     # VPC peering connection + bidirectional routes
```

---

## Variables

### Shared

| Variable | Required | Default | Description |
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

| Variable | Required | Description |
|---|---|---|
| `standalone_vpc_cidr` | yes | VPC CIDR |
| `standalone_public_subnet_cidrs` | yes | Public subnet CIDRs |
| `standalone_private_subnet_cidrs` | yes | Private subnet CIDRs |
| `standalone_data_subnet_cidrs` | yes | Data subnet CIDRs |
| `eks_cluster_name` | no | EKS cluster name for subnet tags |

### `blue_green` mode

| Variable | Required | Description |
|---|---|---|
| `green_enabled` | no (default `false`) | Flip to `true` to provision green VPC |
| `blue_vpc_cidr` | yes | Blue VPC CIDR |
| `blue_public_subnet_cidrs` | yes | Blue public subnet CIDRs |
| `blue_private_subnet_cidrs` | yes | Blue private subnet CIDRs |
| `green_vpc_cidr` | when green_enabled | Green VPC CIDR |
| `green_public_subnet_cidrs` | when green_enabled | Green public subnet CIDRs |
| `green_private_subnet_cidrs` | when green_enabled | Green private subnet CIDRs |
| `data_vpc_cidr` | yes | Shared data VPC CIDR |
| `data_subnet_cidrs` | yes | Shared data subnet CIDRs |
| `eks_blue_cluster_name` | no | Blue EKS cluster name for subnet tags |
| `eks_green_cluster_name` | no | Green EKS cluster name for subnet tags |

---

## Outputs

### `standalone` mode

| Output | Description |
|---|---|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR |
| `igw_id` | Internet Gateway ID |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `data_subnet_ids` | Data subnet IDs |
| `nat_gateway_ids` | NAT Gateway IDs |
| `nat_public_ips` | NAT Gateway public IPs |
| `private_route_table_ids` | Private route table IDs |
| `data_route_table_id` | Data route table ID |

### `blue_green` mode

| Output | Description |
|---|---|
| `blue_vpc_id` | Blue VPC ID |
| `blue_public_subnet_ids` | Blue public subnet IDs |
| `blue_private_subnet_ids` | Blue private subnet IDs |
| `blue_nat_public_ips` | Blue NAT public IPs |
| `blue_data_peering_id` | Blue ↔ Data peering connection ID |
| `green_vpc_id` | Green VPC ID (null when green_enabled = false) |
| `green_public_subnet_ids` | Green public subnet IDs |
| `green_private_subnet_ids` | Green private subnet IDs |
| `green_data_peering_id` | Green ↔ Data peering connection ID |
| `data_vpc_id` | Shared data VPC ID |
| `data_vpc_subnet_ids` | Shared data subnet IDs |
| `data_vpc_route_table_id` | Shared data route table ID |

All outputs are `null` or `[]` when not applicable to the active mode.

---

## Design Decisions

- **Separate VPCs for blue/green** — true blast radius isolation; full VPC teardown after cutover
- **Shared data VPC** — RDS/Redis provisioned once; no data sync complexity during upgrades
- **`green_enabled` toggle** — green VPC only exists when needed; avoids paying for idle infra
- **`vpc-cluster` reused for blue and green** — DRY; same resource structure, different `color` param
- **VPC peering (not TGW)** — two peering connections (blue↔data, green↔data) is sufficient; TGW adds cost for this topology
- **NAT per AZ** — avoids cross-AZ traffic charges; ~$32/AZ/month
- **`default_tags` via provider** — tags applied centrally; submodules inherit automatically
- **`eks_deployment_mode` string** — self-documenting, extensible

---

## Provider Notes

- Local dev: `~/.aws/credentials` with `AWS_PROFILE`
- Pipeline: uncomment `assume_role` block in `providers.tf`, pass `var.aws_assume_role_arn` via CI
- Backend: configured externally via `-backend-config` (S3 + DynamoDB lock)

---

## Naming Convention

Pattern: `{vpc_name}-{environment}-{color}-{resource}-{index}`

Examples (`vpc_name=myapp`, `environment=prod`):

| Resource | Name |
|---|---|
| Blue VPC | `myapp-prod-blue-vpc` |
| Green VPC | `myapp-prod-green-vpc` |
| Data VPC | `myapp-prod-data-vpc` |
| Blue private subnet 1 | `myapp-prod-blue-private-1` |
| Green NAT GW 2 | `myapp-prod-green-nat-2` |
| Standalone private RT 1 | `myapp-prod-private-rt-1` |

---

## Known TODOs

- [ ] VPC Flow Logs
- [ ] VPC Endpoints (S3/DynamoDB gateway — free; ECR/SSM interface — reduces NAT cost)
- [ ] Single NAT mode flag for dev/staging cost savings
- [ ] Network ACLs
- [ ] CIDR validation (subnets within vpc_cidr, non-overlapping)
- [ ] Cross-account peering support (requires accepter resource + separate provider)
