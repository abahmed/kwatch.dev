---
title: Threema alerts
description: Configure Threema Kubernetes alerts with kwatch. Required settings include Threema Gateway ID and Gateway secret; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Threema, notification channel]
---

# Threema alerts

Send kwatch incident alerts to **Threema**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `gatewayId` — Threema Gateway ID.
- `secret` — Gateway secret.
- `to` — Recipient Threema ID.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `gatewayId` | `string` | yes | yes | — | — | Threema Gateway ID |
| `secret` | `string` | yes | yes | — | — | Gateway secret |
| `to` | `string` | yes | no | — | — | Recipient Threema ID |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  threema:
    gatewayId: "${file:/config/threema-gatewayId}"
    secret: "${file:/config/threema-secret}"
    to: <to>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
