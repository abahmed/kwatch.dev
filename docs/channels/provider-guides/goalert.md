---
title: GoAlert alerts
description: Configure GoAlert alerts with kwatch using the current provider catalog.
keywords: [kwatch, Kubernetes alerts, GoAlert, notification channel]
---

# GoAlert alerts

Use **GoAlert** when you want kwatch incidents delivered to this channel. This page is generated from the current provider catalog and lists every field accepted by the installed release.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `url` | `string` | no | no | url | https://goalert.example.com | GoAlert URL (default: https://goalert.example.com) |
| `token` | `string` | yes | yes | — | — | API token |
| `serviceId` | `string` | yes | no | — | — | Service ID |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  goalert:
    token: "${file:/config/goalert-token}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
