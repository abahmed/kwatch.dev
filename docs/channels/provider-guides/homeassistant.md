---
title: Home Assistant alerts
description: Configure Home Assistant Kubernetes alerts with kwatch. Required settings include Long-lived access token; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Home Assistant, notification channel]
---

# Home Assistant alerts

Send kwatch incident alerts to **Home Assistant**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `token` — Long-lived access token.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `token` | `string` | yes | yes | — | — | Long-lived access token |
| `url` | `string` | no | no | url | http://localhost:8123 | Server URL (default: http://localhost:8123) |
| `service` | `string` | no | no | — | notify | Notification service (default: notify) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  homeassistant:
    token: "${file:/config/homeassistant-token}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
