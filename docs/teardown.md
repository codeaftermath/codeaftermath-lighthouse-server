# Teardown Guide

How to fully tear down CodeAftermath Lighthouse infrastructure without leaving
orphaned resources.

> Warning: This is destructive and can permanently delete Lighthouse data.

## Scope

This runbook covers:

1. Main stack in terraform/
2. Optional ACM bootstrap stack in terraform/bootstrap/acm/
3. Bootstrap backend stack in terraform/bootstrap/

## Prerequisites

1. Verified backup of /data/lhci.db (EFS data) if you need historical data.
2. AWS credentials/profile with permissions to destroy all managed resources.
3. No active Terraform apply/plan jobs running in CI.

## 1. Disable ALB deletion protection

The ALB has deletion protection enabled by default in terraform/alb.tf, so
terraform destroy will fail until this is disabled.

1. Edit terraform/alb.tf and set:

```hcl
enable_deletion_protection = false
```

2. Apply this change first:

```bash
cd terraform
terraform apply -var="lhci_admin_api_key=<key>"
```

## 2. Destroy the main stack

```bash
cd terraform
terraform destroy -var="lhci_admin_api_key=<key>"
```

Expected result: VPC, ALB, ECS, EFS, IAM roles/policies, logs, and related
resources are removed.

## 3. Optional: destroy ACM bootstrap stack

Run this only if you created certs from terraform/bootstrap/acm and want that
state-managed ACM resource removed too.

```bash
cd terraform/bootstrap/acm
terraform destroy
```

If you plan to keep using the same certificate elsewhere, skip this step.

## 4. Destroy backend bootstrap stack

The state bucket is protected by prevent_destroy in terraform/bootstrap/main.tf.
Remove the lifecycle guard before destroying bootstrap resources.

1. Edit terraform/bootstrap/main.tf and remove or comment:

```hcl
lifecycle {
  prevent_destroy = true
}
```

2. Destroy bootstrap stack:

```bash
cd terraform/bootstrap
terraform destroy
```

## 5. Clean up local Terraform artifacts

Optional local cleanup:

```bash
find terraform -type d -name ".terraform" -prune -exec rm -rf {} +
find terraform -type f -name ".terraform.lock.hcl" -print
```

## 6. Troubleshooting

### State lock stuck

Use lock ID from error output:

```bash
terraform force-unlock <LOCK_ID>
```

### Destroy still fails due to protection

1. Re-check enable_deletion_protection in terraform/alb.tf is false and applied.
2. Re-check prevent_destroy was removed in terraform/bootstrap/main.tf.

## Verification checklist

1. terraform state list in terraform/ returns no managed resources.
2. terraform state list in terraform/bootstrap/acm/ returns no managed resources (if destroyed).
3. terraform state list in terraform/bootstrap/ returns no managed resources.
4. AWS Console shows no running ECS service/task for this stack.
5. ALB DNS endpoint no longer resolves for this stack.
