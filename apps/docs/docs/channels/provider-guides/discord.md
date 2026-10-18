---
title: Discord provider settings for kwatch Kubernetes alerts
sidebar_label: Discord alerts
description: Configure Discord Kubernetes alerts with kwatch. Required settings include Discord webhook URL; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Discord, notification channel]
---

# Discord alerts

Send kwatch incident alerts to **Discord**. Use the
[interactive manager](/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `webhook` — Discord webhook URL.

For a guided setup, use the [Discord channel guide](/channels/discord).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `webhook` | `string` | yes | yes | url | — | Discord webhook URL |
| `title` | `string` | no | no | — | — | Custom title |
| `text` | `string` | no | no | — | — | Custom text |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  discord:
    webhook: "${file:/config/discord-webhook}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/channels) for guidance, or the [complete provider reference](/channels/providers) for the catalog-wide view.

## Related

- [Set up Discord alerts step by step](/channels/discord)
- [All alert providers](/channels/providers) and [how channels work](/channels)
- [Configuration reference](/general-configuration) and [Troubleshoot missing or delayed alerts](/operations/troubleshooting)
