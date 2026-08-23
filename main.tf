# Y62 Infrastructure for storage compliance

# Divided by category purely for organization. Each category can have a mixture of CRs.
module "backup" {
  source = "./backup"
}
module "ec2" {
  source = "./ec2"
}
module "efs" {
  source = "./efs"
}
module "fsx" {
  source = "./fsx"
}
module "s3" {
  source = "./s3"
}

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
  region = "us-east-1"
}

