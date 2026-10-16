---
title: GoAlert alerts
description: Configure GoAlert Kubernetes alerts with kwatch. Required settings include API token and Service ID; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, GoAlert, notification channel]
---

# GoAlert alerts

Send kwatch incident alerts to **GoAlert**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `token` — API token.
- `serviceId` — Service ID.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `url` | `string` | no | no | url | https://goalert.example.com | GoAlert URL (default: https://goalert.example.com) |
| `token` | `string` | yes | yes | — | — | API token |
| `serviceId` | `string` | yes | no | — | — | Service ID |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  goalert:
    token: "${file:/config/goalert-token}"
    serviceId: <serviceId>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
