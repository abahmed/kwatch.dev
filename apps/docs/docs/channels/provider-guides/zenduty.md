---
title: Zenduty alerts
description: Configure Zenduty Kubernetes alerts with kwatch. Required settings include Integration Key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Zenduty, notification channel]
---

# Zenduty alerts

Send kwatch incident alerts to **Zenduty**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `integrationKey` — Integration Key.

For a guided setup, use the [Zenduty channel guide](/docs/channels/zenduty).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `integrationKey` | `string` | yes | yes | — | — | Integration Key |
| `alertType` | `string` | no | no | — | critical | Alert type (default: critical) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  zenduty:
    integrationKey: "${file:/config/zenduty-integrationKey}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
