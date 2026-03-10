# Operations Guide

Day-to-day reference for managing the CodeAftermath Lighthouse CI server
running on AWS ECS Fargate.

---

## Table of Contents

1. [Checking Server Health](#1-checking-server-health)
2. [Redeploying the Server](#2-redeploying-the-server)
3. [Scaling the Service](#3-scaling-the-service)
4. [Viewing Logs](#4-viewing-logs)
5. [Managing Projects and Tokens](#5-managing-projects-and-tokens)
6. [Rotating the Admin API Key](#6-rotating-the-admin-api-key)
7. [Backing Up the Database](#7-backing-up-the-database)
8. [Updating the Lighthouse Server Version](#8-updating-the-lighthouse-server-version)
9. [Destroying the Infrastructure](#9-destroying-the-infrastructure)

---

## 1. Checking Server Health

### Via the ALB health check URL

```bash
SERVER_URL=$(cd terraform && terraform output -raw lighthouse_server_url)
curl -s "$SERVER_URL/v1/version"
# {"version":"0.13.x"}
```

### Via AWS CLI

```bash
# Check the ECS service status
aws ecs describe-services \
  --cluster codeaftermath-lighthouse \
  --services codeaftermath-lighthouse \
  --region us-east-1 \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}'

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(cd terraform && terraform output -raw alb_dns_name) \
  --region us-east-1
```

### Via the LHCI CLI

```bash
lhci healthcheck \
  --fatal \
  --serverBaseUrl "$SERVER_URL"
```

---

## 2. Redeploying the Server

The deploy workflow (`deploy.yml`) runs automatically on every push to `main`.
To trigger a manual redeploy:

1. Go to **Actions → Deploy Lighthouse Server** in this repository.
2. Click **Run workflow → Run workflow**.

Or, from the command line:

```bash
gh workflow run deploy.yml --ref main
```

### Force a fresh ECS deployment (without a code change)

```bash
aws ecs update-service \
  --cluster codeaftermath-lighthouse \
  --service codeaftermath-lighthouse \
  --force-new-deployment \
  --region us-east-1
```

---

## 3. Scaling the Service

The ECS service runs a single task by default. Change `desired_count` in
`terraform/ecs.tf` to increase capacity:

```hcl
resource "aws_ecs_service" "lighthouse" {
  desired_count = 2   # was 1
  # ...
}
```

Then apply:

```bash
cd terraform
terraform apply -var="lhci_admin_api_key=<key>"
```

> **Note:** The server stores data in a shared EFS volume so multiple tasks
> can safely run concurrently.

To adjust CPU/memory, change the `container_cpu` and `container_memory`
variables:

```bash
terraform apply \
  -var="container_cpu=512" \
  -var="container_memory=1024" \
  -var="lhci_admin_api_key=<key>"
```

---

## 4. Viewing Logs

### Via the AWS Console

Navigate to **CloudWatch → Log groups → `/ecs/codeaftermath-lighthouse`**.

### Via the AWS CLI

```bash
# Stream the most recent logs
aws logs tail /ecs/codeaftermath-lighthouse \
  --follow \
  --region us-east-1

# Filter for errors
aws logs filter-log-events \
  --log-group-name /ecs/codeaftermath-lighthouse \
  --filter-pattern "ERROR" \
  --region us-east-1 \
  --query 'events[*].message' \
  --output text
```

### Fetch logs for a specific time window

```bash
aws logs filter-log-events \
  --log-group-name /ecs/codeaftermath-lighthouse \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --end-time $(date +%s)000 \
  --region us-east-1
```

---

## 5. Managing Projects and Tokens

All project management uses the LHCI admin API. Set `SERVER_URL` and
`ADMIN_KEY` before running these commands.

```bash
SERVER_URL="http://<alb-dns-name>"
ADMIN_KEY="<lhci_admin_api_key>"
```

### List all projects

```bash
curl -s "$SERVER_URL/v1/projects" \
  -H "Authorization: Bearer $ADMIN_KEY" | jq '.[].name'
```

### Create a new project

```bash
curl -s -X POST "$SERVER_URL/v1/projects" \
  -H "Authorization: Bearer $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name":        "my-project",
    "externalUrl": "https://www.example.com",
    "slug":        "my-project"
  }' | jq '{name,token,adminToken}'
```

### Get details for a specific project

```bash
PROJECT_ID="<project-id>"

curl -s "$SERVER_URL/v1/projects/$PROJECT_ID" \
  -H "Authorization: Bearer $ADMIN_KEY" | jq .
```

### Update a project

```bash
curl -s -X PUT "$SERVER_URL/v1/projects/$PROJECT_ID" \
  -H "Authorization: Bearer $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name":        "my-project-renamed",
    "externalUrl": "https://www.example.com"
  }' | jq .
```

### Delete a project

```bash
curl -s -X DELETE "$SERVER_URL/v1/projects/$PROJECT_ID" \
  -H "Authorization: Bearer $ADMIN_KEY"
```

### Regenerate a build token

```bash
curl -s -X POST "$SERVER_URL/v1/projects/$PROJECT_ID/token" \
  -H "Authorization: Bearer $ADMIN_KEY" | jq .token
```

### List builds for a project

```bash
curl -s "$SERVER_URL/v1/projects/$PROJECT_ID/builds" \
  -H "Authorization: Bearer $ADMIN_KEY" \
  | jq '.[] | {id, branch, commitMessage, runAt}'
```

### Delete a specific build

```bash
BUILD_ID="<build-id>"

curl -s -X DELETE "$SERVER_URL/v1/projects/$PROJECT_ID/builds/$BUILD_ID" \
  -H "Authorization: Bearer $ADMIN_KEY"
```

---

## 6. Rotating the Admin API Key

1. Generate a new key (must be 20+ characters):

   ```bash
   openssl rand -hex 20
   ```

2. Update the SSM parameter:

   ```bash
   aws ssm put-parameter \
     --name "/codeaftermath-lighthouse/lhci_admin_api_key" \
     --value "<new-key>" \
     --type SecureString \
     --overwrite \
     --region us-east-1
   ```

3. Update the GitHub Actions secret `LHCI_ADMIN_API_KEY` in this repository's
   settings.

4. Force a new ECS deployment so the running container picks up the new value:

   ```bash
   aws ecs update-service \
     --cluster codeaftermath-lighthouse \
     --service codeaftermath-lighthouse \
     --force-new-deployment \
     --region us-east-1
   ```

---

## 7. Backing Up the Database

The SQLite database lives on an EFS file system. To take a point-in-time
backup, create an EFS backup using AWS Backup (recommended) or copy the
database file via a temporary EC2/ECS task.

### Enable automatic backups via AWS Backup

```bash
aws backup create-backup-plan \
  --backup-plan '{
    "BackupPlanName": "codeaftermath-lighthouse-daily",
    "Rules": [{
      "RuleName": "daily-backup",
      "TargetBackupVaultName": "Default",
      "ScheduleExpression": "cron(0 2 * * ? *)",
      "Lifecycle": {"DeleteAfterDays": 30}
    }]
  }' \
  --region us-east-1
```

### Manual backup using an ECS task

```bash
# Run a one-off task that copies the SQLite file to S3
aws ecs run-task \
  --cluster codeaftermath-lighthouse \
  --task-definition codeaftermath-lighthouse \
  --launch-type FARGATE \
  --overrides '{
    "containerOverrides": [{
      "name": "lighthouse-server",
      "command": ["sh", "-c",
        "apk add --no-cache aws-cli && aws s3 cp /data/lhci.db s3://<bucket>/backups/lhci-$(date +%Y%m%d).db"
      ]
    }]
  }' \
  --network-configuration "awsvpcConfiguration={subnets=[<subnet-id>],assignPublicIp=ENABLED}" \
  --region us-east-1
```

---

## 8. Updating the Lighthouse Server Version

1. Update the `@lhci/server` version in the `Dockerfile`:

   ```dockerfile
   RUN npm install -g @lhci/server@<new-version> && \
   ```

2. Commit the change and push to `main`. The deploy workflow will build a
   new image, push it to ECR, and update the ECS service automatically.

To check available versions:

```bash
npm view @lhci/server versions --json | jq -r '.[-5:]'
```

---

## 9. Destroying the Infrastructure

> ⚠️ This permanently deletes all data. Make a backup first.

```bash
cd terraform

terraform destroy -var="lhci_admin_api_key=<key>"
```

The bootstrap resource (S3 state bucket) is protected
by `lifecycle { prevent_destroy = true }`. To remove it, first remove that
lifecycle block in `terraform/bootstrap/main.tf`, then:

```bash
cd terraform/bootstrap
terraform destroy
```
