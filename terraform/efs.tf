# ── EFS File System ────────────────────────────────────────────────────────────

resource "aws_efs_file_system" "lighthouse_data" {
  creation_token   = "${var.project_name}-data"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name = "${var.project_name}-efs"
  }
}

# ── Mount Targets (one per public subnet / AZ) ────────────────────────────────

resource "aws_efs_mount_target" "lighthouse_data" {
  count = 2

  file_system_id  = aws_efs_file_system.lighthouse_data.id
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# ── Access Point ───────────────────────────────────────────────────────────────

resource "aws_efs_access_point" "lighthouse_data" {
  file_system_id = aws_efs_file_system.lighthouse_data.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.project_name}-efs-ap"
  }
}
