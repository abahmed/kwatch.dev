---
title: SensiGo alerts
description: Configure SensiGo Kubernetes alerts with kwatch. Required settings include Sensu Go API URL and API key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, SensiGo, notification channel]
---

# SensiGo alerts

Send kwatch incident alerts to **SensiGo**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `url` — Sensu Go API URL.
- `apiKey` — API key.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `url` | `string` | yes | no | url | — | Sensu Go API URL |
| `apiKey` | `string` | yes | yes | — | — | API key |
| `namespace` | `string` | no | no | — | default | Namespace (default: default) |
| `entity` | `string` | no | no | — | kwatch | Entity name (default: kwatch) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  sensugo:
    url: <url>
    apiKey: "${file:/config/sensugo-apiKey}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.

