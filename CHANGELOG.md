# Changelog

All notable changes to this module are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- `CLAUDE.md` generalized "Provisions AWS VPC networking for the AI Search Engine platform" to describe the module itself (reusable infra tooling, not tied to one product's name) — "ai-search" is still the real, currently-deployed product per `aj-infra-release`'s actual tfvars (see below), so this was about scoping the module's own self-description correctly, not correcting stale info.
- All three `envs/*.tfvars` files had `vpc_name`/`eks_blue_cluster_name` set to `"ai-platform-<env>"` — this didn't match anything. Checked `aj-infra-release/envs/workload/blue-green/*/vpc.tfvars` (the actual pipeline repo that drives real deployments) and found the real, live convention is `"ai-search-<env>"` / `"ai-search-<env>-blue"` — consistent across dev/staging/prod/prod-regulated/standalone there. Updated this module's examples to match.
- `CLAUDE.md`'s CIDR table was a single generic Blue/Green/Data set presented as "the defaults," when each environment actually has its own range. Relabeled as a dev example and pointed at `README.md`'s authoritative per-environment table instead of duplicating one that can drift.
- `CLAUDE.md` / `README.md` Terraform version corrected `1.7.5` → `1.10.5` to match `providers.tf`'s actual pin.
- `CLAUDE.md` / `README.md` backend-config examples updated from DynamoDB locking to S3 native locking (`use_lockfile=true`), matching the platform-wide Terraform 1.10.5 migration (`aj-infra-context/CLAUDE.md`, 2026-05-18).
- `CLAUDE.md`'s "Running Locally" section pointed at `My-Infra/ make shell` — repo since renamed to `aj-infra-context`, and that Podman workflow currently has no `Makefile`/`Dockerfile` (documented gap, not fixed here — see that repo's `local-testing/README.md`). Updated the reference and noted the gap inline instead of silently carrying forward instructions that don't work.
- `CLAUDE.md`'s "Known TODOs" — checked off two that were already done but never marked: `envs/dev.tfvars`/`envs/staging.tfvars` exist, and `.github/workflows/ci.yml` exists. Left the two still-open ones (VPC flow logs, Transit Gateway support) — verified no flow-log resources exist anywhere in the module.

## [v1.0.0] - 2026-03-29

Provider version pins, `az_count` expanded to support 2/3/4 AZs, repo name fixed in tags, `CLAUDE.md` added. Note: the current `README.md` (full mode/topology/CIDR documentation) landed in a later, unreleased `docs/readme-rewrite` merge (2026-05-18) — not yet part of a tagged release.

## [vpc-01] - 2026-03-23

Initial standalone and blue/green VPC implementation.
