"""
Lambda function to auto-remediate SNS topics without encryption.
Triggered by AWS Config rule or Security Hub finding.
"""

import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client('sns')
events_client = boto3.client('events')

# Default KMS key alias for SNS encryption
DEFAULT_KMS_KEY_ALIAS = os.environ.get('KMS_KEY_ALIAS', 'alias/aws/sns')


def lambda_handler(event, context):
    """
    Remediate SNS topics without encryption by enabling KMS encryption.

    Expected event formats:
    1. AWS Config remediation event
    2. Security Hub finding event
    3. Direct invocation with topic ARN
    """
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        topic_arn = extract_topic_arn(event)
        if not topic_arn:
            return {
                'statusCode': 400,
                'body': 'Could not extract SNS topic ARN from event'
            }

        # Get current topic attributes (before state)
        before_state = get_topic_attributes(topic_arn)

        # Enable encryption
        result = enable_encryption(topic_arn)

        # Get updated topic attributes (after state)
        after_state = get_topic_attributes(topic_arn)

        # Send event to EventBridge for IaC sync
        send_iac_sync_event(topic_arn, before_state, after_state)

        logger.info(f"Successfully enabled encryption for {topic_arn}")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Encryption enabled for {topic_arn}',
                'topic_arn': topic_arn,
                'kms_key': result.get('kms_key_id')
            })
        }

    except Exception as e:
        logger.error(f"Error remediating SNS topic: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }


def extract_topic_arn(event):
    """Extract SNS topic ARN from various event formats."""

    # Direct invocation
    if 'topic_arn' in event:
        return event['topic_arn']

    # CloudTrail CreateTopic event (via EventBridge input transformer)
    if event.get('source') == 'cloudtrail' and event.get('action') == 'CreateTopic':
        return event.get('topicArn')

    # AWS Config remediation event
    if 'resourceId' in event:
        resource_id = event['resourceId']
        if resource_id.startswith('arn:aws:sns:'):
            return resource_id
        # Construct ARN from resource ID (topic name)
        region = os.environ.get('AWS_REGION', 'us-east-1')
        account_id = boto3.client('sts').get_caller_identity()['Account']
        return f"arn:aws:sns:{region}:{account_id}:{resource_id}"

    # Security Hub finding
    if 'detail' in event and 'findings' in event.get('detail', {}):
        findings = event['detail']['findings']
        if findings:
            resources = findings[0].get('Resources', [])
            for resource in resources:
                if resource.get('Type') == 'AwsSnsTopic':
                    return resource.get('Id')

    # Config rule evaluation
    if 'invokingEvent' in event:
        invoking_event = json.loads(event['invokingEvent'])
        config_item = invoking_event.get('configurationItem', {})
        if config_item.get('resourceType') == 'AWS::SNS::Topic':
            return config_item.get('ARN')

    return None


def get_topic_attributes(topic_arn):
    """Get current SNS topic attributes."""
    try:
        response = sns_client.get_topic_attributes(TopicArn=topic_arn)
        return response.get('Attributes', {})
    except Exception as e:
        logger.warning(f"Could not get topic attributes: {str(e)}")
        return {}


def enable_encryption(topic_arn):
    """Enable KMS encryption on SNS topic."""

    # Get KMS key ID
    kms_key_id = get_kms_key_id()

    sns_client.set_topic_attributes(
        TopicArn=topic_arn,
        AttributeName='KmsMasterKeyId',
        AttributeValue=kms_key_id
    )

    logger.info(f"Enabled encryption with key {kms_key_id} for topic {topic_arn}")
    return {'kms_key_id': kms_key_id}


def get_kms_key_id():
    """Get KMS key ID for encryption."""
    kms_key_alias = os.environ.get('KMS_KEY_ALIAS', DEFAULT_KMS_KEY_ALIAS)

    # If using AWS managed key, return the alias directly
    if kms_key_alias == 'alias/aws/sns':
        return kms_key_alias

    # For custom keys, resolve the alias to key ID
    kms_client = boto3.client('kms')
    try:
        response = kms_client.describe_key(KeyId=kms_key_alias)
        return response['KeyMetadata']['KeyId']
    except Exception:
        logger.warning(f"Could not resolve KMS key alias {kms_key_alias}, using AWS managed key")
        return 'alias/aws/sns'


def send_iac_sync_event(topic_arn, before_state, after_state):
    """Send event to EventBridge for IaC sync agent."""

    topic_name = topic_arn.split(':')[-1]

    event_detail = {
        'resourceType': 'AWS::SNS::Topic',
        'resourceId': topic_name,
        'resourceArn': topic_arn,
        'action': 'EnableEncryption',
        'repoUrl': os.environ.get('REPO_URL', ''),
        'before': {
            'encryption': None,
            'kmsMasterKeyId': before_state.get('KmsMasterKeyId')
        },
        'after': {
            'encryption': {
                'kmsMasterKeyId': after_state.get('KmsMasterKeyId', 'alias/aws/sns')
            }
        },
        'slackChannel': os.environ.get('SLACK_CHANNEL', 'iac-alerts')
    }

    try:
        events_client.put_events(
            Entries=[
                {
                    'Source': 'custom.autoremediation',
                    'DetailType': 'SNS Topic Remediation',
                    'Detail': json.dumps(event_detail),
                    'EventBusName': os.environ.get('EVENT_BUS_NAME', 'default')
                }
            ]
        )
        logger.info(f"Sent IaC sync event for {topic_arn}")
    except Exception as e:
        logger.warning(f"Failed to send EventBridge event: {str(e)}")
