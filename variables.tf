variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
  default     = "iac-sync-notifications"
}
