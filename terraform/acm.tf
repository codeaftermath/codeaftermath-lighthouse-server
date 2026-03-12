resource "aws_acm_certificate" "managed" {
  count = var.create_acm_certificate ? 1 : 0

  domain_name               = var.acm_domain_name
  subject_alternative_names = var.acm_subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-acm"
  }
}

output "acm_certificate_request_arn" {
  description = "ARN of the ACM certificate requested by Terraform (null when create_acm_certificate=false)."
  value       = try(aws_acm_certificate.managed[0].arn, null)
}

output "acm_dns_validation_records" {
  description = "DNS records to create manually in external DNS (for example Cloudflare) to validate the ACM certificate."
  value = [
    for dvo in try(aws_acm_certificate.managed[0].domain_validation_options, []) : {
      domain_name  = dvo.domain_name
      record_name  = dvo.resource_record_name
      record_type  = dvo.resource_record_type
      record_value = dvo.resource_record_value
    }
  ]
}