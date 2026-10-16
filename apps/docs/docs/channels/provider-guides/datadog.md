---
title: Datadog alerts
description: Configure Datadog Kubernetes alerts with kwatch. Required settings include API key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Datadog, notification channel]
---

# Datadog alerts

Send kwatch incident alerts to **Datadog**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `apiKey` — API key.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `apiKey` | `string` | yes | yes | — | — | API key |
| `site` | `string` | no | no | — | datadoghq.com | Datadog site (default: datadoghq.com) |
| `applicationKey` | `string` | no | yes | — | — | Optional application key |
| `title` | `string` | no | no | — | — | Custom title |
| `alertType` | `string` | no | no | — | error | Alert type (default: error) |
| `tags` | `list` | no | no | list | — | Comma-separated tags |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  datadog:
    apiKey: "${file:/config/datadog-apiKey}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
