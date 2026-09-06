---
title: ntfy alerts
description: Configure ntfy alerts with kwatch using the current provider catalog.
keywords: [kwatch, Kubernetes alerts, ntfy, notification channel]
---

# ntfy alerts

Use **ntfy** when you want kwatch incidents delivered to this channel. This page is generated from the current provider catalog and lists every field accepted by the installed release.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `topic` | `string` | yes | yes | — | — | Topic to publish to |
| `url` | `string` | no | no | url | https://ntfy.sh | Server URL (default: https://ntfy.sh) |
| `token` | `string` | no | yes | — | — | Optional auth token |
| `title` | `string` | no | no | — | — | Custom title |
| `priority` | `integer` | no | no | integer | 4 | Priority 1-5 (default: 4) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  ntfy:
    topic: "${file:/config/ntfy-topic}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
