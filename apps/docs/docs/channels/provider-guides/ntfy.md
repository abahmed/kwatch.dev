---
title: ntfy alerts
description: Configure ntfy Kubernetes alerts with kwatch. Required settings include Topic to publish to; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, ntfy, notification channel]
---

# ntfy alerts

Send kwatch incident alerts to **ntfy**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `topic` — Topic to publish to.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `topic` | `string` | yes | yes | — | — | Topic to publish to |
| `url` | `string` | no | no | url | https://ntfy.sh | Server URL (default: https://ntfy.sh) |
| `token` | `string` | no | yes | — | — | Optional auth token |
| `title` | `string` | no | no | — | — | Custom title |
| `priority` | `integer` | no | no | integer | 4 | Priority 1-5 (default: 4) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  ntfy:
    topic: "${file:/config/ntfy-topic}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
