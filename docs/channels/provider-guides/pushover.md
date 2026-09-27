---
title: Pushover alerts
description: Configure Pushover Kubernetes alerts with kwatch. Required settings include Application token and User or group key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Pushover, notification channel]
---

# Pushover alerts

Send kwatch incident alerts to **Pushover**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `token` — Application token.
- `user` — User or group key.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `token` | `string` | yes | yes | — | — | Application token |
| `user` | `string` | yes | yes | — | — | User or group key |
| `priority` | `integer` | no | no | integer | — | Priority (optional) |
| `title` | `string` | no | no | — | — | Custom title |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  pushover:
    token: "${file:/config/pushover-token}"
    user: "${file:/config/pushover-user}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
