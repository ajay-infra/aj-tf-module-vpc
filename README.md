# tf-module-vpc

Terraform module for AWS VPC with production-grade 3 AZ high-availability design.

## 📋 Overview

This module provisions a complete VPC infrastructure optimized for Kubernetes (EKS) and data services:

- **3 Availability Zones** (AZ) for fault tolerance and etcd quorum
- **Public Subnets** for NAT Gateways and ALB (load balancer)
- **Private Subnets** for EKS cluster nodes
- **Data Subnets** for Aurora (pgvector) and Redis (isolated, no internet)
- **Network egress** via NAT Gateways (1 per AZ, ~$32/month each)
- **DNS** enabled for in-cluster and external resolution

---
This VPC gives a classic 3‑tier, internet-enabled network: public entry, private app (blue/green), and private data, all wired by route tables, IGW, and NAT.
Big picture flow
	•	Internet → ALB in public subnets → pods in blue/green private subnets → data subnets (DB/cache).
	•	Outbound from pods goes: private subnet → NAT in public subnet → Internet Gateway → internet.
Component connections
	1.	VPC + Subnets
	•	One VPC  10.100.0.0/16  contains 3 AZs with four subnet types per AZ: public, private-blue, private-green, data.
	•	All subnets can talk to each other via the implicit  local  route in the VPC; route tables then decide what can reach outside.
	2.	Internet-facing path (ingress & egress)
	•	Internet Gateway attaches to the VPC ( aws_internet_gateway.main ).
	•	Public route table has a route  0.0.0.0/0 → igw-id , is associated to all public subnets.
	•	Result:
	•	ALB, Bastion, NAT sit in public subnets and get public IPs.
	•	Inbound: internet → IGW → ALB in public subnet.
	•	Outbound: ALB/bastion can reach internet directly via IGW.
	3.	Private blue/green → internet (egress only)
	•	For each AZ:
	•	A NAT Gateway sits in the corresponding public subnet and has an EIP.
	•	A private_blue route table (one per AZ) has  0.0.0.0/0 → nat-gw-in-same-az  and is associated only with blue subnets in that AZ.
	•	Same pattern for green if/when you add separate route tables.
	•	Result:
	•	Pods/EC2 in blue/green subnets have no public IPs, cannot be reached from the internet.
	•	They can initiate outbound connections (e.g., to pull images, talk to external APIs) via NAT → IGW, but responses come back through NAT only.
	4.	Data subnets (isolated)
	•	Data route table is associated to all data subnets and has only the default  local  route (no  0.0.0.0/0 ).
	•	Result:
	•	RDS/Redis/etc. can be reached only from inside the VPC (e.g., blue/green subnets, maybe VPN/Direct Connect if you add later).
	•	They cannot reach the internet unless you explicitly add NAT routes or VPC endpoints (which you haven’t, yet).
	5.	Blue/Green semantics
	•	Blue and green subnets are structurally identical; the only differences are:
	•	Their CIDRs.
	•	Their  ClusterEnv  and  Type  tags.
	•	EKS blue cluster uses blue subnets, EKS green cluster uses green subnets; both:
	•	Receive traffic via the same/shared ALB (or different ones) from public subnets.
	•	Reach outside via their AZ’s NAT.
	•	During a blue→green cutover, you swap target groups/DNS; network topology stays exactly the same.
One simple mental diagram
For one AZ (repeated 3x):
	•	 public-1  (10.100.0.0/27): IGW route; contains NAT, ALB.
	•	 private-blue-1  (10.100.0.128/25): route  0.0.0.0/0 → nat-1 .
	•	 private-green-1  (10.100.3.0/25): route  0.0.0.0/0 → nat-1 .
	•	 data-1  (10.100.6.0/26): no  0.0.0.0/0  route → internal-only.

## Network Flow

**Inbound**: Internet → IGW → Public Subnets → ALB → Blue/Green EKS Pods
**Outbound**: EKS Pods → NAT (per AZ) → IGW → Internet  
**Internal**: EKS ↔ Data Subnets (RDS/Redis/ElastiCache)
**Data**: Internal-only (no internet route)

[Future: VPN/TGW/VPC Endpoints]