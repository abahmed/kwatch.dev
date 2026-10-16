---
title: MessageBird alerts
description: Configure MessageBird Kubernetes alerts with kwatch. Required settings include Access key and Sender number; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, MessageBird, notification channel]
---

# MessageBird alerts

Send kwatch incident alerts to **MessageBird**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `accessKey` — Access key.
- `from` — Sender number.
- `to` — Recipient phone number.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `accessKey` | `string` | yes | yes | — | — | Access key |
| `from` | `string` | yes | no | — | — | Sender number |
| `to` | `string` | yes | no | — | — | Recipient phone number |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  messagebird:
    accessKey: "${file:/config/messagebird-accessKey}"
    from: <from>
    to: <to>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
