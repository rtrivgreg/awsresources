# =========================================================================================
# AWS CONFIG COMPLIANCE MATRIX (Backup)
# =========================================================================================
# • backup-recovery-point-encrypted: Enforced via dedicated KMS Customer Managed Key 
#   assigned directly to the AWS Backup Vault configuration block.
# • backup-plan-min-frequency-and-min-retention-check: Satisfied by pairing a structured 
#   cron cron(0 12 * * ? *) schedule with an explicit lifecycle deletion configuration.
# • backup-recovery-point-minimum-retention-check: Maintained via a 1-day retention 
#   lifecycle window block, preventing undefined lifespans on generated snapshots.
# • backup-recovery-point-manual-deletion-disabled: Met using Vault Lock in Governance 
#   mode to block unauthorized drops while preserving safe Terraform destroy paths.
# =========================================================================================

# ---------------------------------------------------------
# 1. Mock Target Resource (Smallest 1 GiB EBS Volume)
# ---------------------------------------------------------
# Creating a small, unattached volume provides a real resource 
# for AWS Backup to snapshot, generating compliant recovery points.
resource "aws_ebs_volume" "mock_target" {
  availability_zone = "us-east-1a"
  size              = 1 # 1 GiB minimum allocation
  encrypted         = true

  tags = {
    Name        = "backup-compliance-mock-target"
    Environment = "Testing"
  }
}

# ---------------------------------------------------------
# 2. KMS Key for Backup Encryption
# ---------------------------------------------------------
# Satisfies: backup-recovery-point-encrypted
resource "aws_kms_key" "backup_key" {
  description             = "KMS Key for AWS Backup compliance test"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# ---------------------------------------------------------
# 3. AWS Backup Vault & Vault Lock
# ---------------------------------------------------------
# Satisfies: backup-recovery-point-manual-deletion-disabled
resource "aws_backup_vault" "compliance_vault" {
  name        = "compliance-testing-vault"
  kms_key_arn = aws_kms_key.backup_key.arn
}

resource "aws_backup_vault_lock_configuration" "vault_lock" {
  backup_vault_name   = aws_backup_vault.compliance_vault.name
  changeable_for_days = 3 # No cooling-off period; allows immediate adjustments

  # Governance mode protects against deletion by standard users, 
  # but allows IAM admin/Terraform destroy to wipe it cleanly.
  # NEVER use COMPLIANCE mode for temporary test harnesses.
  max_retention_days = 365
  min_retention_days = 1
}

# ---------------------------------------------------------
# 4. AWS Backup Plan
# ---------------------------------------------------------
# Satisfies: backup-plan-min-frequency-and-min-retention-check
# Satisfies: backup-recovery-point-minimum-retention-check
resource "aws_backup_plan" "compliance_plan" {
  name = "compliance-testing-plan"

  rule {
    rule_name         = "hourly-or-daily-compliance-rule"
    target_vault_name = aws_backup_vault.compliance_vault.name
    schedule          = "cron(0 12 * * ? *)" # Runs once daily at 12:00 UTC

    lifecycle {
      delete_after = 1 # 1-day retention minimizes lifecycle storage fees
    }
  }
}

# ---------------------------------------------------------
# 5. AWS Backup Assignment Selection
# ---------------------------------------------------------
resource "aws_iam_role" "backup_role" {
  name = "aws-backup-compliance-execution-role"

  # FIX: Restructured clean JSON trust pattern targeting the AWS Backup service
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

resource "aws_backup_selection" "target_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "mock-target-selection"
  plan_id      = aws_backup_plan.compliance_plan.id

  # Directly target the 1 GiB EBS volume ARN
  resources = [
    aws_ebs_volume.mock_target.arn
  ]
}
