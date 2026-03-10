resource "aws_cloudwatch_log_group" "lighthouse" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-logs"
  }
}

# ── ECS Cluster ────────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = var.project_name
  }
}

# ── Task Definition ────────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "lighthouse" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "lighthouse-server"
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = 9001
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "LHCI_NO_WARNINGS"
          value = "1"
        },
        {
          name  = "LHCI_ADMIN_API_KEY"
          value = var.lhci_admin_api_key
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "lhci-data"
          containerPath = "/data"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.lighthouse.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:9001/v1/version || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }
    }
  ])

  volume {
    name = "lhci-data"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.lighthouse_data.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.lighthouse_data.id
        iam             = "ENABLED"
      }
    }
  }

  tags = {
    Name = var.project_name
  }
}

# ── ECS Service ────────────────────────────────────────────────────────────────

resource "aws_ecs_service" "lighthouse" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.lighthouse.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Force a new deployment when the task definition changes.
  force_new_deployment = true

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lighthouse.arn
    container_name   = "lighthouse-server"
    container_port   = 9001
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution,
    aws_efs_mount_target.lighthouse_data,
  ]

  tags = {
    Name = var.project_name
  }
}
