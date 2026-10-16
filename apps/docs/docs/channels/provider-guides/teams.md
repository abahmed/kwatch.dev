---
title: Teams alerts
description: Configure Teams Kubernetes alerts with kwatch. Required settings include Webhook URL; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Teams, notification channel]
---

# Teams alerts

Send kwatch incident alerts to **Teams**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `webhook` — Webhook URL.

For a guided setup, use the [Teams channel guide](/docs/channels/ms-teams).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `webhook` | `string` | yes | yes | url | — | Webhook URL |
| `title` | `string` | no | no | — | — | Custom title |
| `text` | `string` | no | no | — | — | Custom text |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
