# Bootstrap ACM certificate request (one-time/manual DNS validation flow).
#
# Run from this directory when you need to request or rotate a certificate:
#
#   cd terraform/bootstrap/acm
#   terraform init
#   terraform apply

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "codeaftermath-terraform-state"
    key          = "lighthouse-server/acm-bootstrap.tfstate"
    region       = "us-west-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

variable "aws_region" {
  description = "AWS region to request the ACM certificate in (must match the ALB region)."
  type        = string
  default     = "us-west-1"
}

variable "environment" {
  description = "Environment tag value for ACM resources."
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used as a prefix for ACM resource tags."
  type        = string
  default     = "codeaftermath-lighthouse"
}

variable "acm_domain_name" {
  description = "Primary domain name for ACM certificate request (for example *.codeaftermath.com)."
  type        = string
  default     = "*.codeaftermath.com"
}

variable "acm_subject_alternative_names" {
  description = "Optional SAN entries for ACM certificate request."
  type        = list(string)
  default     = []
}

variable "acm_key_algorithm" {
  description = "Key algorithm for ACM certificate request."
  type        = string
  default     = "EC_prime256v1"
}

resource "aws_acm_certificate" "managed" {
  domain_name               = var.acm_domain_name
  subject_alternative_names = var.acm_subject_alternative_names
  validation_method         = "DNS"
  key_algorithm             = var.acm_key_algorithm

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-acm"
  }
}

output "acm_certificate_request_arn" {
  description = "ARN of the ACM certificate requested by Terraform."
  value       = aws_acm_certificate.managed.arn
}

output "acm_dns_validation_records" {
  description = "DNS records to create manually in external DNS (for example Cloudflare) to validate the ACM certificate."
  value = [
    for dvo in aws_acm_certificate.managed.domain_validation_options : {
      domain_name  = dvo.domain_name
      record_name  = dvo.resource_record_name
      record_type  = dvo.resource_record_type
      record_value = dvo.resource_record_value
    }
  ]
}
