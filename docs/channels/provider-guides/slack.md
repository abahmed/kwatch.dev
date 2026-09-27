---
title: Slack alerts
description: Configure Slack Kubernetes alerts with kwatch. Choose a webhook or bot token, then review Secret handling, routing, and retries.
keywords: [kwatch, Kubernetes alerts, Slack, notification channel]
---

# Slack alerts

Send kwatch incident alerts to **Slack**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start:** choose a webhook URL, or a bot token and channel.

For a guided setup, use the [Slack channel guide](/docs/channels/slack).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `webhook` | `string` | no | yes | url | — | Slack webhook URL |
| `channel` | `string` | no | no | — | — | Override channel |
| `title` | `string` | no | no | — | — | Custom title |
| `text` | `string` | no | no | — | — | Custom text |
| `compact` | `boolean` | no | no | boolean | false | Single-line mode |
| `token` | `string` | no | yes | — | — | Bot token (xoxb-...) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
