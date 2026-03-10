resource "aws_ssm_parameter" "lhci_admin_api_key" {
  name        = "/${var.project_name}/lhci_admin_api_key"
  description = "Admin API key for the Lighthouse CI server."
  type        = "SecureString"
  value       = var.lhci_admin_api_key

  tags = {
    Name = "${var.project_name}-lhci-admin-api-key"
  }
}
