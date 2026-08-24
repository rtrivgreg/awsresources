# ==============================================================================
# AWS CONFIG COMPLIANCE TEST BED: AMAZON EFS & AWS BACKUP
#
# Target AWS Config Rule Coverage:
# - DISASTER RECOVERY: efs-in-backup-plan, efs-resources-protected-by-backup-plan,
#                      efs-automatic-backups-enabled
# - ENCRYPTION:        efs-filesystem-ct-encrypted, efs-encrypted-check
# - NETWORK SECURITY:  efs-mount-target-public-accessible
# - ACCESS CONTROL:    efs-access-point-enforce-root-directory, 
#                      efs-access-point-enforce-user-identity
#
# Structure: Deploys side-by-side COMPLIANT and NON_COMPLIANT resource pairs 
#            to validate absolute rule evaluation logic at zero minimal cost.
# ==============================================================================

/*
cli test

#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# Change this to the exact name of your deployed Conformance Pack
PACK_NAME="efs-security-conformance-pack"

echo "=============================================================================="
echo " STEP 1: REFRESHING COMPLIANCE ENGINE FOR CONFORMANCE PACK: $PACK_NAME"
echo "=============================================================================="

echo "--> Discovering system-generated rule names inside the pack..."
RULE_NAMES=$(aws configservice describe-config-rules \
    --query "ConfigRules[?contains(ConfigRuleName, '$PACK_NAME')].ConfigRuleName" \
    --output text)

if [ -z "$RULE_NAMES" ]; then
    echo "Error: No rules found matching Conformance Pack name '$PACK_NAME'."
    exit 1
fi

echo "--> Triggering evaluation refresh for the following rules:"
echo "$RULE_NAMES" | tr ' ' '\n'
echo ""

# Execute the asynchronous evaluation refresh
aws configservice start-config-rules-evaluation --config-rule-names $RULE_NAMES

echo "--> Refresh signal sent successfully. (Evaluations run asynchronously in the background)."
echo "--> Waiting 10 seconds for initial processing before pulling diagnostics..."
sleep 10


echo "=============================================================================="
echo " STEP 2: DIAGNOSTICS & LOGICAL EVALUATION PROBLEMS"
echo "=============================================================================="
echo "Checking if any rules failed to execute (e.g., IAM permission errors or timeouts)..."
echo ""

aws configservice describe-config-rules \
    --config-rule-names $RULE_NAMES \
    --query "ConfigRules[?[ConfigRuleState!='ACTIVE'] || [LastErrorMessage!=null]].{
        RuleName: ConfigRuleName,
        State: ConfigRuleState,
        FailureReason: LastErrorMessage
    }" \
    --output table

echo "Note: If the table above is empty, all rules executed successfully without system errors."
echo ""


echo "=============================================================================="
echo " STEP 3: DETAILED RESOURCE COMPLIANCE STATES"
echo "=============================================================================="
echo "Listing evaluated resources and their compliance status (COMPLIANT / NON_COMPLIANT)..."
echo ""

# Formats output into a clean table showing Resource Type, ID, and Compliance State
aws configservice describe-conformance-pack-compliance-details \
    --conformance-pack-name "$PACK_NAME" \
    --query "ConformancePackRuleEvaluationResults[].EvaluationResultIdentifier.EvaluationResultQualifier.{
        ResourceType: ResourceType,
        ResourceID: ResourceId,
        Compliance: ComplianceType
    }" \
    --output table


*/

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "efs-config-test-vpc" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags                 = { Name = "efs-compliant-private-subnet" }
}

# Public subnet designed to trigger the "efs-mount-target-public-accessible" rule
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true 
  tags                    = { Name = "efs-noncompliant-public-subnet" }
}

# Internet Gateway to satisfy the subnet logic requirement for internet-route evaluations
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-test-sg"
  description = "Minimal EFS rules"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

# ==============================================================================
# 2. AWS BACKUP ARCHITECTURE
# ==============================================================================

resource "aws_backup_vault" "test_vault" {
  name        = "efs_config_test_vault"
  kms_key_arn = "arn:aws:kms:us-east-1:111222333444:alias/aws/backup" # Fallback placeholder or standard alias
}

resource "aws_backup_plan" "compliant_plan" {
  name = "efs_compliant_backup_plan"

  rule {
    rule_name         = "daily_backup_rule"
    target_vault_name = aws_backup_vault.test_vault.name
    schedule          = "cron(0 12 * * ? *)"
    
    lifecycle {
      delete_after = 35
    }
  }
}

resource "aws_iam_role" "backup_role" {
  name = "efs-backup-test-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackupAndRestore"
  role       = aws_iam_role.backup_role.name
}

# Compliant Backup Assignment (Protects COMPLIANT filesystem)
resource "aws_backup_selection" "compliant_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "compliant_efs_selection"
  plan_id      = aws_backup_plan.compliant_plan.id

  resources = [
    aws_efs_file_system.compliant.arn
  ]
}

# ==============================================================================
# 3. COMPLIANT FILESYSTEM RESOURCES
# ==============================================================================

resource "aws_efs_file_system" "compliant" {
  creation_token   = "efs-compliant-token"
  encrypted        = true # Satisfies: efs-filesystem-ct-encrypted & efs-encrypted-check
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "efs-compliant-resource"
    # Satisfies: efs-automatic-backups-enabled (AWS managed backup policy tag standard if applicable)
    "aws:elasticfilesystem:backup-policy" = "dummy-enabled" 
  }
}

resource "aws_efs_backup_policy" "compliant_policy" {
  file_system_id = aws_efs_file_system.compliant.id
  backup_policy {
    status = "ENABLED" # Satisfies: efs-automatic-backups-enabled
  }
}

resource "aws_efs_mount_target" "compliant_target" {
  file_system_id  = aws_efs_file_system.compliant.id
  subnet_id       = aws_subnet.private.id # Satisfies: efs-mount-target-public-accessible
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_access_point" "compliant_ap" {
  file_system_id = aws_efs_file_system.compliant.id

  # Satisfies: efs-access-point-enforce-root-directory
  root_directory {
    path = "/custom-root" 
    creation_info {
      owner_gid   = 1001
      owner_uid   = 1001
      permissions = "0755"
    }
  }

  # Satisfies: efs-access-point-enforce-user-identity
  posix_user {
    uid = 1001
    gid = 1001
  }
}

# ==============================================================================
# 4. NON-COMPLIANT FILESYSTEM RESOURCES
# ==============================================================================

resource "aws_efs_file_system" "non_compliant" {
  creation_token   = "efs-non-compliant-token"
  encrypted        = false # Triggers Violation: efs-filesystem-ct-encrypted & efs-encrypted-check
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "efs-non-compliant-resource"
  }
}

resource "aws_efs_backup_policy" "non_compliant_policy" {
  file_system_id = aws_efs_file_system.non_compliant.id
  backup_policy {
    status = "DISABLED" # Triggers Violation: efs-automatic-backups-enabled
  }
}

# Left intentionally out of aws_backup_selection to trigger:
# efs-in-backup-plan & efs-resources-protected-by-backup-plan

resource "aws_efs_mount_target" "non_compliant_target" {
  file_system_id  = aws_efs_file_system.non_compliant.id
  subnet_id       = aws_subnet.public.id # Triggers Violation: efs-mount-target-public-accessible
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_access_point" "non_compliant_ap" {
  file_system_id = aws_efs_file_system.non_compliant.id

  # Triggers Violation: efs-access-point-enforce-root-directory (Exposes root path directly)
  root_directory {
    path = "/"
  }

  # Triggers Violation: efs-access-point-enforce-user-identity (Lacks posix_user identity enforce block)
}
