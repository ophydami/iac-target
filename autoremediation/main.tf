# SNS Encryption Auto-Remediation Lambda

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda IAM Role
resource "aws_iam_role" "sns_remediation_lambda" {
  name = "sns-encryption-remediation-lambda-role"

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
}

# Lambda IAM Policy
resource "aws_iam_role_policy" "sns_remediation_lambda" {
  name = "sns-encryption-remediation-policy"
  role = aws_iam_role.sns_remediation_lambda.id

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
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/sns_encryption_remediation.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "sns_remediation" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "sns-encryption-remediation"
  role             = aws_iam_role.sns_remediation_lambda.arn
  handler          = "sns_encryption_remediation.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      KMS_KEY_ALIAS  = var.kms_key_alias
      REPO_URL       = var.repo_url
      SLACK_CHANNEL  = var.slack_channel
      EVENT_BUS_NAME = var.event_bus_name
    }
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "sns_remediation" {
  name              = "/aws/lambda/${aws_lambda_function.sns_remediation.function_name}"
  retention_in_days = 14
}

# AWS Config Remediation Configuration
resource "aws_config_remediation_configuration" "sns_encryption" {
  count = var.create_config_remediation ? 1 : 0

  config_rule_name = var.config_rule_name
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWS-InvokeLambdaFunction"

  parameter {
    name         = "FunctionName"
    static_value = aws_lambda_function.sns_remediation.arn
  }

  parameter {
    name           = "Payload"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# EventBridge Rule for Security Hub findings
resource "aws_cloudwatch_event_rule" "security_hub_sns" {
  count = var.create_security_hub_trigger ? 1 : 0

  name        = "sns-encryption-security-hub-trigger"
  description = "Trigger SNS encryption remediation from Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        ProductFields = {
          "ControlId" = ["SNS.1"]
        }
        Compliance = {
          Status = ["FAILED"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "security_hub_sns" {
  count = var.create_security_hub_trigger ? 1 : 0

  rule      = aws_cloudwatch_event_rule.security_hub_sns[0].name
  target_id = "sns-encryption-remediation"
  arn       = aws_lambda_function.sns_remediation.arn
}

resource "aws_lambda_permission" "security_hub" {
  count = var.create_security_hub_trigger ? 1 : 0

  statement_id  = "AllowSecurityHubTrigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_hub_sns[0].arn
}
