---
title: Zulip alerts
description: Configure Zulip Kubernetes alerts with kwatch. Required settings include Bot email and Bot API key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Zulip, notification channel]
---

# Zulip alerts

Send kwatch incident alerts to **Zulip**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `email` — Bot email.
- `token` — Bot API key.
- `channel` — Channel/stream to post to.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `email` | `string` | yes | no | — | — | Bot email |
| `token` | `string` | yes | yes | — | — | Bot API key |
| `channel` | `string` | yes | no | — | — | Channel/stream to post to |
| `url` | `string` | no | no | url | https://zulip.example.com/api/v1/messages | Server URL (default: https://zulip.example.com/api/v1/messages) |
| `title` | `string` | no | no | — | — | Custom title |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  zulip:
    email: <email>
    token: "${file:/config/zulip-token}"
    channel: <channel>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.

