---
title: Gotify alerts
description: Configure Gotify alerts with kwatch using the current provider catalog.
keywords: [kwatch, Kubernetes alerts, Gotify, notification channel]
---

# Gotify alerts

Use **Gotify** when you want kwatch incidents delivered to this channel. This page is generated from the current provider catalog and lists every field accepted by the installed release.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `url` | `string` | yes | no | url | — | Gotify server URL |
| `token` | `string` | yes | yes | — | — | App token |
| `priority` | `integer` | no | no | integer | — | Priority (optional) |
| `title` | `string` | no | no | — | — | Custom title |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  gotify:
    url: <url>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.

