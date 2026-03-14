# ── ALB ───────────────────────────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.alb_http.id,
    aws_security_group.alb_https.id,
  ]
  subnets = aws_subnet.public[*].id

  # Prevent accidental deletion; disable before running terraform destroy.
  enable_deletion_protection = true

  # Drop requests that contain invalid HTTP header fields (prevents header injection).
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# ── Target Group ───────────────────────────────────────────────────────────────

resource "aws_lb_target_group" "lighthouse" {
  name        = "${var.project_name}-tg"
  port        = 9001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/version"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# ── Listener ───────────────────────────────────────────────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  lifecycle {
    precondition {
      condition     = var.acm_certificate_arn != null
      error_message = "acm_certificate_arn must be set for HTTPS listener. If you are creating a new ACM certificate with Terraform, request it first, add DNS validation records in Cloudflare, wait for issuance, then set acm_certificate_arn to the issued certificate ARN."
    }
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lighthouse.arn
  }
}
