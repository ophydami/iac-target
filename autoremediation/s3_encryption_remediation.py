"""
Lambda function to auto-remediate S3 buckets without encryption.
Triggered by AWS Config rule or Security Hub finding.
"""

import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
events_client = boto3.client('events')

# Default encryption algorithm
DEFAULT_ENCRYPTION_ALGORITHM = os.environ.get('ENCRYPTION_ALGORITHM', 'AES256')


def lambda_handler(event, context):
    """
    Remediate S3 buckets without encryption by enabling default encryption.

    Expected event formats:
    1. AWS Config remediation event
    2. Security Hub finding event
    3. Direct invocation with bucket name
    """
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        bucket_name = extract_bucket_name(event)
        if not bucket_name:
            return {
                'statusCode': 400,
                'body': 'Could not extract S3 bucket name from event'
            }

        # Get current bucket encryption (before state)
        before_state = get_bucket_encryption(bucket_name)

        # Enable encryption
        result = enable_encryption(bucket_name)

        # Get updated bucket encryption (after state)
        after_state = get_bucket_encryption(bucket_name)

        # Send event to EventBridge for IaC sync
        send_iac_sync_event(bucket_name, before_state, after_state)

        logger.info(f"Successfully enabled encryption for {bucket_name}")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Encryption enabled for {bucket_name}',
                'bucket': bucket_name,
                'encryption': result
            })
        }

    except Exception as e:
        logger.error(f"Error remediating S3 bucket: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }


def extract_bucket_name(event):
    """Extract S3 bucket name from various event formats."""

    # Direct invocation
    if 'bucket_name' in event:
        return event['bucket_name']

    # CloudTrail CreateBucket event (via EventBridge input transformer)
    if event.get('source') == 'cloudtrail' and event.get('action') == 'CreateBucket':
        return event.get('bucketName')

    # AWS Config remediation event
    if 'resourceId' in event:
        return event['resourceId']

    # Security Hub finding
    if 'detail' in event and 'findings' in event.get('detail', {}):
        findings = event['detail']['findings']
        if findings:
            resources = findings[0].get('Resources', [])
            for resource in resources:
                if resource.get('Type') == 'AwsS3Bucket':
                    # Extract bucket name from ARN or Id
                    resource_id = resource.get('Id', '')
                    if resource_id.startswith('arn:aws:s3:::'):
                        return resource_id.replace('arn:aws:s3:::', '')
                    return resource_id

    # Config rule evaluation
    if 'invokingEvent' in event:
        invoking_event = json.loads(event['invokingEvent'])
        config_item = invoking_event.get('configurationItem', {})
        if config_item.get('resourceType') == 'AWS::S3::Bucket':
            return config_item.get('resourceName')

    return None


def get_bucket_encryption(bucket_name):
    """Get current S3 bucket encryption configuration."""
    try:
        response = s3_client.get_bucket_encryption(Bucket=bucket_name)
        rules = response.get('ServerSideEncryptionConfiguration', {}).get('Rules', [])
        if rules:
            return rules[0].get('ApplyServerSideEncryptionByDefault', {})
        return {}
    except s3_client.exceptions.ClientError as e:
        if e.response['Error']['Code'] == 'ServerSideEncryptionConfigurationNotFoundError':
            return None
        raise


def enable_encryption(bucket_name):
    """Enable default encryption on S3 bucket."""

    encryption_algorithm = os.environ.get('ENCRYPTION_ALGORITHM', DEFAULT_ENCRYPTION_ALGORITHM)
    kms_key_id = os.environ.get('KMS_KEY_ID')

    encryption_config = {
        'SSEAlgorithm': encryption_algorithm
    }

    # If using KMS, add the key ID
    if encryption_algorithm == 'aws:kms' and kms_key_id:
        encryption_config['KMSMasterKeyID'] = kms_key_id

    s3_client.put_bucket_encryption(
        Bucket=bucket_name,
        ServerSideEncryptionConfiguration={
            'Rules': [
                {
                    'ApplyServerSideEncryptionByDefault': encryption_config,
                    'BucketKeyEnabled': encryption_algorithm == 'aws:kms'
                }
            ]
        }
    )

    logger.info(f"Enabled {encryption_algorithm} encryption for bucket {bucket_name}")
    return encryption_config


def send_iac_sync_event(bucket_name, before_state, after_state):
    """Send event to EventBridge for IaC sync agent."""

    region = os.environ.get('AWS_REGION', 'us-east-1')
    account_id = boto3.client('sts').get_caller_identity()['Account']
    bucket_arn = f"arn:aws:s3:::{bucket_name}"

    event_detail = {
        'resourceType': 'AWS::S3::Bucket',
        'resourceId': bucket_name,
        'resourceArn': bucket_arn,
        'action': 'EnableDefaultEncryption',
        'repoUrl': os.environ.get('REPO_URL', ''),
        'before': {
            'encryption': before_state
        },
        'after': {
            'encryption': after_state
        },
        'slackChannel': os.environ.get('SLACK_CHANNEL', 'iac-alerts')
    }

    try:
        events_client.put_events(
            Entries=[
                {
                    'Source': 'custom.autoremediation',
                    'DetailType': 'S3 Bucket Remediation',
                    'Detail': json.dumps(event_detail),
                    'EventBusName': os.environ.get('EVENT_BUS_NAME', 'default')
                }
            ]
        )
        logger.info(f"Sent IaC sync event for {bucket_name}")
    except Exception as e:
        logger.warning(f"Failed to send EventBridge event: {str(e)}")
