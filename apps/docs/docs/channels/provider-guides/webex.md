---
title: Webex alerts
description: Configure Webex Kubernetes alerts with kwatch. Required settings include Bot access token; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Webex, notification channel]
---

# Webex alerts

Send kwatch incident alerts to **Webex**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `accessToken` — Bot access token.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `accessToken` | `string` | yes | yes | — | — | Bot access token |
| `roomId` | `string` | no | no | — | — | Room ID (provide this or `toPersonEmail`) |
| `toPersonEmail` | `string` | no | no | — | — | Person email (provide this or `roomId`) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  webex:
    accessToken: "${file:/config/webex-accessToken}"
    roomId: "your-room-id"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
