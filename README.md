# IaC Target - Terraform Infrastructure

Infrastructure as Code target repository for auto-remediation sync.

## Architecture

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│  Security Hub /     │────▶│  Auto-Remediation   │────▶│    EventBridge      │
│  AWS Config         │     │  Lambda             │     │                     │
└─────────────────────┘     └─────────────────────┘     └──────────┬──────────┘
                                                                   │
                                                                   ▼
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│     GitHub PR       │◀────│  AgentCore Runtime  │◀────│  Forwarder Lambda   │
│   (Terraform Fix)   │     │  (IaC Sync Agent)   │     │                     │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
```

## Resources

### Infrastructure (main.tf)
- **S3 Bucket**: `agentcore-test-bucket` - Test bucket for S3 encryption remediation
- **SNS Topic**: `iac-sync-notifications` - Test topic for SNS encryption remediation

### EventBridge Integration (eventbridge.tf)
- **Event Rule**: Captures remediation events from:
  - `aws.autoremediation` - Custom remediation Lambdas
  - `aws.config` - AWS Config compliance changes
  - `aws.securityhub` - Security Hub findings

### Forwarder Lambda (lambda.tf)
- **Function**: Transforms EventBridge events and forwards to AgentCore Runtime
- **Triggers**: EventBridge rule for remediation events

## File Structure

```
terraform/
├── main.tf           # Core resources (S3, SNS)
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── eventbridge.tf    # EventBridge rules and targets
├── lambda.tf         # Forwarder Lambda function
├── lambda/
│   └── forwarder.py  # Lambda code to invoke AgentCore
└── README.md
```

## Usage

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `environment` | Environment name | `test` |
| `region` | AWS region | `us-east-1` |
| `agentcore_runtime_arn` | AgentCore Runtime ARN | (set) |
| `repo_url` | GitHub repo for Terraform | `https://github.com/ophydami/iac-target` |
| `slack_channel` | Slack notification channel | `iac-alerts` |

## Flow

1. **Compliance Violation Detected** - AWS Config or Security Hub detects non-compliant resource
2. **Auto-Remediation Runs** - Remediation Lambda fixes the resource (e.g., enables encryption)
3. **Event Published** - Remediation Lambda publishes event to EventBridge
4. **Forwarder Triggered** - EventBridge invokes forwarder Lambda
5. **AgentCore Invoked** - Forwarder calls IaC Sync Agent on AgentCore Runtime
6. **PR Created** - Agent updates Terraform and creates PR
7. **Slack Notification** - Team notified with PR link
