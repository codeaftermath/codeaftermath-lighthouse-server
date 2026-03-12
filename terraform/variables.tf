variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-west-1"
}

variable "environment" {
  description = "Environment name (e.g., production, staging)."
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used as a prefix for all resource names."
  type        = string
  default     = "codeaftermath-lighthouse"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in the same region as the ALB (for HTTPS listener)."
  type        = string
  default     = null
}

variable "create_acm_certificate" {
  description = "When true, Terraform requests an ACM certificate and outputs DNS validation records for manual creation in external DNS providers (for example Cloudflare)."
  type        = bool
  default     = false
}

variable "acm_domain_name" {
  description = "Primary domain name for ACM certificate request (for example *.codeaftermath.com). Used only when create_acm_certificate=true."
  type        = string
  default     = "*.codeaftermath.com"
}

variable "acm_subject_alternative_names" {
  description = "Optional SAN entries for ACM certificate request. Used only when create_acm_certificate=true."
  type        = list(string)
  default     = ["codeaftermath.com"]
}

variable "container_image" {
  description = "Docker image URI to run in ECS. Defaults to the CodeAftermath-maintained public LHCI server image."
  type        = string
  default     = "codeaftermath/lhci-server:0.15.1"
}

variable "container_cpu" {
  description = "CPU units to allocate to the ECS task (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory (MiB) to allocate to the ECS task."
  type        = number
  default     = 512
}

variable "lhci_admin_api_key" {
  description = "Admin API key for the LHCI server. Must be a 20-character or longer string."
  type        = string
  sensitive   = true
}

variable "use_spot" {
  description = "Use FARGATE_SPOT as the preferred capacity provider (~70% cheaper) with regular FARGATE as fallback. Spot tasks can be interrupted with a 2-minute warning; EFS persistence means no data loss on restart."
  type        = bool
  default     = true
}
