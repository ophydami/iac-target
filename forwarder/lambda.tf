# Lambda Function - Forwards EventBridge events to AgentCore

# IAM Role for Lambda
resource "aws_iam_role" "agentcore_forwarder" {
  name = "iac-sync-agentcore-forwarder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "IaC Sync AgentCore Forwarder Role"
    Environment = var.environment
  }
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "agentcore_forwarder" {
  name = "iac-sync-agentcore-forwarder-policy"
  role = aws_iam_role.agentcore_forwarder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:InvokeAgentRuntime"
        ]
        Resource = var.agentcore_runtime_arn
      }
    ]
  })
}

# Package Lambda code
data "archive_file" "forwarder_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/forwarder.py"
  output_path = "${path.module}/lambda/forwarder.zip"
}

# Lambda Function
resource "aws_lambda_function" "agentcore_forwarder" {
  filename         = data.archive_file.forwarder_zip.output_path
  function_name    = "iac-sync-agentcore-forwarder"
  role             = aws_iam_role.agentcore_forwarder.arn
  handler          = "forwarder.lambda_handler"
  source_code_hash = data.archive_file.forwarder_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 256

  environment {
    variables = {
      AGENT_RUNTIME_ENDPOINT = var.agentcore_runtime_endpoint
      AGENT_ID               = var.agentcore_agent_id
      REPO_URL               = var.repo_url
      SLACK_CHANNEL          = var.slack_channel
    }
  }

  tags = {
    Name        = "IaC Sync AgentCore Forwarder"
    Environment = var.environment
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "agentcore_forwarder" {
  name              = "/aws/lambda/${aws_lambda_function.agentcore_forwarder.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "IaC Sync AgentCore Forwarder Logs"
    Environment = var.environment
  }
}
