---
title: SNS alerts
description: Configure SNS alerts with kwatch using the current provider catalog.
keywords: [kwatch, Kubernetes alerts, SNS, notification channel]
---

# SNS alerts

Use **SNS** when you want kwatch incidents delivered to this channel. This page is generated from the current provider catalog and lists every field accepted by the installed release.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `accessKeyId` | `string` | yes | yes | — | — | AWS access key ID |
| `secretAccessKey` | `string` | yes | yes | — | — | AWS secret access key |
| `region` | `string` | no | no | — | us-east-1 | AWS region (default: us-east-1) |
| `topicArn` | `string` | no | no | — | — | SNS topic ARN (or targetArn) |
| `targetArn` | `string` | no | no | — | — | SNS target ARN (alternative to topicArn). |
| `subject` | `string` | no | no | — | — | Optional subject (email subscriptions) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  sns:
    accessKeyId: "${file:/config/sns-accessKeyId}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
