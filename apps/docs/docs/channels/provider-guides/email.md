---
title: Email alerts
description: Configure Email Kubernetes alerts with kwatch. Required settings include From address and From password; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Email, notification channel]
---

# Email alerts

Send kwatch incident alerts to **Email**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `from` — From address.
- `password` — From password.
- `host` — SMTP host.
- `port` — SMTP port.
- `to` — Receiver email.

For a guided setup, use the [Email channel guide](/docs/channels/email).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `from` | `string` | yes | no | — | — | From address |
| `password` | `string` | yes | yes | — | — | From password |
| `host` | `string` | yes | no | — | — | SMTP host |
| `port` | `string` | yes | no | port | — | SMTP port |
| `to` | `string` | yes | no | — | — | Receiver email |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  email:
    from: <from>
    password: "${file:/config/email-password}"
    host: <host>
    port: <port>
    to: <to>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.

