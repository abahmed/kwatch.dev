---
title: Plivo alerts
description: Configure Plivo alerts with kwatch using the current provider catalog.
keywords: [kwatch, Kubernetes alerts, Plivo, notification channel]
---

# Plivo alerts

Use **Plivo** when you want kwatch incidents delivered to this channel. This page is generated from the current provider catalog and lists every field accepted by the installed release.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `authId` | `string` | yes | yes | — | — | Auth ID |
| `authToken` | `string` | yes | yes | — | — | Auth token |
| `from` | `string` | yes | no | — | — | Sender number |
| `to` | `string` | yes | no | — | — | Recipient phone number |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  plivo:
    authId: "${file:/config/plivo-authId}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
