---
title: Splunk On-Call alerts
description: Configure Splunk On-Call Kubernetes alerts with kwatch. Required settings include API key and Routing key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Splunk On-Call, notification channel]
---

# Splunk On-Call alerts

Send kwatch incident alerts to **Splunk On-Call**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `apiKey` — API key.
- `routingKey` — Routing key.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `apiKey` | `string` | yes | yes | — | — | API key |
| `routingKey` | `string` | yes | yes | — | — | Routing key |
| `url` | `string` | no | no | url | — | Optional endpoint override |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  splunkoncall:
    apiKey: "${file:/config/splunkoncall-apiKey}"
    routingKey: "${file:/config/splunkoncall-routingKey}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
