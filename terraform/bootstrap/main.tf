# Bootstrap: creates the S3 bucket and DynamoDB table used as the Terraform
# remote state backend for the main lighthouse-server configuration.
#
# Run this ONCE before initialising the main Terraform configuration:
#
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
#
# After the resources are created, switch to the terraform/ directory and run
# the usual workflow.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "codeaftermath-lighthouse"
      ManagedBy = "terraform"
    }
  }
}

variable "aws_region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

# ── S3 State Bucket ────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "terraform_state" {
  bucket = "codeaftermath-terraform-state"

  # Prevent accidental deletion of the bucket that holds all Terraform state.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "codeaftermath-terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── DynamoDB Lock Table ────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "codeaftermath-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "codeaftermath-terraform-locks"
  }
}
