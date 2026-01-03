"""
EventBridge to AgentCore Forwarder

Receives auto-remediation events from EventBridge and forwards them
to the IaC Sync Agent running on AgentCore Runtime.
"""

import json
import os
import boto3
import urllib3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from botocore.credentials import Credentials

AGENT_RUNTIME_ENDPOINT = os.environ.get('AGENT_RUNTIME_ENDPOINT')
AGENT_ID = os.environ.get('AGENT_ID')
REPO_URL = os.environ.get('REPO_URL', 'https://github.com/ophydami/iac-target')
SLACK_CHANNEL = os.environ.get('SLACK_CHANNEL', 'iac-alerts')

http = urllib3.PoolManager()


def lambda_handler(event, context):
    """Process EventBridge event and forward to AgentCore."""
    print(f"Received event: {json.dumps(event)}")

    source = event.get('source', '')
    detail_type = event.get('detail-type', '')
    detail = event.get('detail', {})

    # Transform event to agent payload format
    payload = transform_event(source, detail_type, detail)

    if not payload:
        print("Event not relevant for IaC sync, skipping")
        return {'statusCode': 200, 'body': 'Skipped - not a remediation event'}

    print(f"Forwarding to AgentCore: {json.dumps(payload)}")

    try:
        result = invoke_agentcore(payload, context.aws_request_id)
        print(f"AgentCore response: {result}")
        return {'statusCode': 200, 'body': result}

    except Exception as e:
        print(f"Error invoking AgentCore: {e}")
        return {'statusCode': 500, 'body': str(e)}


def invoke_agentcore(payload: dict, session_id: str) -> str:
    """Invoke AgentCore Runtime using HTTP API."""

    if not AGENT_RUNTIME_ENDPOINT:
        raise ValueError("AGENT_RUNTIME_ENDPOINT not configured")

    # Prepare request
    url = f"{AGENT_RUNTIME_ENDPOINT}/invoke"
    body = json.dumps({
        "prompt": json.dumps(payload),
        "sessionId": session_id
    })

    # Sign request with SigV4
    session = boto3.Session()
    credentials = session.get_credentials()
    region = os.environ.get('AWS_REGION', 'us-east-1')

    request = AWSRequest(
        method='POST',
        url=url,
        data=body,
        headers={'Content-Type': 'application/json'}
    )

    SigV4Auth(credentials, 'bedrock-agentcore', region).add_auth(request)

    # Make request
    response = http.request(
        'POST',
        url,
        body=body,
        headers=dict(request.headers)
    )

    return response.data.decode('utf-8')


def transform_event(source: str, detail_type: str, detail: dict) -> dict | None:
    """Transform EventBridge event to agent payload format."""

    # Custom auto-remediation events (from our remediation Lambdas)
    if source == 'aws.autoremediation':
        return {
            'resourceType': detail.get('resourceType', ''),
            'resourceId': detail.get('resourceId', ''),
            'action': detail.get('action', ''),
            'repoUrl': detail.get('repoUrl') or REPO_URL,
            'before': detail.get('before', {}),
            'after': detail.get('after', {}),
            'slackChannel': detail.get('slackChannel') or SLACK_CHANNEL
        }

    # AWS Config compliance change
    if source == 'aws.config' and 'Config Rules Compliance Change' in detail_type:
        resource_type = detail.get('resourceType', '')
        resource_id = detail.get('resourceId', '')
        rule_name = detail.get('configRuleName', '')
        compliance = detail.get('newEvaluationResult', {}).get('complianceType', '')

        # Only process if now compliant (remediated)
        if compliance != 'COMPLIANT':
            return None

        action = get_action_from_rule(rule_name)

        return {
            'resourceType': resource_type,
            'resourceId': resource_id,
            'action': action,
            'repoUrl': REPO_URL,
            'before': {'compliant': False},
            'after': {'compliant': True, 'rule': rule_name},
            'slackChannel': SLACK_CHANNEL
        }

    # Security Hub findings
    if source == 'aws.securityhub':
        findings = detail.get('findings', [])
        if not findings:
            return None

        finding = findings[0]
        resources = finding.get('Resources', [])
        if not resources:
            return None

        resource = resources[0]
        workflow_status = finding.get('Workflow', {}).get('Status', '')

        # Only process resolved findings
        if workflow_status != 'RESOLVED':
            return None

        return {
            'resourceType': resource.get('Type', ''),
            'resourceId': resource.get('Id', '').split('/')[-1],
            'action': finding.get('Title', 'SecurityHubRemediation'),
            'repoUrl': REPO_URL,
            'before': {'status': 'FAILED'},
            'after': {'status': 'PASSED'},
            'slackChannel': SLACK_CHANNEL
        }

    return None


def get_action_from_rule(rule_name: str) -> str:
    """Map Config rule name to remediation action."""
    rule_actions = {
        's3-bucket-server-side-encryption-enabled': 'EnableDefaultEncryption',
        's3-bucket-ssl-requests-only': 'EnableSSLOnly',
        's3-bucket-versioning-enabled': 'EnableVersioning',
        's3-bucket-public-read-prohibited': 'BlockPublicAccess',
        's3-bucket-public-write-prohibited': 'BlockPublicAccess',
        'sns-encrypted-kms': 'EnableEncryption',
        'encrypted-volumes': 'EnableEBSEncryption',
        'rds-storage-encrypted': 'EnableRDSEncryption',
    }
    return rule_actions.get(rule_name, f'Remediate_{rule_name}')
