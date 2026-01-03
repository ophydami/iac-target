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

# SNS Topic - No encryption configured
resource "aws_sns_topic" "notifications" {
  name = var.sns_topic_name

  tags = {
    Name        = "IaC Sync Notifications"
    Environment = var.environment
  }
}
