---
title: PagerDuty alerts
description: Configure PagerDuty Kubernetes alerts with kwatch. Required settings include PagerDuty integration key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, PagerDuty, notification channel]
---

# PagerDuty alerts

Send kwatch incident alerts to **PagerDuty**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `integrationKey` — PagerDuty integration key.

For a guided setup, use the [PagerDuty channel guide](/docs/channels/pagerduty).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `integrationKey` | `string` | yes | yes | — | — | PagerDuty integration key |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  pagerduty:
    integrationKey: "${file:/config/pagerduty-integrationKey}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
