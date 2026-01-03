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