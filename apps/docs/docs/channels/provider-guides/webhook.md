---
title: Generic Webhook alerts
description: Configure Generic Webhook Kubernetes alerts with kwatch. Required settings include Webhook URL; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Generic Webhook, notification channel]
---

# Generic Webhook alerts

Send kwatch incident alerts to **Generic Webhook**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `url` — Webhook URL.

For a guided setup, use the [Generic Webhook channel guide](/docs/channels/webhook).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `url` | `string` | yes | yes | url | — | Webhook URL |
| `headers` | `headers` | no | no | — | — | Custom headers |
| `basicAuth.username` | `string` | no | no | — | — | Basic-auth username. |
| `basicAuth.password` | `string` | no | yes | — | — | Basic-auth password. |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  webhook:
    url: "${file:/config/webhook-url}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
