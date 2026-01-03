terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# S3 Bucket
resource "aws_s3_bucket" "agentcore_test_bucket" {
  bucket = "agentcore-test-bucket"

  tags = {
    Name        = "AgentCore Test Bucket"
    Environment = var.environment
  }
}

# SNS Topic - Encryption enabled with AWS managed KMS key
# S3 Bucket Server Side Encryption Configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "agentcore_test_bucket_encryption" {
  bucket = aws_s3_bucket.agentcore_test_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# SNS Topic - No encryption configured
resource "aws_sns_topic" "notifications" {
  name              = var.sns_topic_name
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "IaC Sync Notifications"
    Environment = var.environment
  }
}