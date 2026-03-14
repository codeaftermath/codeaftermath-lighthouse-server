output "lighthouse_server_url" {
  description = "Public URL of the Lighthouse CI server."
  value       = "https://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.lighthouse.name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "target_group_arn" {
  description = "ARN of the ALB target group for the Lighthouse service."
  value       = aws_lb_target_group.lighthouse.arn
}
