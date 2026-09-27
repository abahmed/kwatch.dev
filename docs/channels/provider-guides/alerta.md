---
title: Alerta alerts
description: Configure Alerta Kubernetes alerts with kwatch. Required settings include Alerta server URL and API key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Alerta, notification channel]
---

# Alerta alerts

Send kwatch incident alerts to **Alerta**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `url` — Alerta server URL.
- `apiKey` — API key.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `url` | `string` | yes | no | url | — | Alerta server URL |
| `apiKey` | `string` | yes | yes | — | — | API key |
| `environment` | `string` | no | no | — | Production | Environment (default: Production) |
| `service` | `string` | no | no | — | kwatch | Service name (default: kwatch) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  alerta:
    url: <url>
    apiKey: "${file:/config/alerta-apiKey}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.

