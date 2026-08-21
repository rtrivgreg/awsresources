# 1. AWS Provider Configuration
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Change to your preferred target region
}

# 2. Minimal Shared File System Resource
resource "aws_efs_file_system" "test" {
  creation_token = "efs-config-rule-test"
  
  tags = {
    Name = "efs-config-test-fs"
  }
}

# 3. NON-COMPLIANT: Points to the root "/" directory
resource "aws_efs_access_point" "non_compliant" {
  file_system_id = aws_efs_file_system.test.id

  root_directory {
    path = "/"
  }

  tags = {
    Name = "test-non-compliant-ap"
  }
}

# 4. COMPLIANT: Points to a specific subfolder
resource "aws_efs_access_point" "compliant" {
  file_system_id = aws_efs_file_system.test.id

  root_directory {
    path = "/custom-sub-directory"
  }

  tags = {
    Name = "test-compliant-ap"
  }
}
