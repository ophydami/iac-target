# SNS Remediation Outputs

output "sns_lambda_function_arn" {
  description = "ARN of the SNS remediation Lambda function"
  value       = aws_lambda_function.sns_remediation.arn
}

output "sns_lambda_function_name" {
  description = "Name of the SNS remediation Lambda function"
  value       = aws_lambda_function.sns_remediation.function_name
}

output "sns_lambda_role_arn" {
  description = "ARN of the SNS Lambda execution role"
  value       = aws_iam_role.sns_remediation_lambda.arn
}

# S3 Remediation Outputs

output "s3_lambda_function_arn" {
  description = "ARN of the S3 remediation Lambda function"
  value       = aws_lambda_function.s3_remediation.arn
}

output "s3_lambda_function_name" {
  description = "Name of the S3 remediation Lambda function"
  value       = aws_lambda_function.s3_remediation.function_name
}

output "s3_lambda_role_arn" {
  description = "ARN of the S3 Lambda execution role"
  value       = aws_iam_role.s3_remediation_lambda.arn
}

# CloudTrail Trigger Outputs

output "sns_create_trigger_rule_arn" {
  description = "ARN of the SNS CreateTopic EventBridge rule"
  value       = var.create_cloudtrail_triggers ? aws_cloudwatch_event_rule.sns_create[0].arn : null
}

output "s3_create_trigger_rule_arn" {
  description = "ARN of the S3 CreateBucket EventBridge rule"
  value       = var.create_cloudtrail_triggers ? aws_cloudwatch_event_rule.s3_create[0].arn : null
}
