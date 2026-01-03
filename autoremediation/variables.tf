variable "kms_key_alias" {
  description = "KMS key alias for SNS encryption"
  type        = string
  default     = "alias/aws/sns"
}

variable "repo_url" {
  description = "GitHub repository URL for IaC sync"
  type        = string
  default     = ""
}

variable "slack_channel" {
  description = "Slack channel for notifications"
  type        = string
  default     = "iac-alerts"
}

variable "event_bus_name" {
  description = "EventBridge event bus name"
  type        = string
  default     = "default"
}

variable "create_config_remediation" {
  description = "Create AWS Config remediation configuration"
  type        = bool
  default     = false
}

variable "config_rule_name" {
  description = "AWS Config rule name for SNS encryption check"
  type        = string
  default     = "sns-encrypted-kms"
}

variable "create_security_hub_trigger" {
  description = "Create Security Hub EventBridge trigger"
  type        = bool
  default     = true
}

# S3 Remediation Variables

variable "s3_encryption_algorithm" {
  description = "Encryption algorithm for S3 (AES256 or aws:kms)"
  type        = string
  default     = "AES256"
}

variable "s3_kms_key_id" {
  description = "KMS key ID for S3 encryption (required if using aws:kms)"
  type        = string
  default     = ""
}

variable "create_s3_config_remediation" {
  description = "Create AWS Config remediation configuration for S3"
  type        = bool
  default     = false
}

variable "s3_config_rule_name" {
  description = "AWS Config rule name for S3 encryption check"
  type        = string
  default     = "s3-bucket-server-side-encryption-enabled"
}

variable "create_s3_security_hub_trigger" {
  description = "Create Security Hub EventBridge trigger for S3"
  type        = bool
  default     = true
}

# CloudTrail Triggers
variable "create_cloudtrail_triggers" {
  description = "Create EventBridge rules to trigger remediation on resource creation (requires CloudTrail)"
  type        = bool
  default     = true
}
