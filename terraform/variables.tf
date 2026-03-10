variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
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

variable "container_image" {
  description = "Full URI of the Docker image to run in ECS (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/codeaftermath-lighthouse:sha)."
  type        = string
  default     = "patrickhulce/lhci-server:0.13.0"
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
