---
title: SNS alerts
description: Configure SNS Kubernetes alerts with kwatch. Required settings include AWS access key ID and AWS secret access key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, SNS, notification channel]
---

# SNS alerts

Send kwatch incident alerts to **SNS**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `accessKeyId` — AWS access key ID.
- `secretAccessKey` — AWS secret access key.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

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
    secretAccessKey: "${file:/config/sns-secretAccessKey}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
