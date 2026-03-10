data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ── ECS Task Execution Role ────────────────────────────────────────────────────
# Used by the ECS agent to pull images from ECR and write logs to CloudWatch.

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Name = "${var.project_name}-ecs-exec-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_exec_ssm" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters"]
    resources = [aws_ssm_parameter.lhci_admin_api_key.arn]
  }
}

resource "aws_iam_role_policy" "ecs_exec_ssm" {
  name   = "${var.project_name}-ecs-exec-ssm"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_exec_ssm.json
}

# ── ECS Task Role ──────────────────────────────────────────────────────────────
# Used by the application code running inside the container.

resource "aws_iam_role" "ecs_task" {
  name               = "${var.project_name}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}

data "aws_iam_policy_document" "ecs_task" {
  statement {
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
    ]
    resources = [aws_efs_file_system.lighthouse_data.arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_efs" {
  name   = "${var.project_name}-ecs-task-efs"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task.json
}
