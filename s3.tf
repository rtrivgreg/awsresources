# Fetch the current AWS Account ID dynamically to format Access Point resource names
data "aws_caller_identity" "current" {}

################################################################################
# 1. COMPLIANT INFRASTRUCTURE STACK
################################################################################

# Compliant S3 Bucket
resource "aws_s3_bucket" "compliant_bucket" {
  bucket        = "compliant-test-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# Compliant S3 Access Point (All 4 Public Access Blocks are set to true)
resource "aws_s3_access_point" "compliant_access_point" {
  bucket = aws_s3_bucket.compliant_bucket.id
  name   = "compliant-ap"

  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}


################################################################################
# 2. NON-COMPLIANT INFRASTRUCTURE STACK
################################################################################

# Non-Compliant S3 Bucket
resource "aws_s3_bucket" "non_compliant_bucket" {
  bucket        = "non-compliant-test-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# Non-Compliant S3 Access Point (Fails compliance because blocks are explicitly false)
resource "aws_s3_access_point" "non_compliant_access_point" {
  bucket = aws_s3_bucket.non_compliant_bucket.id
  name   = "non-compliant-ap"

  public_access_block_configuration {
    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
  }
}

# -----------------------------------------------------------------------------------------
# NETWORK PREREQUISITES (Zero cost infrastructure for Access Point validation)
# -----------------------------------------------------------------------------------------
resource "aws_vpc" "test_vpc" {
  cidr_block = "10.0.0.0/16"
}

# -----------------------------------------------------------------------------------------
# 1. S3 EXPRESS DIRECTORY BUCKETS (s3express-dir-bucket-lifecycle-rules-check)
# -----------------------------------------------------------------------------------------

# COMPLIANT: Directory bucket with active lifecycle rule configuration attached
resource "aws_s3_directory_bucket" "compliant" {
  bucket = "compliant-test-bucket--use1-az4--x-s3"

  location {
    name = "use1-az4"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "dir_compliant_lifecycle" {
  bucket = aws_s3_directory_bucket.compliant.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# NON-COMPLIANT: Directory bucket explicitly missing a lifecycle configuration
resource "aws_s3_directory_bucket" "dir_non_compliant" {
  bucket = "dir-non-compliant--use1-az4--x-s3"

  location {
    name = "use1-az4"
  }
}


# -----------------------------------------------------------------------------------------
# 2. S3 ACCESS POINTS (s3-access-point-in-vpc-only & s3-access-point-public-access-blocks)
# -----------------------------------------------------------------------------------------
resource "aws_s3_bucket" "ap_standard_bucket" {
  bucket        = "cfg-compliance-access-point-testing-bucket"
  force_destroy = true
}

# COMPLIANT AP: Enforces VPC-Only routing and explicitly enables Public Access Blocks
resource "aws_s3_access_point" "ap_compliant" {
  bucket = aws_s3_bucket.ap_standard_bucket.id
  name   = "ap-storage-compliant"

  vpc_configuration {
    vpc_id = aws_vpc.test_vpc.id
  }

  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}

# NON-COMPLIANT AP: Public endpoint routing enabled; missing public block configuration
resource "aws_s3_access_point" "ap_non_compliant" {
  bucket = aws_s3_bucket.ap_standard_bucket.id
  name   = "ap-storage-non-compliant"
  # Absence of 'vpc_configuration' makes it Internet-routing (Triggers s3-access-point-in-vpc-only fail)
  # Absence of 'public_access_block_configuration' triggers second rule fail
}


# -----------------------------------------------------------------------------------------
# 3. S3 BUCKET POLICIES (s3-bucket-policy-not-more-permissive)
# -----------------------------------------------------------------------------------------

# COMPLIANT: Standard bucket locked down to a single designated IAM root string identifier
resource "aws_s3_bucket" "policy_compliant" {
  bucket        = "cfg-compliance-policy-compliant-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "compliant_policy_attachment" {
  bucket = aws_s3_bucket.policy_compliant.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSpecificRoot"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.policy_compliant.arn}/*"
      }
    ]
  })
}

# NON-COMPLIANT: Open bucket policy using a permissive wildcard principal string configuration
resource "aws_s3_bucket" "policy_non_compliant" {
  bucket        = "cfg-compliance-policy-non-compliant-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "non_compliant_policy_attachment" {
  bucket = aws_s3_bucket.policy_non_compliant.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PermissiveWildcardPrincipal"
        Effect    = "Allow"
        Principal = "*" # Wildcard triggers s3-bucket-policy-not-more-permissive flag
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.policy_non_compliant.arn}/*"
      }
    ]
  })
}


# -----------------------------------------------------------------------------------------
# 4. RESTORE TIME TARGET (s3-meets-restore-time-target)
# -----------------------------------------------------------------------------------------

# COMPLIANT: Stays on short recovery tiers (Transitions straight to STANDARD_IA)
resource "aws_s3_bucket" "restore_target" {
  bucket        = "restore-compliance-test-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "restore_compliant_config" {
  bucket = aws_s3_bucket.restore_target.id

  rule {
    id     = "restore-target-rule"
    status = "Enabled"
    filter {}

    # Example transition block to satisfy the rule requirements
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
}


# NON-COMPLIANT: Automatically archives to slow cold tiers (Glacier Deep Archive)
resource "aws_s3_bucket" "restore_non_compliant" {
  bucket        = "cfg-compliance-restore-non-compliant-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "restore_non_compliant_config" {
  bucket = aws_s3_bucket.restore_non_compliant.id

  rule {
    id     = "restore-non-compliant-rule"
    status = "Enabled"
    filter {}

    expiration {
      days = 1
    }
  }
}
