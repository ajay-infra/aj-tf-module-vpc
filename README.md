# aj-tf-module-vpc

Terraform module for AWS VPC networking — the foundation of every cluster in the platform. Supports two deployment modes and all three cluster topology types used by `aj-infra-release`.

---

## When to use which mode

| Mode | VPCs | EKS upgrade strategy | Use for |
|---|---|---|---|
| `standalone` | 1 | In-place rolling update | SaaS dev cluster (shared, all teams) |
| `blue_green` | 3 (blue + green + data) | Zero-downtime cluster swap | Product clusters, SaaS customer clusters |

**Rule of thumb:** if this cluster ever needs a zero-downtime Kubernetes minor version upgrade, use `blue_green`. If it can tolerate a brief API server blip during a node roll, `standalone` is simpler and cheaper.

---

## Cluster topology reference

The platform runs three types of clusters. Each maps directly to a VPC mode and a set of `envs/` files:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TYPE 1 — Product cluster (per region)                                      │
│  Your own product, one cluster per region.                                  │
│  Mode: blue_green   az_count: 3 (prod) / 2 (dev+staging)                   │
│  envs/: dev.tfvars  staging.tfvars  prod.tfvars                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  TYPE 2 — SaaS customer cluster (per customer)                              │
│  Fully dedicated, isolated stack per paying customer.                       │
│  Mode: blue_green   az_count: 3                                             │
│  envs/: customer-<id>.tfvars  (in aj-infra-release, not this repo)         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  TYPE 3 — SaaS dev cluster (shared)                                         │
│  One shared cluster for all internal dev/staging teams.                     │
│  Mode: standalone   az_count: 2                                             │
│  envs/: saas-dev.tfvars  (in aj-infra-release)                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Deployment modes

### `standalone` — single VPC, in-place upgrades

One VPC with public, private, and data subnet tiers. EKS upgrades roll nodes in place — no DNS or traffic migration required.

```
Internet
   │
   ▼
Public subnets  (ALB, NAT Gateways)
   │
   ▼
Private subnets (EKS nodes)
   │
   ▼
Data subnets    (Aurora, Valkey — internet-isolated)
```

**When to choose standalone:**
- SaaS dev/staging clusters where brief API server blips are acceptable
- Cost-sensitive environments (fewer NAT Gateways, no green VPC cost)
- Patch upgrades (1.35.x → 1.35.y) on any cluster type

---

### `blue_green` — three VPCs, zero-downtime cluster swap

Three fully isolated VPCs. Blue and green each have independent IGWs, NAT Gateways, public/private subnets, and EKS clusters. Both peer into a shared data VPC so Aurora and Valkey are never duplicated.

```
Internet                        Internet
   │                               │
   ▼                               ▼
Blue VPC (active)           Green VPC (standby)
  Public / Private             Public / Private
       │                               │
       └───────────┬───────────────────┘
                   │  VPC Peering
                   ▼
              Data VPC
         Aurora · Valkey
        (no internet gateway)
```

**Upgrade lifecycle:**

| Step | Action | `green_enabled` |
|---|---|---|
| Normal operation | Blue cluster active, green does not exist | `false` |
| Start upgrade | Provision green VPC + new EKS cluster | `true` |
| Validate | Deploy workloads to green, run smoke tests | `true` |
| Cutover | Flip `active.<domain>` CNAME from blue ALB → green ALB | `true` |
| Teardown | Destroy blue VPC entirely — full blast radius separation | `false` (blue destroyed) |

**Key invariant:** CloudFront is never updated during a cutover. It always points to `active.<domain>` — only that CNAME record moves.

---

## Standard CIDR plan

These are the CIDRs used in the `envs/` files and expected by `aj-infra-release`. All ranges are non-overlapping and valid for both VPC Peering and Transit Gateway.

| Cluster | Blue VPC | Green VPC | Data VPC | Account |
|---|---|---|---|---|
| `dev` | 10.100.0.0/16 | 10.101.0.0/16 | 10.102.0.0/16 | dev |
| `staging` | 10.110.0.0/16 | 10.111.0.0/16 | 10.112.0.0/16 | staging |
| `prod` | 10.120.0.0/16 | 10.121.0.0/16 | 10.122.0.0/16 | prod |
| `central-nonprod` | 10.200.0.0/16 | — | — | central |
| `central-prod` | 10.201.0.0/16 | — | — | central |

Green VPC CIDRs are only used when `green_enabled = true`. They are pre-allocated to ensure no overlap when provisioned.

---

## envs/ — ready-to-use tfvars files

The `envs/` directory contains pre-configured tfvars files for each standard environment. These are consumed directly by `aj-infra-release` pipelines.

```
envs/
├── dev.tfvars      — dev cluster, az_count=2, 10.100.x.x CIDRs
├── staging.tfvars  — staging cluster, az_count=2, 10.110.x.x CIDRs
└── prod.tfvars     — prod cluster, az_count=3, 10.120.x.x CIDRs
```

All three use `eks_deployment_mode = "blue_green"` with `green_enabled = false` by default. To start a cluster upgrade, uncomment the green CIDR block in the relevant file and set `green_enabled = true`.

For SaaS customer clusters, the customer-specific tfvars live in `aj-infra-release/envs/<customer-id>/vpc.tfvars` rather than here — this module's `envs/` covers the platform's own environments only.

---

## How aj-infra-release uses this module

VPC is **Stage 1** in every provisioning pipeline (`provision-eks.yml`):

```
Stage 1: aj-tf-module-vpc  ← this module
  terraform init -backend-config="bucket=<state-bucket>" \
                 -backend-config="key=<env>/vpc/terraform.tfstate"
  terraform apply -var-file=envs/dev/common.tfvars \
                  -var-file=envs/dev/vpc.tfvars

Stage 2: aj-tf-module-eks
  # VPC outputs passed as -var flags at runtime (not remote state)
  terraform apply -var="vpc_id=$(tf_output vpc_id)" \
                  -var="private_subnet_ids=[...]" \
                  -var="public_subnet_ids=[...]"

Stage 3: aj-infra-platform
  # Reads EKS remote state — no direct VPC dependency
  terraform apply -var-file=envs/dev/common.tfvars

Stage 4+: aj-tf-module-aurora, aj-tf-module-valkey
  # Consume data_vpc_id + data_vpc_subnet_ids from VPC outputs
  terraform apply -var="data_vpc_id=$(tf_output data_vpc_id)" \
                  -var="data_subnet_ids=[...]"
```

VPC outputs flow directly to downstream modules as `-var` flags — there is no `terraform_remote_state` read of VPC state. This keeps module blast radii separate and avoids cross-state coupling.

---

## Usage

### Standalone — SaaS dev cluster

```hcl
module "vpc" {
  source = "github.com/ajay-infra/aj-tf-module-vpc?ref=v1.0.0"

  vpc_name            = "saas-dev"
  environment         = "dev"
  eks_deployment_mode = "standalone"
  eks_cluster_name    = "saas-dev"
  az_count            = 2

  standalone_vpc_cidr             = "10.100.0.0/16"
  standalone_public_subnet_cidrs  = ["10.100.0.0/27",   "10.100.0.32/27"]
  standalone_private_subnet_cidrs = ["10.100.0.128/25",  "10.100.1.0/25"]
  standalone_data_subnet_cidrs    = ["10.100.6.0/26",    "10.100.6.64/26"]
}
```

### Blue/Green — Day 0 (blue only)

```hcl
module "vpc" {
  source = "github.com/ajay-infra/aj-tf-module-vpc?ref=v1.0.0"

  vpc_name              = "platform-prod"
  environment           = "prod"
  eks_deployment_mode   = "blue_green"
  eks_blue_cluster_name = "platform-prod-blue"
  az_count              = 3
  green_enabled         = false

  blue_vpc_cidr             = "10.120.0.0/16"
  blue_public_subnet_cidrs  = ["10.120.0.0/27",   "10.120.0.32/27",  "10.120.0.64/27"]
  blue_private_subnet_cidrs = ["10.120.0.128/25",  "10.120.1.0/25",  "10.120.1.128/25"]

  data_vpc_cidr     = "10.122.0.0/16"
  data_subnet_cidrs = ["10.122.0.0/26", "10.122.0.64/26", "10.122.0.128/26"]
}
```

### Blue/Green — Upgrade day (flip green_enabled = true)

```hcl
module "vpc" {
  source = "github.com/ajay-infra/aj-tf-module-vpc?ref=v1.0.0"

  vpc_name               = "platform-prod"
  environment            = "prod"
  eks_deployment_mode    = "blue_green"
  eks_blue_cluster_name  = "platform-prod-blue"
  eks_green_cluster_name = "platform-prod-green"
  az_count               = 3
  green_enabled          = true  # ← flip this, then apply

  blue_vpc_cidr             = "10.120.0.0/16"
  blue_public_subnet_cidrs  = ["10.120.0.0/27",   "10.120.0.32/27",  "10.120.0.64/27"]
  blue_private_subnet_cidrs = ["10.120.0.128/25",  "10.120.1.0/25",  "10.120.1.128/25"]

  green_vpc_cidr             = "10.121.0.0/16"
  green_public_subnet_cidrs  = ["10.121.0.0/27",   "10.121.0.32/27",  "10.121.0.64/27"]
  green_private_subnet_cidrs = ["10.121.0.128/25",  "10.121.1.0/25",  "10.121.1.128/25"]

  data_vpc_cidr     = "10.122.0.0/16"
  data_subnet_cidrs = ["10.122.0.0/26", "10.122.0.64/26", "10.122.0.128/26"]
}
```

### Using envs/ files directly (release pipeline style)

```bash
terraform init \
  -backend-config="bucket=tf-state-central-123456789012" \
  -backend-config="key=dev/vpc/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=tf-locks-central"

terraform apply -var-file=envs/dev.tfvars
```

---

## Inputs

### Core

| Name | Required | Default | Description |
|---|---|---|---|
| `vpc_name` | yes | — | Drives all resource naming |
| `environment` | no | `dev` | Environment label for tags |
| `aws_region` | no | `us-east-1` | AWS region |
| `eks_deployment_mode` | no | `blue_green` | `standalone` or `blue_green` |
| `az_count` | no | `3` | AZs to use: 2 (dev/staging), 3 (prod), 4 (regulated) |
| `availability_zones` | no | us-east-1a/b/c/d | AZ list — must have ≥ `az_count` entries |

### standalone mode

| Name | Required | Description |
|---|---|---|
| `eks_cluster_name` | no | EKS cluster name for subnet tags |
| `standalone_vpc_cidr` | yes | Single VPC CIDR |
| `standalone_public_subnet_cidrs` | yes | One per AZ |
| `standalone_private_subnet_cidrs` | yes | One per AZ |
| `standalone_data_subnet_cidrs` | yes | One per AZ |

### blue_green mode

| Name | Required | Default | Description |
|---|---|---|---|
| `green_enabled` | no | `false` | Set `true` to provision the green VPC during an upgrade |
| `eks_blue_cluster_name` | no | `""` | Blue EKS cluster name for subnet tags |
| `eks_green_cluster_name` | no | `""` | Green EKS cluster name for subnet tags |
| `blue_vpc_cidr` | yes | — | Blue VPC CIDR |
| `blue_public_subnet_cidrs` | yes | — | One per AZ |
| `blue_private_subnet_cidrs` | yes | — | One per AZ |
| `green_vpc_cidr` | if green_enabled | — | Green VPC CIDR |
| `green_public_subnet_cidrs` | if green_enabled | — | One per AZ |
| `green_private_subnet_cidrs` | if green_enabled | — | One per AZ |
| `data_vpc_cidr` | yes | — | Shared data VPC CIDR (Aurora/Valkey) |
| `data_subnet_cidrs` | yes | — | One per AZ |

### Tags

| Name | Default | Description |
|---|---|---|
| `team` | `infra-core` | Team tag |
| `cost_center` | `infra-2026-q1` | Cost center tag |
| `common_tags` | `{Project, ManagedBy, Repository}` | Merged into all resources |
| `tags` | `{}` | Additional tags |

---

## Outputs

### standalone

| Output | Description |
|---|---|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Public subnet IDs — pass to EKS module |
| `private_subnet_ids` | Private subnet IDs — pass to EKS module |
| `data_subnet_ids` | Data subnet IDs — pass to Aurora/Valkey modules |
| `nat_gateway_ids` | NAT Gateway IDs |
| `private_route_table_ids` | Private route table IDs |

### blue_green

| Output | Description |
|---|---|
| `blue_vpc_id` | Blue VPC ID |
| `blue_public_subnet_ids` | Blue public subnet IDs |
| `blue_private_subnet_ids` | Blue private subnet IDs — pass to EKS blue cluster |
| `blue_data_peering_id` | Blue ↔ Data peering connection ID |
| `green_vpc_id` | Green VPC ID (`null` when `green_enabled = false`) |
| `green_public_subnet_ids` | Green public subnet IDs |
| `green_private_subnet_ids` | Green private subnet IDs — pass to EKS green cluster |
| `green_data_peering_id` | Green ↔ Data peering ID (`null` when `green_enabled = false`) |
| `data_vpc_id` | Shared data VPC ID — pass to Aurora/Valkey modules |
| `data_vpc_subnet_ids` | Shared data subnet IDs |

All outputs are `null` or `[]` when not applicable to the active mode.

---

## AZ count guide

Pass all available AZs in `availability_zones` — the module slices to `az_count` automatically. Subnets must be ordered by AZ (standard output from this module's callers).

| `az_count` | Use for | Trade-off |
|---|---|---|
| `2` | Dev, staging | Lower NAT GW + cross-AZ data transfer cost; one AZ failure affects 50% of nodes |
| `3` | Production (default) | Balanced cost vs resilience; one AZ failure affects ~33% |
| `4` | Regulated / financial | Highest resilience; highest cross-AZ transfer cost |

Must match `az_count` in `aj-tf-module-eks` — the EKS module slices the subnet lists to the same value.

---

## Cost reference

NAT Gateways are the main cost driver: **~$32/month each**.

| Config | NAT GWs | Est. monthly |
|---|---|---|
| standalone, az_count=2 | 2 | ~$64 |
| standalone, az_count=3 | 3 | ~$96 |
| blue_green (blue only), az_count=2 | 4 (2 blue + 2 data) | ~$0 (data VPC has no NGW) → ~$64 |
| blue_green (blue only), az_count=3 | 3 blue NAT GWs | ~$96 |
| blue_green (blue + green active), az_count=3 | 6 | ~$192 |

The green VPC only incurs cost during an active upgrade window. Destroy it immediately after cutover is validated.

---

## Provider pins

| Tool | Version |
|---|---|
| Terraform | `= 1.7.5` |
| AWS provider | `= 5.100.0` |

Exact pins — no ranges. Upgrade deliberately: bump the pin, run `terraform init -upgrade`, validate, commit.
