---
title: iLert alerts
description: Configure iLert Kubernetes alerts with kwatch. Required settings include Integration key; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, iLert, notification channel]
---

# iLert alerts

Send kwatch incident alerts to **iLert**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `integrationKey` — Integration key.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `integrationKey` | `string` | yes | yes | — | — | Integration key |
| `priority` | `integer` | no | no | integer | — | Priority (LOW/HIGH/CRITICAL, default: HIGH) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  ilert:
    integrationKey: "${file:/config/ilert-integrationKey}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
