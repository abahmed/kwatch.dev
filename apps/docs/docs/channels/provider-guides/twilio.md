---
title: Twilio alerts
description: Configure Twilio Kubernetes alerts with kwatch. Required settings include Account SID and Auth token; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Twilio, notification channel]
---

# Twilio alerts

Send kwatch incident alerts to **Twilio**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `accountSid` — Account SID.
- `authToken` — Auth token.
- `from` — Sender phone number.
- `to` — Recipient phone number.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `accountSid` | `string` | yes | yes | — | — | Account SID |
| `authToken` | `string` | yes | yes | — | — | Auth token |
| `from` | `string` | yes | no | — | — | Sender phone number |
| `to` | `string` | yes | no | — | — | Recipient phone number |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  twilio:
    accountSid: "${file:/config/twilio-accountSid}"
    authToken: "${file:/config/twilio-authToken}"
    from: <from>
    to: <to>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
