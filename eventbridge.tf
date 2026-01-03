# EventBridge Rule - Captures auto-remediation events and forwards to AgentCore
resource "aws_cloudwatch_event_rule" "iac_sync_trigger" {
  name        = "iac-sync-agentcore-trigger"
  description = "Capture remediation events and forward to IaC Sync Agent"

  event_pattern = jsonencode({
    source = [
      "aws.autoremediation",
      "aws.config",
      "aws.securityhub"
    ]
    detail-type = [
      "SNS Topic Remediation",
      "S3 Bucket Remediation",
      "Config Rules Compliance Change",
      "Security Hub Findings - Imported"
    ]
  })

  tags = {
    Name        = "IaC Sync AgentCore Trigger"
    Environment = var.environment
  }
}

# EventBridge Target - Invokes the forwarder Lambda
resource "aws_cloudwatch_event_target" "agentcore_forwarder" {
  rule      = aws_cloudwatch_event_rule.iac_sync_trigger.name
  target_id = "iac-sync-agentcore-forwarder"
  arn       = aws_lambda_function.agentcore_forwarder.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.agentcore_forwarder.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.iac_sync_trigger.arn
}
