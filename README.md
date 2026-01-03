# IaC Target

Target Terraform infrastructure for the IaC Sync Agent demo.

This repo contains sample AWS resources that get auto-remediated and synced by the [IaC Sync Agent](https://github.com/ophydami/iac-sync-agent).

## Resources

- **S3 Bucket** - Test bucket with server-side encryption
- **SNS Topic** - Notification topic with KMS encryption

## How It Works

1. Resources are created without encryption
2. Auto-remediation enables encryption on AWS
3. IaC Sync Agent detects the change
4. Agent creates a PR to update this Terraform code
5. Code stays in sync with actual AWS state

## Usage

```bash
terraform init
terraform apply
```

## Related

- [IaC Sync Agent](https://github.com/ophydami/iac-sync-agent) - The agent that syncs this code
