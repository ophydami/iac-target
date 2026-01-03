# S3 Encryption Auto-Remediation Lambda

# Lambda IAM Role
resource "aws_iam_role" "s3_remediation_lambda" {
  name = "s3-encryption-remediation-lambda-role"

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
resource "aws_iam_role_policy" "s3_remediation_lambda" {
  name = "s3-encryption-remediation-policy"
  role = aws_iam_role.s3_remediation_lambda.id

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
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration"
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
data "archive_file" "s3_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/s3_encryption_remediation.py"
  output_path = "${path.module}/s3_lambda.zip"
}

resource "aws_lambda_function" "s3_remediation" {
  filename         = data.archive_file.s3_lambda_zip.output_path
  function_name    = "s3-encryption-remediation"
  role             = aws_iam_role.s3_remediation_lambda.arn
  handler          = "s3_encryption_remediation.lambda_handler"
  source_code_hash = data.archive_file.s3_lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      ENCRYPTION_ALGORITHM = var.s3_encryption_algorithm
      KMS_KEY_ID           = var.s3_kms_key_id
      REPO_URL             = var.repo_url
      SLACK_CHANNEL        = var.slack_channel
      EVENT_BUS_NAME       = var.event_bus_name
    }
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "s3_remediation" {
  name              = "/aws/lambda/${aws_lambda_function.s3_remediation.function_name}"
  retention_in_days = 14
}

# AWS Config Remediation Configuration
resource "aws_config_remediation_configuration" "s3_encryption" {
  count = var.create_s3_config_remediation ? 1 : 0

  config_rule_name = var.s3_config_rule_name
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWS-InvokeLambdaFunction"

  parameter {
    name         = "FunctionName"
    static_value = aws_lambda_function.s3_remediation.arn
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
resource "aws_cloudwatch_event_rule" "security_hub_s3" {
  count = var.create_s3_security_hub_trigger ? 1 : 0

  name        = "s3-encryption-security-hub-trigger"
  description = "Trigger S3 encryption remediation from Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        ProductFields = {
          "ControlId" = ["S3.4"]
        }
        Compliance = {
          Status = ["FAILED"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "security_hub_s3" {
  count = var.create_s3_security_hub_trigger ? 1 : 0

  rule      = aws_cloudwatch_event_rule.security_hub_s3[0].name
  target_id = "s3-encryption-remediation"
  arn       = aws_lambda_function.s3_remediation.arn
}

resource "aws_lambda_permission" "security_hub_s3" {
  count = var.create_s3_security_hub_trigger ? 1 : 0

  statement_id  = "AllowSecurityHubTrigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_hub_s3[0].arn
}
