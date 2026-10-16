---
title: Mailgun alerts
description: Configure Mailgun Kubernetes alerts with kwatch. Required settings include API key and Sending domain; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Mailgun, notification channel]
---

# Mailgun alerts

Send kwatch incident alerts to **Mailgun**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `apiKey` — API key.
- `domain` — Sending domain.
- `from` — From address.
- `to` — Recipients (comma-separated).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `apiKey` | `string` | yes | yes | — | — | API key |
| `domain` | `string` | yes | no | — | — | Sending domain |
| `from` | `string` | yes | no | — | — | From address |
| `to` | `string` | yes | no | — | — | Recipients (comma-separated) |
| `subject` | `string` | no | no | — | — | Email subject |
| `url` | `string` | no | no | url | — | Optional endpoint override (e.g. EU region) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  mailgun:
    apiKey: "${file:/config/mailgun-apiKey}"
    domain: <domain>
    from: <from>
    to: <to>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
