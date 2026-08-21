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

# 5. LOCAL AWS CONFIG RULE (Bypasses Organization Conformance Pack Delays)
resource "aws_config_config_rule" "local_efs_test_rule" {
  name        = "local-efs-access-point-enforce-root-directory"
  description = "Local rule to test EFS Access Point compliance immediately."

  source {
    owner             = "AWS"
    source_identifier = "EFS_ACCESS_POINT_ENFORCE_ROOT_DIRECTORY"
  }

  # Restricts evaluations strictly to EFS Access Points to reduce noise
  scope {
    compliance_resource_types = ["AWS::EFS::AccessPoint"]
  }
}

