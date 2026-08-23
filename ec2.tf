# =========================================================================================
# AWS EC2 & EBS STORAGE CONFIG RULE COMPLIANCE SUMMARY
# =========================================================================================
# • ec2-ebs-encryption-by-default:
#   - Assesses whether account-level EBS volume encryption by default is enabled.
#   - Compliance toggle: Modify 'aws_ebs_encryption_by_default.enabled' (true vs false).
#
# • ec2-launch-templates-ebs-volume-encrypted:
#   - Assesses whether EC2 Launch Templates configure all block device mappings with encryption.
#   - Compliant: Set 'block_device_mappings.ebs.encrypted = true'.
#   - Non-Compliant: Set 'block_device_mappings.ebs.encrypted = false' or omit the field.
#
# • ec2-spot-fleet-request-ct-encryption-at-rest:
#   - Evaluates whether Spot Fleet Requests mandate encryption on attached EBS volumes.
#   - Zero-Cost Architecture: Set 'target_capacity = 0' to evaluate request definitions 
#     via the AWS Control Plane API without launching live, billable EC2 compute instances.
# =========================================================================================

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for test deployment"
}

# ---------------------------------------------------------
# 1. Account-Level EBS Encryption (ec2-ebs-encryption-by-default)
# ---------------------------------------------------------
# Set 'enabled = true' to test COMPLIANCE.
# Set 'enabled = false' to test NON-COMPLIANCE.
resource "aws_ebs_encryption_by_default" "account_wide_ebs_encryption" {
  enabled = true
}

# ---------------------------------------------------------
# 2. Base Network & IAM Prerequisites (Zero Cost)
# ---------------------------------------------------------
data "aws_ami" "minimal_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }
}

resource "aws_iam_role" "spot_fleet_role" {
  name = "spot-fleet-compliance-test-role"

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

resource "aws_iam_role_policy_attachment" "spot_fleet_policy" {
  role       = aws_iam_role.spot_fleet_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

# ---------------------------------------------------------
# 3. EC2 Launch Templates (ec2-launch-templates-ebs-volume-encrypted)
# ---------------------------------------------------------

# COMPLIANT: Explicitly enables encryption on block device mappings
resource "aws_launch_template" "compliant_template" {
  name          = "lt-storage-compliant"
  image_id      = data.aws_ami.minimal_ami.id
  instance_type = "t3.nano"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 1 # 1 GiB minimum allocation
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tags = {
    Name        = "launch-template-compliant"
    Environment = "Testing"
  }
}

# NON-COMPLIANT: Explicitly disables encryption on block device mappings
resource "aws_launch_template" "non_compliant_template" {
  name          = "lt-storage-non-compliant"
  image_id      = data.aws_ami.minimal_ami.id
  instance_type = "t3.nano"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 1 # 1 GiB minimum allocation
      volume_type = "gp3"
      encrypted   = false
    }
  }

  tags = {
    Name        = "launch-template-non-compliant"
    Environment = "Testing"
  }
}

# ---------------------------------------------------------
# 4. Spot Fleet Requests (ec2-spot-fleet-request-ct-encryption-at-rest)
# ---------------------------------------------------------

# COMPLIANT: Uses the compliant Launch Template with target_capacity = 0 to prevent billing
resource "aws_spot_fleet_request" "compliant_spot_fleet" {
  iam_fleet_role      = aws_iam_role.spot_fleet_role.arn
  target_capacity     = 0 # Cost protection: prevents instance launch
  allocation_strategy = "lowestPrice"

  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.compliant_template.id
      version = aws_launch_template.compliant_template.latest_version
    }
  }

  tags = {
    Name        = "spot-fleet-compliant"
    Environment = "Testing"
  }
}

# NON-COMPLIANT: Uses the non-compliant Launch Template with target_capacity = 0 to prevent billing
resource "aws_spot_fleet_request" "non_compliant_spot_fleet" {
  iam_fleet_role      = aws_iam_role.spot_fleet_role.arn
  target_capacity     = 0 # Cost protection: prevents instance launch
  allocation_strategy = "lowestPrice"

  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.non_compliant_template.id
      version = aws_launch_template.non_compliant_template.latest_version
    }
  }

  tags = {
    Name        = "spot-fleet-non-compliant"
    Environment = "Testing"
  }
}

