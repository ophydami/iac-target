# Outputs

output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.notifications.arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.iac_sync_trigger.arn
}

output "forwarder_lambda_arn" {
  description = "ARN of the forwarder Lambda function"
  value       = aws_lambda_function.agentcore_forwarder.arn
}

output "forwarder_lambda_name" {
  description = "Name of the forwarder Lambda function"
  value       = aws_lambda_function.agentcore_forwarder.function_name
}
