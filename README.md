# codeaftermath-lighthouse-server

Private [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci) server for CodeAftermath projects, deployed on AWS ECS Fargate with Docker and provisioned via Terraform.

---

## Architecture

```
GitHub Actions
     │
     ├─ build image → ECR
     └─ terraform apply
                │
                ▼
         ┌──────────────────────────────────────┐
         │  AWS (us-east-1)                     │
         │                                      │
         │  ALB (port 80)                       │
         │   └─ ECS Fargate (lhci-server:9001)  │
         │         └─ EFS (SQLite /data)        │
         │                                      │
         │  ECR  │  CloudWatch Logs             │
         └──────────────────────────────────────┘
```

| Resource | Purpose |
|---|---|
| **ECR** | Stores the `lhci-server` Docker image |
| **ECS Fargate** | Runs the Lighthouse CI server container |
| **EFS** | Persistent volume for the SQLite database |
| **ALB** | Public HTTP entry point for the server |
| **CloudWatch Logs** | Container stdout/stderr retained for 30 days |
| **IAM** | Least-privilege roles for ECS execution and task |

---

## Prerequisites

- AWS account with credentials that have sufficient permissions
- Terraform ≥ 1.5
- Docker (for local development)

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key with permissions to manage ECS, ECR, VPC, EFS, IAM, ALB |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret key |
| `LHCI_ADMIN_API_KEY` | Admin API key for the LHCI server (20+ character string) |

---

## First-Time Setup

### 1 — Bootstrap the Terraform state backend

The Terraform configuration uses an S3 bucket and DynamoDB table for remote state. Run the bootstrap **once** before the main configuration:

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

### 2 — Push to `main`

Once the bootstrap resources exist, merge or push to the `main` branch. The [deploy workflow](.github/workflows/deploy.yml) will:

1. Build the Docker image and push it to ECR.
2. Run `terraform apply` to provision all remaining AWS resources.
3. Print the server URL as a workflow output.

---

## Local Development

```bash
# Start the server locally on http://localhost:9001
docker compose up --build
```

Data is persisted in the `lhci_data` Docker volume between restarts.

---

## Terraform

```bash
cd terraform

# Initialise the backend (after bootstrap)
terraform init

# Preview changes
terraform plan -var="lhci_admin_api_key=<key>"

# Apply changes
terraform apply -var="lhci_admin_api_key=<key>"
```

Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and fill in values for a more ergonomic workflow (the file is git-ignored).

### Key Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `environment` | `production` | Environment tag |
| `project_name` | `codeaftermath-lighthouse` | Prefix for all resource names |
| `container_image` | `patrickhulce/lhci-server:0.13.0` | Docker image URI |
| `container_cpu` | `256` | ECS task CPU units |
| `container_memory` | `512` | ECS task memory (MiB) |
| `lhci_admin_api_key` | *(required)* | LHCI admin API key |

---

## Connecting Projects

Once the server is running, configure your project's `lighthouserc.js` (or `.lighthouserc.json`) to upload results:

```js
module.exports = {
  ci: {
    upload: {
      target: 'lhci',
      serverBaseUrl: 'http://<alb-dns-name>',
      token: '<project-build-token>',
    },
  },
};
```

Obtain a build token by creating a new project via the LHCI admin API:

```bash
curl -X POST http://<alb-dns-name>/v1/projects \
  -H "Authorization: Bearer <lhci_admin_api_key>" \
  -H "Content-Type: application/json" \
  -d '{"name":"my-project","externalUrl":"https://example.com","slug":"my-project"}'
```

---

## GitHub Actions Workflows

| Workflow | Trigger | Description |
|---|---|---|
| [`deploy.yml`](.github/workflows/deploy.yml) | Push to `main` or manual | Builds image, pushes to ECR, runs `terraform apply` |
| [`terraform-plan.yml`](.github/workflows/terraform-plan.yml) | Pull request to `main` | Runs `terraform plan` and posts results as a PR comment |
