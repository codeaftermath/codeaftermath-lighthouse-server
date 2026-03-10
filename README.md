# codeaftermath-lighthouse-server

Private [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci) server
for CodeAftermath projects. Infrastructure is provisioned on **AWS ECS Fargate**
using **Terraform**, the server runs in **Docker**, and deployments are
automated via **GitHub Actions**.

---

## Table of Contents

- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [First-Time Setup](#first-time-setup)
  - [1 — Bootstrap the Terraform state backend](#1--bootstrap-the-terraform-state-backend)
  - [2 — Configure GitHub repository secrets](#2--configure-github-repository-secrets)
  - [3 — Push to main](#3--push-to-main)
- [Local Development](#local-development)
- [Terraform Reference](#terraform-reference)
  - [Variables](#variables)
  - [Outputs](#outputs)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Connecting a New Project](#connecting-a-new-project)
- [Further Reading](#further-reading)

---

## Architecture

```
GitHub Actions (push to main)
        │
        ├─ 1. build Docker image
        ├─ 2. push to Amazon ECR
        └─ 3. terraform apply
                    │
                    ▼
       ┌────────────────────────────────────────┐
       │  AWS VPC (us-east-1)                   │
       │                                        │
       │  ┌──────────────────────────────────┐  │
       │  │  Application Load Balancer       │  │
       │  │  (port 80, public)               │  │
       │  └───────────────┬──────────────────┘  │
       │                  │ HTTP → 9001          │
       │  ┌───────────────▼──────────────────┐  │
       │  │  ECS Fargate task                │  │
       │  │  lhci-server container (9001)    │  │
       │  │         │ EFS mount              │  │
       │  │    /data/lhci.db (SQLite)        │  │
       │  └──────────────────────────────────┘  │
       │                                        │
       │  ECR  │  SSM Parameter Store           │
       │  CloudWatch Logs (/ecs/...)            │
       └────────────────────────────────────────┘
```

| AWS Resource | Purpose |
|---|---|
| **ECR** | Stores versioned `lhci-server` Docker images |
| **ECS Fargate** | Runs the Lighthouse CI server container (serverless) |
| **EFS** | Encrypted persistent volume for the SQLite database |
| **ALB** | Public HTTP entry point; routes traffic to ECS |
| **SSM Parameter Store** | Securely stores the admin API key |
| **CloudWatch Logs** | Container stdout/stderr retained for 30 days |
| **IAM** | Least-privilege execution and task roles |

---

## Repository Layout

```
.
├── Dockerfile                        # lhci-server container image
├── docker-compose.yml                # Local development
├── .github/
│   └── workflows/
│       ├── deploy.yml                # CI/CD: build → ECR → terraform apply
│       └── terraform-plan.yml        # PR preview: terraform plan as PR comment
├── terraform/
│   ├── backend.tf                    # S3 remote state
│   ├── versions.tf                   # Terraform + provider version pins
│   ├── variables.tf                  # Input variables
│   ├── outputs.tf                    # Outputs (server URL, ECR URL, …)
│   ├── networking.tf                 # VPC, subnets, IGW, route tables
│   ├── security_groups.tf            # ALB / ECS / EFS security groups
│   ├── ecr.tf                        # ECR repository + lifecycle policy
│   ├── efs.tf                        # EFS file system, mount targets, access point
│   ├── ssm.tf                        # SSM SecureString for admin API key
│   ├── iam.tf                        # ECS execution + task IAM roles
│   ├── alb.tf                        # ALB, target group, HTTP listener
│   ├── ecs.tf                        # ECS cluster, task definition, service
│   ├── terraform.tfvars.example      # Example variable values (copy + fill in)
│   └── bootstrap/
│       └── main.tf                   # One-time S3 + DynamoDB backend setup
└── docs/
    ├── onboarding.md                 # Connect a new project to the server
    └── operations.md                 # Day-to-day server management
```

---

## Prerequisites

| Tool | Version |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.5 |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 |
| [Docker](https://docs.docker.com/get-docker/) | any recent |

An AWS IAM user or role with permissions to manage: ECS, ECR, VPC, EFS, ALB,
IAM, SSM, CloudWatch, S3, DynamoDB.

---

## First-Time Setup

### 1 — Bootstrap the Terraform state backend

The main Terraform configuration stores its state in an S3 bucket with
DynamoDB state-locking. Run the bootstrap **once** before the main config:

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

This creates:

- `codeaftermath-terraform-state` S3 bucket (versioned, encrypted)
- `codeaftermath-terraform-locks` DynamoDB table

### 2 — Configure GitHub repository secrets

Navigate to **Settings → Secrets and variables → Actions** in this repository
and add the following:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key ID |
| `AWS_SECRET_ACCESS_KEY` | IAM secret access key |
| `LHCI_ADMIN_API_KEY` | Admin API key for the LHCI server (generate with `openssl rand -hex 20`) |

### 3 — Push to `main`

Once the bootstrap resources exist and secrets are configured, merge or push
to the `main` branch. The [deploy workflow](.github/workflows/deploy.yml) will:

1. Create the ECR repository (Terraform targeted apply).
2. Build the Docker image and push it to ECR.
3. Run `terraform apply` to provision all remaining AWS resources.
4. Print the ALB server URL as a workflow output.

The server will be available at the URL printed by the workflow. You can also
retrieve it at any time:

```bash
cd terraform
terraform output lighthouse_server_url
```

---

## Local Development

```bash
# Build and start the server on http://localhost:9001
docker compose up --build

# Run in the background
docker compose up -d --build

# Follow logs
docker compose logs -f

# Stop and remove containers (data volume is preserved)
docker compose down
```

Data is persisted between restarts in the `lhci_data` Docker volume.

To reset local data:

```bash
docker compose down -v    # removes the volume
```

---

## Terraform Reference

```bash
cd terraform

# Initialise (once per environment or after provider changes)
terraform init

# Preview changes
terraform plan -var="lhci_admin_api_key=<key>"

# Apply changes
terraform apply -var="lhci_admin_api_key=<key>"

# Destroy all resources (⚠️ irreversible — back up data first)
terraform destroy -var="lhci_admin_api_key=<key>"
```

Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` for
a more ergonomic workflow. The file is excluded from version control by
`.gitignore`.

### Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `environment` | `production` | Environment tag applied to all resources |
| `project_name` | `codeaftermath-lighthouse` | Name prefix for all resources |
| `container_image` | `patrickhulce/lhci-server:0.13.0` | Docker image URI (overridden by deploy workflow) |
| `container_cpu` | `256` | ECS task CPU units (256 = 0.25 vCPU) |
| `container_memory` | `512` | ECS task memory in MiB |
| `lhci_admin_api_key` | *(required)* | Admin API key stored in SSM Parameter Store |

### Outputs

| Output | Description |
|---|---|
| `lighthouse_server_url` | Public URL of the Lighthouse CI server |
| `ecr_repository_url` | ECR repository URL (used by the deploy workflow) |
| `ecs_cluster_name` | Name of the ECS cluster |
| `ecs_service_name` | Name of the ECS service |
| `alb_dns_name` | Raw ALB DNS name |

---

## GitHub Actions Workflows

| Workflow | Trigger | Description |
|---|---|---|
| [`deploy.yml`](.github/workflows/deploy.yml) | Push to `main` or manual dispatch | Builds Docker image, pushes to ECR, runs `terraform apply` |
| [`terraform-plan.yml`](.github/workflows/terraform-plan.yml) | Pull request to `main` (terraform paths) | Runs `terraform validate` + `terraform plan`; posts the plan as a PR comment |

### Required GitHub repository configuration

| Type | Name | Description |
|---|---|---|
| Secret | `AWS_ACCESS_KEY_ID` | IAM access key |
| Secret | `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| Secret | `LHCI_ADMIN_API_KEY` | LHCI admin API key |
| Environment | `production` | Gates the `deploy` job in `deploy.yml` (optional but recommended) |

---

## Connecting a New Project

See **[docs/onboarding.md](docs/onboarding.md)** for the full step-by-step
guide, including:

- Installing the `lhci` CLI
- Registering a project and obtaining a build token
- `lighthouserc.js` configuration examples
- Running `lhci collect`, `lhci assert`, and `lhci upload`
- A ready-to-use GitHub Actions workflow for automated audits

---

## Further Reading

- [docs/operations.md](docs/operations.md) — Server management, log access,
  key rotation, scaling, and backup procedures
- [Lighthouse CI documentation](https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/getting-started.md)
- [LHCI server configuration reference](https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/server.md)
- [Terraform AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
