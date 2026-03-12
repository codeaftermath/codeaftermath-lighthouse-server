# ── ALB Security Group ─────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP/HTTPS traffic to the ALB."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ALB only needs to reach ECS tasks on the container port within the VPC.
  egress {
    description = "LHCI server port to ECS tasks"
    from_port   = 9001
    to_port     = 9001
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ── ECS Security Group ─────────────────────────────────────────────────────────

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "Allow inbound traffic from the ALB to ECS tasks."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "LHCI server port from ALB"
    from_port       = 9001
    to_port         = 9001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # HTTPS (443): pull image from Docker Hub, reach AWS APIs (SSM, CloudWatch).
  egress {
    description = "HTTPS to internet (Docker Hub, AWS APIs)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NFS (2049): mount EFS within the VPC; EFS transit encryption uses a local
  # TLS proxy so the wire traffic still exits on the standard NFS port.
  egress {
    description = "NFS to EFS within VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.project_name}-ecs-sg"
  }
}

# ── EFS Security Group ─────────────────────────────────────────────────────────

resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Allow NFS traffic from ECS tasks to EFS."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # EFS mount targets are passive responders; they never initiate outbound
  # connections. Return traffic is handled by stateful security group tracking
  # so no egress rule is required.

  tags = {
    Name = "${var.project_name}-efs-sg"
  }
}
