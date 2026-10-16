---
title: Signal alerts
description: Configure Signal Kubernetes alerts with kwatch. Required settings include Sender phone number and Recipient phone number; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Signal, notification channel]
---

# Signal alerts

Send kwatch incident alerts to **Signal**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `number` — Sender phone number.
- `to` — Recipient phone number.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `number` | `string` | yes | no | — | — | Sender phone number |
| `to` | `string` | yes | no | — | — | Recipient phone number |
| `url` | `string` | no | no | url | http://localhost:8080 | REST API URL (default: http://localhost:8080) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  signal:
    number: <number>
    to: <to>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.

