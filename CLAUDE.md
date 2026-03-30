# CLAUDE.md — aj-tf-module-vpc

> Local context file for Claude Code. Not pushed to GitHub.

---

## What This Module Does

Provisions AWS VPC networking for the AI Search Engine platform (L2 in the roadmap).

Two modes controlled by `eks_deployment_mode`:

| Mode | VPCs | Use Case |
|---|---|---|
| `standalone` | 1 VPC (configurable CIDR) with public + private + data subnets | Simple single-cluster setup, in-place upgrades only |
| `blue_green` | Blue VPC + Data VPC (always) + optional Green VPC | Zero-downtime EKS cluster swaps |

### Blue/Green CIDR Layout (defaults)

| VPC | CIDR | Purpose |
|---|---|---|
| Blue | 10.100.0.0/16 | Active EKS cluster |
| Green | 10.101.0.0/16 | Standby cluster (provisioned when `green_enabled = true`) |
| Data | 10.102.0.0/16 | Shared RDS/Redis — no internet gateway |

### VPC Peering

- **Blue ↔ Data**: always present in `blue_green` mode
- **Green ↔ Data**: only when `green_enabled = true`
- Blue and Green never peer directly — traffic flows through the data VPC only

---

## Submodules

| Module | Purpose |
|---|---|
| `modules/vpc-standalone` | Single VPC with public, private, and data subnets |
| `modules/vpc-cluster` | Reusable cluster VPC (blue or green) with public + private subnets + NAT GW |
| `modules/vpc-data` | Data-tier VPC — private subnets only, no IGW |
| `modules/vpc-peering` | Wires a peering connection + route table entries between two VPCs |

---

## Files

| File | Purpose |
|---|---|
| `providers.tf` | AWS provider pinned to `= 5.100.0`, Terraform `= 1.7.5` |
| `variables.tf` | All inputs — mode, CIDRs, AZ config, tags |
| `locals.tf` | `name_prefix`, `azs` slice, `is_standalone`/`is_blue_green` booleans |
| `main.tf` | Module instantiation with `count`-based conditional logic |
| `outputs.tf` | VPC IDs, subnet IDs, NAT GW IDs, peering IDs per mode |

---

## Key Design Decisions

- **`count` not `for_each`** — modes are mutually exclusive, so `count = local.is_standalone ? 1 : 0` is simpler than a map. Switching modes requires a full destroy/recreate.
- **`green_enabled` flag** — Green VPC is not provisioned by default (cost saving). Set to `true` only during an upgrade window; set back to `false` once traffic is cut over and blue is decommissioned.
- **Data VPC has no IGW** — intentional. RDS/Redis should never be directly reachable from the internet. Cluster VPCs reach it only through the VPC peering connection.
- **`azs` slice in locals** — `slice(var.availability_zones, 0, var.az_count)` so you can pass all 4 AZs but only activate 2 or 3 via `az_count`. Consistent with the same pattern in `aj-tf-module-eks`.
- **Subnet CIDRs are caller-supplied** — the module does not calculate CIDRs with `cidrsubnet()`. The caller (envs/*.tfvars) owns the CIDR plan. This avoids surprises when AZ count changes.

---

## AZ Count Guide

| `az_count` | Tier | Notes |
|---|---|---|
| 2 | Dev / Staging | Lower NAT GW + cross-AZ data-transfer costs; relaxed SLO |
| 3 | Production | Standard HA — default |
| 4 | Regulated Prod | Financial / healthcare; strict 99.99% SLA |

> Must match `az_count` in `aj-tf-module-eks` — the EKS module slices subnet lists by this value.

---

## Running Locally

```bash
# From My-Infra/
make shell

# Inside container
cd /workspaces/aj-tf-module-vpc
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="key=dev/vpc/terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform plan -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```

---

## Apply Order

This module is **Stage 1** of the platform apply order:

```
Stage 1a: aj-tf-module-vpc  ← this repo
  → outputs: VPC IDs, subnet IDs (passed to EKS module)

Stage 1b: aj-tf-module-eks
  → reads VPC outputs via input variables (not remote state)
  → outputs: cluster endpoint, node group ARNs, cilium_helm_values

Stage 2: infra-platform
  → reads EKS state via data.terraform_remote_state.eks
  → installs Cilium + add-ons via Helm
```

---

## Known TODOs

- [ ] Add `envs/dev.tfvars` and `envs/staging.tfvars` example files
- [ ] Add `.github/workflows/ci.yml` (fmt + validate + plan matrix)
- [ ] Flow Logs — VPC flow logs to S3/CloudWatch not yet wired
- [ ] Transit Gateway support for multi-account setups (future)
