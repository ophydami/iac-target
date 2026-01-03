# EventBridge Rules for CloudTrail - Trigger remediation on resource creation

# ============================================================================
# SNS Topic Creation Trigger
# ============================================================================

resource "aws_cloudwatch_event_rule" "sns_create" {
  count = var.create_cloudtrail_triggers ? 1 : 0

  name        = "sns-create-trigger-remediation"
  description = "Trigger SNS encryption remediation when a new topic is created"

  event_pattern = jsonencode({
    source      = ["aws.sns"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["sns.amazonaws.com"]
      eventName   = ["CreateTopic"]
    }
  })

  tags = {
    Name    = "SNS Create Remediation Trigger"
    Purpose = "Auto-remediation"
  }
}

resource "aws_cloudwatch_event_target" "sns_create" {
  count = var.create_cloudtrail_triggers ? 1 : 0

  rule      = aws_cloudwatch_event_rule.sns_create[0].name
  target_id = "sns-encryption-remediation"
  arn       = aws_lambda_function.sns_remediation.arn

  # Transform the CloudTrail event to extract topic ARN
  input_transformer {
    input_paths = {
      topicArn  = "$.detail.responseElements.topicArn"
      eventTime = "$.detail.eventTime"
      region    = "$.detail.awsRegion"
      account   = "$.detail.userIdentity.accountId"
    }
    input_template = <<EOF
{
  "source": "cloudtrail",
  "action": "CreateTopic",
  "topicArn": <topicArn>,
  "eventTime": <eventTime>,
  "region": <region>,
  "account": <account>
}
EOF
  }
}

resource "aws_lambda_permission" "sns_create" {
  count = var.create_cloudtrail_triggers ? 1 : 0

  statement_id  = "AllowCloudTrailSNSCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sns_create[0].arn
}

# ============================================================================
# S3 Bucket Creation Trigger
# ============================================================================

resource "aws_cloudwatch_event_rule" "s3_create" {
  count = var.create_cloudtrail_triggers ? 1 : 0

  name        = "s3-create-trigger-remediation"
  description = "Trigger S3 encryption remediation when a new bucket is created"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName   = ["CreateBucket"]
    }
  })

  tags = {
    Name    = "S3 Create Remediation Trigger"
    Purpose = "Auto-remediation"
  }
}

resource "aws_cloudwatch_event_target" "s3_create" {
  count = var.create_cloudtrail_triggers ? 1 : 0

  rule      = aws_cloudwatch_event_rule.s3_create[0].name
  target_id = "s3-encryption-remediation"
  arn       = aws_lambda_function.s3_remediation.arn

  # Transform the CloudTrail event to extract bucket name
  input_transformer {
    input_paths = {
      bucketName = "$.detail.requestParameters.bucketName"
      eventTime  = "$.detail.eventTime"
      region     = "$.detail.awsRegion"
      account    = "$.detail.userIdentity.accountId"
    }
    input_template = <<EOF
{
  "source": "cloudtrail",
  "action": "CreateBucket",
  "bucketName": <bucketName>,
  "eventTime": <eventTime>,
  "region": <region>,
  "account": <account>
}
EOF
  }
}

resource "aws_lambda_permission" "s3_create" {
  count = var.create_cloudtrail_triggers ? 1 : 0

  statement_id  = "AllowCloudTrailS3Create"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_create[0].arn
}
