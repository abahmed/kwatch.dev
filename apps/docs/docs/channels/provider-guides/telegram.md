---
title: Telegram alerts
description: Configure Telegram Kubernetes alerts with kwatch. Required settings include Bot token and Chat ID; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Telegram, notification channel]
---

# Telegram alerts

Send kwatch incident alerts to **Telegram**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `token` — Bot token.
- `chatId` — Chat ID.

For a guided setup, use the [Telegram channel guide](/docs/channels/telegram).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `token` | `string` | yes | yes | — | — | Bot token |
| `chatId` | `string` | yes | no | signed-integer | — | Chat ID |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  telegram:
    token: "${file:/config/telegram-token}"
    chatId: <chatId>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
