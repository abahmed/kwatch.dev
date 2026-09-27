---
title: SES alerts
description: Configure SES Kubernetes alerts with kwatch. Required settings include AWS access key ID and AWS secret access key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, SES, notification channel]
---

# SES alerts

Send kwatch incident alerts to **SES**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `accessKeyId` — AWS access key ID.
- `secretAccessKey` — AWS secret access key.
- `from` — Verified sender address.
- `to` — Recipients (comma-separated).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `accessKeyId` | `string` | yes | yes | — | — | AWS access key ID |
| `secretAccessKey` | `string` | yes | yes | — | — | AWS secret access key |
| `region` | `string` | no | no | — | us-east-1 | AWS region (default: us-east-1) |
| `from` | `string` | yes | no | — | — | Verified sender address |
| `to` | `string` | yes | no | — | — | Recipients (comma-separated) |
| `subject` | `string` | no | no | — | — | Email subject |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  ses:
    accessKeyId: "${file:/config/ses-accessKeyId}"
    secretAccessKey: "${file:/config/ses-secretAccessKey}"
    from: <from>
    to: <to>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
