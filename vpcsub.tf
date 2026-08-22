# --- Minimal VPC ---
resource "aws_vpc" "compliance_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "fsx-compliance-vpc"
  }
}

# --- Single Subnet for FSx Single-AZ ---
resource "aws_subnet" "compliance_subnet" {
  vpc_id            = aws_vpc.compliance_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "fsx-compliance-subnet"
  }
}

# --- Minimal Security Group for FSx ---
resource "aws_security_group" "fsx_sg" {
  name        = "fsx-compliance-sg"
  description = "Security group for compliance testing FSx OpenZFS"
  vpc_id      = aws_vpc.compliance_vpc.id

  # Allow all outbound traffic (default standard)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fsx-compliance-sg"
  }
}
