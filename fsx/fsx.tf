# =========================================================================================
# COMPLIANCE TESTING GUIDE: fsx-openzfs-copy-tags-enabled
# =========================================================================================
# • Rule Objective:
#   - Assesses whether FSx for OpenZFS file systems copy tags to backups and child volumes.
#
# • Testing COMPLIANCE (Pass Scenario):
#   - Set both:
#       copy_tags_to_backups = true
#       copy_tags_to_volumes = true
#   - Deploy via 'terraform apply'.
#   - AWS Config marks the resource COMPLIANT (~1-2 mins post-deploy).
#
# • Testing NON-COMPLIANCE (Fail Scenario):
#   - Set either/both:
#       copy_tags_to_backups = false
#       copy_tags_to_volumes = false
#   - Deploy via 'terraform apply'.
#   - AWS Config marks the resource NON_COMPLIANT upon evaluating configuration change.
#
# • Fast Verification:
#   - Force immediate evaluation via AWS CLI:
#       aws configservice start-config-rules-evaluation \
#         --config-rule-names fsx-openzfs-copy-tags-enabled
# =========================================================================================

# ---------------------------------------------------------
# 1. Zero-Cost Test Network (VPC & Subnet)
# ---------------------------------------------------------
resource "aws_vpc" "compliance_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "fsx-compliance-vpc"
  }
}

resource "aws_subnet" "compliance_subnet" {
  vpc_id            = aws_vpc.compliance_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "fsx-compliance-subnet"
  }
}

# ---------------------------------------------------------
# 2. Minimal FSx for OpenZFS Resource
# ---------------------------------------------------------
resource "aws_fsx_openzfs_file_system" "compliance_test" {
  storage_capacity    = 64
  storage_type        = "SSD"
  throughput_capacity = 64
  deployment_type     = "SINGLE_AZ_1"

  # Uses the managed subnet directly (no variable prompt)
  subnet_ids = [aws_subnet.compliance_subnet.id]

  # Rule: fsx-openzfs-copy-tags-enabled
  copy_tags_to_backups = true
  copy_tags_to_volumes = true

  # Disable internal snapshot retention to eliminate extra FSx costs
  automatic_backup_retention_days = 0
  skip_final_backup               = true

  tags = {
    Name        = "fsx-openzfs-compliance-test"
    Environment = "Testing"
  }
}

# ---------------------------------------------------------
# 3. AWS Backup Infrastructure
# ---------------------------------------------------------
resource "aws_iam_role" "backup_role" {
  name = "fsx-openzfs-backup-compliance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_vault" "test_vault" {
  name = "fsx-test-backup-vault"
}

# Rule: fsx-resources-protected-by-backup-plan
resource "aws_backup_plan" "test_plan" {
  name = "fsx-compliance-backup-plan"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.test_vault.name
    schedule          = "cron(0 12 * * ? *)"

    lifecycle {
      delete_after = 1 # Minimize vault retention costs
    }
  }
}

# Assigns the FSx OpenZFS file system to the AWS Backup Plan
resource "aws_backup_selection" "fsx_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "fsx-openzfs-selection"
  plan_id      = aws_backup_plan.test_plan.id

  resources = [
    aws_fsx_openzfs_file_system.compliance_test.arn
  ]
}
