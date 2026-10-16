---
title: IFTTT alerts
description: Configure IFTTT Kubernetes alerts with kwatch. Required settings include Webhooks key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, IFTTT, notification channel]
---

# IFTTT alerts

Send kwatch incident alerts to **IFTTT**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `key` — Webhooks key.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `key` | `string` | yes | yes | — | — | Webhooks key |
| `event` | `string` | no | no | — | kwatch | Event name (default: kwatch) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  ifttt:
    key: "${file:/config/ifttt-key}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
