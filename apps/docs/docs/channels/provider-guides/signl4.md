---
title: SIGNL4 provider settings for kwatch Kubernetes alerts
sidebar_label: SIGNL4 alerts
description: Configure SIGNL4 Kubernetes alerts with kwatch. Required settings include Team secret; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, SIGNL4, notification channel]
---

# SIGNL4 alerts

Send kwatch incident alerts to **SIGNL4**. Use the
[interactive manager](/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `teamSecret` — Team secret.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `teamSecret` | `string` | yes | yes | — | — | Team secret |
| `title` | `string` | no | no | — | — | Custom title |
| `user` | `string` | no | no | — | — | Optional alerting user |
| `url` | `string` | no | no | url | — | Optional endpoint override |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  signl4:
    teamSecret: "${file:/config/signl4-teamSecret}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/channels) for guidance, or the [complete provider reference](/channels/providers) for the catalog-wide view.

## Related

- [All alert providers](/channels/providers) and [how channels work](/channels)
- [Configuration reference](/general-configuration) and [Troubleshoot missing or delayed alerts](/operations/troubleshooting)
