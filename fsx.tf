

# ---------------------------------------------------------
# 1. Minimal FSx for OpenZFS File System
# ---------------------------------------------------------
resource "aws_fsx_openzfs_file_system" "compliance_test" {
  # Minimum storage capacity for OpenZFS SSD (64 GiB)
  storage_capacity    = 64
  storage_type        = "SSD"
  throughput_capacity = 64

  deployment_type = "SINGLE_AZ_1"
  subnet_ids      = [var.subnet_id]

  # RULE COMPLIANCE: fsx-openzfs-copy-tags-enabled
  # Both copy flags must be true to satisfy the AWS Config rule
  copy_tags_to_backups = true
  copy_tags_to_volumes = true

  # Disable internal FSx automated backups to avoid duplicate storage costs
  automatic_backup_retention_days = 0
  skip_final_backup               = true

  tags = {
    Name        = "fsx-openzfs-compliance-test"
    Environment = "Testing"
  }
}

# ---------------------------------------------------------
# 2. AWS Backup Plan (Satisfies fsx-resources-protected-by-backup-plan)
# ---------------------------------------------------------

# IAM Role for AWS Backup
resource "aws_iam_role" "backup_role" {
  name = "fsx-openzfs-backup-compliance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "://amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# AWS Backup Vault
resource "aws_backup_vault" "test_vault" {
  name = "fsx-test-backup-vault"
}

# AWS Backup Plan
resource "aws_backup_plan" "test_plan" {
  name = "fsx-compliance-backup-plan"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.test_vault.name
    schedule          = "cron(0 12 * * ? *)"

    lifecycle {
      delete_after = 1 # Minimal retention to minimize backup costs
    }
  }
}

# AWS Backup Selection targeting the OpenZFS File System ARN
resource "aws_backup_selection" "fsx_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "fsx-openzfs-selection"
  plan_id      = aws_backup_plan.test_plan.id

  resources = [
    aws_fsx_openzfs_file_system.compliance_test.arn
  ]
}

# ---------------------------------------------------------
# Variables
# ---------------------------------------------------------
variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "subnet_id" {
  type        = string
  description = "The Subnet ID for the OpenZFS Single-AZ deployment"
}
