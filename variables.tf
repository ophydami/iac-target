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

# SNS Topic
variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
  default     = "iac-sync-notifications"
}

# AgentCore Configuration
variable "agentcore_runtime_arn" {
  description = "ARN of the AgentCore Runtime"
  type        = string
  default     = "arn:aws:bedrock-agentcore:us-east-1:870505369167:runtime/iac_sync_agent-ZQT04L9kzR"
}

variable "agentcore_runtime_endpoint" {
  description = "HTTP endpoint for AgentCore Runtime"
  type        = string
  default     = "https://bedrock-agentcore.us-east-1.amazonaws.com/runtimes/iac_sync_agent-ZQT04L9kzR"
}

variable "agentcore_agent_id" {
  description = "AgentCore Agent ID"
  type        = string
  default     = "iac_sync_agent-ZQT04L9kzR"
}

# IaC Sync Configuration
variable "repo_url" {
  description = "GitHub repository URL for Terraform code"
  type        = string
  default     = "https://github.com/ophydami/iac-target"
}

variable "slack_channel" {
  description = "Slack channel for notifications"
  type        = string
  default     = "iac-alerts"
}
