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

variable "container_image" {
  description = "Docker image URI to run in ECS. Defaults to the official public LHCI server image."
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
