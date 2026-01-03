terraform {
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

resource "aws_s3_bucket" "agentcore_test_bucket" {
  bucket = "agentcore-test-bucket"

  tags = {
    Name        = "AgentCore Test Bucket"
    Environment = "test"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "agentcore_test_bucket_encryption" {
  bucket = aws_s3_bucket.agentcore_test_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}