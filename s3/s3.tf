
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
