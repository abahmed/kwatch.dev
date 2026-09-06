---
title: SIGNL4 alerts
description: Configure SIGNL4 alerts with kwatch using the current provider catalog.
keywords: [kwatch, Kubernetes alerts, SIGNL4, notification channel]
---

# SIGNL4 alerts

Use **SIGNL4** when you want kwatch incidents delivered to this channel. This page is generated from the current provider catalog and lists every field accepted by the installed release.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `teamSecret` | `string` | yes | yes | — | — | Team secret |
| `title` | `string` | no | no | — | — | Custom title |
| `user` | `string` | no | no | — | — | Optional alerting user |
| `url` | `string` | no | no | url | — | Optional endpoint override |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  signl4:
    teamSecret: "${file:/config/signl4-teamSecret}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
