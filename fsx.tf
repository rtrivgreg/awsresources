
# --- Shared Networking Prerequisites ---
resource "aws_vpc" "fsx_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.fsx_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.fsx_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_security_group" "fsx_sg" {
  vpc_id = aws_vpc.fsx_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/30"] # Restricted dummy block
  }
}

################################################################################
# 1. COMPLIANT STACK (Passes All 4 Managed Rules)
################################################################################

# Rule 1 Check: OpenZFS with tag replication enabled
resource "aws_fsx_openzfs_file_system" "compliant_zfs" {
  storage_capacity                = 64
  subnet_ids                      = [aws_subnet.subnet_a.id]
  deployment_type                 = "SINGLE_AZ_1"
  throughput_capacity             = 64
  security_group_ids              = [aws_security_group.fsx_sg.id]
  
  # CRITICAL COMPLIANCE PARAMS
  copy_tags_to_backups            = true
  copy_tags_to_volumes            = true
}

# Rule 2 Check: NetApp ONTAP set explicitly to Multi-AZ
resource "aws_fsx_ontap_file_system" "compliant_ontap" {
  storage_capacity    = 1024
  subnet_ids          = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  throughput_capacity = 128
  security_group_ids  = [aws_security_group.fsx_sg.id]
  preferred_subnet_id = aws_subnet.subnet_a.id

  # CRITICAL COMPLIANCE PARAM
  deployment_type     = "MULTI_AZ_1" 
}

# Rule 3 Check: Lustre with tag replication enabled
resource "aws_fsx_lustre_file_system" "compliant_lustre" {
  storage_capacity    = 1200
  subnet_ids          = [aws_subnet.subnet_a.id]
  security_group_ids  = [aws_security_group.fsx_sg.id]

  # CRITICAL COMPLIANCE PARAM
  copy_tags_to_backups = true 
}

# Rule 4 Check: Protection via AWS Backup Plan
resource "aws_backup_vault" "compliance_vault" {
  name        = "fsx_compliance_backup_vault"
}

resource "aws_backup_plan" "compliant_plan" {
  name = "fsx_compliant_backup_plan"

  rule {
    rule_name         = "daily_backup_rule"
    target_vault_name = aws_backup_vault.compliance_vault.name
    schedule          = "cron(0 12 * * ? *)"
  }
}

resource "aws_iam_role" "backup_role" {
  name = "fsx_backup_compliance_role"
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
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

# Explicit Selection protecting the compliant ONTAP array
resource "aws_backup_selection" "fsx_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "fsx_compliant_selection"
  plan_id      = aws_backup_plan.compliant_plan.id

  resources = [
    aws_fsx_ontap_file_system.compliant_ontap.arn
  ]
}


################################################################################
# 2. NON-COMPLIANT STACK (Fails All 4 Managed Rules)
################################################################################

# Rule 1 Failure: OpenZFS with tag replication turned off
resource "aws_fsx_openzfs_file_system" "non_compliant_zfs" {
  storage_capacity                = 64
  subnet_ids                      = [aws_subnet.subnet_a.id]
  deployment_type                 = "SINGLE_AZ_1"
  throughput_capacity             = 64
  security_group_ids              = [aws_security_group.fsx_sg.id]
  
  # FAILS COMPLIANCE (Must be true)
  copy_tags_to_backups            = false
  copy_tags_to_volumes            = false
}

# Rule 2 Failure: NetApp ONTAP set to Single-AZ instead of Multi-AZ
resource "aws_fsx_ontap_file_system" "non_compliant_ontap" {
  storage_capacity    = 1024
  subnet_ids          = [aws_subnet.subnet_a.id]
  throughput_capacity = 128
  security_group_ids  = [aws_security_group.fsx_sg.id]

  # FAILS COMPLIANCE (Must be MULTI_AZ_1)
  deployment_type     = "SINGLE_AZ_1" 
}

# Rule 3 Failure: Lustre with tag replication explicitly set to false
resource "aws_fsx_lustre_file_system" "non_compliant_lustre" {
  storage_capacity    = 1200
  subnet_ids          = [aws_subnet.subnet_a.id]
  security_group_ids  = [aws_security_group.fsx_sg.id]

  # FAILS COMPLIANCE (Must be true)
  copy_tags_to_backups = false 
}

# Rule 4 Failure Context: 
# The resource 'aws_fsx_openzfs_file_system.non_compliant_zfs' 
# is left completely isolated and unassigned to any aws_backup_selection tracker.
