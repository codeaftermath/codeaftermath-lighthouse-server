# Manual Setup Checklist

Everything in this repository that **cannot** be done automatically by
Terraform or GitHub Actions and requires a human to complete.

Work through the sections in order the first time. Per-project tasks are
repeated for every new codebase that connects to the server.

---

## Part 1 — One-Time Server Setup

These steps are performed once, before the server is deployed for the first time.

### 1.1 — AWS account and IAM credentials

- [ ] Log in to (or create) an AWS account.
- [ ] Create a dedicated IAM user (e.g. `github-actions-lighthouse`) that the
  GitHub Actions workflows will use to run Terraform.

The IAM user needs permissions across nine AWS services. Two options are shown
below — choose the one that fits your security requirements.

---

#### Option A — AWS managed policies (quick start)

Attach the following ten AWS-managed policies directly to the IAM user. Each
policy is maintained by AWS, grants full access to its service, and is the
fastest way to get everything working.

| Policy name (attach in IAM console) | Services covered |
|---|---|
| `AmazonEC2FullAccess` | VPC, subnets, security groups, internet gateway, route tables |
| `ElasticLoadBalancingFullAccess` | Application Load Balancer, target groups, listeners |
| `AmazonECS_FullAccess` | ECS cluster, task definitions, service |
| `AmazonElasticFileSystemFullAccess` | EFS file system, mount targets, access points |
| `AmazonSSMFullAccess` | SSM Parameter Store (admin API key) |
| `IAMFullAccess` | IAM roles and policies created for ECS execution/task roles |
| `CloudWatchLogsFullAccess` | CloudWatch log group for ECS container output |
| `AmazonS3FullAccess` | S3 bucket for Terraform remote state and state locking |

> ⚠️ These managed policies are intentionally broad. They are fine for a
> personal or team project but should be replaced with a least-privilege
> policy (Option B) before exposing the infrastructure to untrusted code.

---

#### Option B — Least-privilege inline policy (recommended for production)

The file [`terraform/iam-policy-github-actions.json`](../terraform/iam-policy-github-actions.json)
contains a single JSON policy with exactly the IAM actions required to run
`terraform apply` (bootstrap + main). No service has more access than it needs.

**To attach it:**

```bash
# 1. Create the policy in your AWS account
aws iam create-policy \
  --policy-name codeaftermath-lighthouse-github-actions \
  --policy-document file://terraform/iam-policy-github-actions.json \
  --region us-west-1

# 2. Attach it to the IAM user (replace <account-id>)
aws iam attach-user-policy \
  --user-name github-actions-lighthouse \
  --policy-arn arn:aws:iam::<account-id>:policy/codeaftermath-lighthouse-github-actions
```

Or attach it in the IAM console:
1. Go to **IAM → Users → github-actions-lighthouse → Add permissions**.
2. Choose **Attach policies directly → Create policy**.
3. Switch to the **JSON** tab, paste the contents of
   `terraform/iam-policy-github-actions.json`, and save.
4. Attach the new policy to the user.

**Key security decisions made in the policy:**

| Decision | Reason |
|---|---|
| `iam:PassRole` is restricted to `ecs-tasks.amazonaws.com` via a `Condition` | Prevents the key from being used to escalate privileges via other services |
| All other IAM actions are scoped to create/manage only roles and role policies | Not full `IAMFullAccess` — cannot create users, groups, or access keys |
| `ec2:Describe*` and similar read-only actions require `"Resource": "*"` | AWS does not support resource-level restrictions on Describe actions |

---

- [ ] IAM user `github-actions-lighthouse` created
- [ ] Permissions attached (Option A managed policies **or** Option B inline policy)
- [ ] Generate an **Access Key ID** and **Secret Access Key** for that user.
  Store them somewhere safe — you will add them to GitHub in step 1.4.

### 1.2 — Bootstrap the Terraform state backend (run locally, once)

The S3 bucket that holds Terraform remote state must exist before the main
configuration can be initialised. Run these commands from your local machine
with the IAM credentials above configured in your shell:

```bash
# Configure AWS CLI with the credentials from step 1.1
aws configure   # or export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY

# Bootstrap the remote state resources
cd terraform/bootstrap
terraform init
terraform apply   # type 'yes' when prompted
```

Expected result: one new resource in AWS —
- S3 bucket `codeaftermath-terraform-state` (versioned, AES-256 encrypted)

> **Only do this once.** The bucket has `prevent_destroy = true`
> and should never be re-created.

### 1.3 — Generate the LHCI admin API key

The admin key is used to create and manage projects on the server. It must be
at least 20 characters long.

```bash
openssl rand -hex 20
# Example output: a3f8c2e1d9b04f7a6e5c3d2b1a0f9e8d7c6b5a4
```

- [ ] Copy the output — you will add it to GitHub in step 1.4.

### 1.4 — Add GitHub Actions secrets

Navigate to **Settings → Secrets and variables → Actions** in this repository
and add the following **repository secrets**:

| Secret name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | The key ID from step 1.1 |
| `AWS_SECRET_ACCESS_KEY` | The secret key from step 1.1 |
| `AWS_DEFAULT_REGION` | AWS region to deploy into (e.g. `us-west-1`) |
| `LHCI_ADMIN_API_KEY` | The hex string generated in step 1.3 |

- [ ] `AWS_ACCESS_KEY_ID` added
- [ ] `AWS_SECRET_ACCESS_KEY` added
- [ ] `AWS_DEFAULT_REGION` added
- [ ] `LHCI_ADMIN_API_KEY` added

### 1.5 — Create the `production` GitHub Actions environment

The `deploy` job in `deploy.yml` is gated on an Actions environment called
`production`. Without it the deploy job will still run, but creating it lets
you add required reviewers, wait timers, or branch protection rules.

1. Go to **Settings → Environments → New environment**.
2. Name it exactly `production`.
3. Optionally configure:
   - **Required reviewers** — who must approve a production deployment.
   - **Wait timer** — minutes to pause before deploying.
   - **Deployment branches** — limit to `main` only.

- [ ] `production` environment created in GitHub

### 1.6 — Merge this PR / push to `main`

Once steps 1.1–1.5 are complete, merge this pull request (or push to `main`).
The **Deploy Lighthouse Server** GitHub Actions workflow will run automatically
and:

1. Run `terraform apply` to provision all AWS resources (VPC, ECS,
   EFS, ALB, SSM, CloudWatch, IAM).
2. Print the public ALB URL in the workflow log.

- [ ] PR merged / pushed to `main`
- [ ] **Deploy Lighthouse Server** workflow completed successfully

### 1.7 — Note the server URL

After the workflow succeeds, retrieve the public server URL — you will need it
in every project you connect.

**From the workflow log:**
Open **Actions → Deploy Lighthouse Server → (latest run) → Terraform Apply →
Print server URL**.

**From the command line:**
```bash
cd terraform
terraform output lighthouse_server_url
# http://codeaftermath-lighthouse-alb-xxxx.us-west-1.elb.amazonaws.com
```

- [ ] Server URL noted: `http://___________________________________`

### 1.8 — Verify the server is running

```bash
curl http://<alb-dns-name>/version
# {"version":"0.15.1"}
```

- [ ] Server returns a valid version response

---

## Part 2 — Per-Project Onboarding

Repeat this section for every new codebase that should upload Lighthouse
reports to the server.

### 2.1 — Register the project and get a build token

Run the interactive wizard **once** from any machine that has the `lhci` CLI
installed (`npm install -g @lhci/cli`):

```bash
lhci wizard
# When prompted, enter:
#   LHCI server URL → http://<alb-dns-name>
#   Project name    → my-project
#   External URL    → https://www.example.com
```

The wizard prints a **build token** at the end.

**Alternatively**, use `curl`:

```bash
SERVER_URL="http://<alb-dns-name>"
ADMIN_KEY="<lhci_admin_api_key>"

curl -s -X POST "$SERVER_URL/v1/projects" \
  -H "Authorization: Bearer $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name":        "my-project",
    "externalUrl": "https://www.example.com",
    "slug":        "my-project"
  }' | jq '{token}'
```

- [ ] Project registered on the LHCI server
- [ ] **Build token** copied and stored securely

> ⚠️ The build token cannot be retrieved again after creation. If you lose it,
> regenerate it with:
> ```bash
> curl -s -X POST "$SERVER_URL/v1/projects/<project-id>/token" \
>   -H "Authorization: Bearer $ADMIN_KEY" | jq .token
> ```

### 2.2 — Add the build token as a GitHub secret in the project repository

In the **project** repository (not this one):

1. Go to **Settings → Secrets and variables → Actions**.
2. Add a new **repository secret**:

| Secret name | Value |
|---|---|
| `LHCI_BUILD_TOKEN` | Token from step 2.1 |

- [ ] `LHCI_BUILD_TOKEN` secret added to the project repository

### 2.3 — Add the server URL as a GitHub variable in the project repository

1. Go to **Settings → Secrets and variables → Actions → Variables tab**.
2. Add a new **repository variable**:

| Variable name | Value |
|---|---|
| `LHCI_SERVER_URL` | `http://<alb-dns-name>` from step 1.7 |

- [ ] `LHCI_SERVER_URL` variable added to the project repository

### 2.4 — Add `lighthouserc.js` to the project repository

Create a `lighthouserc.js` at the root of the project. Adjust the `url` and
`assert` sections to match the project. See
[docs/onboarding.md](onboarding.md#4-configure-your-project) for full
configuration examples.

```js
// lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: ['https://www.example.com'],
      numberOfRuns: 3,
    },
    assert: {
      preset: 'lighthouse:recommended',
    },
    upload: {
      target:        'lhci',
      serverBaseUrl: process.env.LHCI_SERVER_URL,
      token:         process.env.LHCI_BUILD_TOKEN,
    },
  },
};
```

- [ ] `lighthouserc.js` created and committed to the project repository

### 2.5 — Add the Lighthouse CI workflow to the project repository

Create `.github/workflows/lighthouse-ci.yml` in the project repository:

```yaml
name: Lighthouse CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lighthouse:
    name: Lighthouse Audit
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      # Add build steps here if your app needs to be compiled first:
      # - name: Install dependencies
      #   run: npm ci
      # - name: Build
      #   run: npm run build

      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v11
        with:
          configPath: ./lighthouserc.js
          serverBaseUrl: ${{ vars.LHCI_SERVER_URL }}
          serverToken: ${{ secrets.LHCI_BUILD_TOKEN }}
          uploadArtifacts: true
          temporaryPublicStorage: false
```

- [ ] `.github/workflows/lighthouse-ci.yml` created and committed to the
  project repository

### 2.6 — Verify the first upload

After the workflow runs for the first time, open the server dashboard to
confirm reports are appearing:

```
http://<alb-dns-name>
```

- [ ] First Lighthouse report visible in the server dashboard for this project

---

## Part 3 — Recommended (but Optional) Follow-Up Tasks

These tasks are not required for the server to run, but are strongly
recommended for a production setup.

### 3.1 — Enable a custom domain with HTTPS

The ALB currently serves plain HTTP on port 80. To add HTTPS:

1. **Request or import a TLS certificate** in AWS Certificate Manager (ACM)
   in the same region as the deployment.
2. **Add an HTTPS listener** (port 443) to the ALB and attach the ACM
   certificate. You can do this in `terraform/alb.tf` by adding an
   `aws_lb_listener` resource with `protocol = "HTTPS"`.
3. **Create a DNS record** in Route 53 (or your DNS provider) pointing your
   custom domain to the ALB DNS name.
4. **Redirect HTTP → HTTPS** by updating the port-80 listener's default
   action to `redirect`.

- [ ] ACM certificate requested/validated
- [ ] HTTPS listener added to the ALB
- [ ] DNS record created
- [ ] HTTP → HTTPS redirect configured

### 3.2 — Enable automatic EFS database backups

The SQLite database stored on EFS is not backed up automatically by default.
Enable daily backups with 30-day retention:

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
  --region us-west-1
```

Then assign the EFS file system to the backup plan using the AWS Console or
CLI (select the EFS resource in the backup plan assignment).

- [ ] AWS Backup plan created and assigned to the EFS file system

### 3.3 — Set AWS billing alerts

To avoid unexpected charges, create a billing alarm:

1. Go to **AWS Billing → Budgets → Create budget**.
2. Choose **Cost budget**, set a monthly threshold (e.g. $20), and add an
   email alert.

- [ ] AWS billing budget / alert configured

### 3.4 — Tighten IAM permissions (if using Option A managed policies)

If you set up the IAM user with the ten broad managed policies from step 1.1
Option A, replace them with the least-privilege inline policy once everything
is working:

```bash
# Detach the broad managed policies one by one, then attach the scoped policy:
aws iam create-policy \
  --policy-name codeaftermath-lighthouse-github-actions \
  --policy-document file://terraform/iam-policy-github-actions.json

aws iam attach-user-policy \
  --user-name github-actions-lighthouse \
  --policy-arn arn:aws:iam::<account-id>:policy/codeaftermath-lighthouse-github-actions
```

See [`terraform/iam-policy-github-actions.json`](../terraform/iam-policy-github-actions.json) for the full policy.

- [ ] Switched from managed policies to the least-privilege inline policy
