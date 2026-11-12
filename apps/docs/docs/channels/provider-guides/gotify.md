---
title: Gotify provider settings for kwatch Kubernetes alerts
sidebar_label: Gotify alerts
description: Configure Gotify Kubernetes alerts with kwatch. Required settings include Gotify server URL and App token; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Gotify, notification channel]
---

# Gotify alerts

Send kwatch incident alerts to **Gotify**. Use the
[interactive manager](/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `url` — Gotify server URL.
- `token` — App token.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `url` | `string` | yes | no | url | — | Gotify server URL |
| `token` | `string` | yes | yes | — | — | App token |
| `priority` | `integer` | no | no | integer | — | Priority (optional) |
| `resolvedPriority` | `integer` | no | no | integer | — | Priority 0-10 of a resolve (optional, default: the priority, capped at 5) |
| `title` | `string` | no | no | — | — | Custom title |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Resolve priority

A resolve is never louder than the incident: with no `resolvedPriority`, it is sent at `priority` capped at 5. With neither setting, the server default applies. Set `resolvedPriority` for a specific level (an explicit `0` is sent); a value outside 0-10 is ignored.

## Minimal example

```yaml
alert:
  gotify:
    url: <url>
    token: "${file:/config/gotify-token}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/channels) for guidance, or the [complete provider reference](/channels/providers) for the catalog-wide view.

## Related

- [All alert providers](/channels/providers) and [how channels work](/channels)
- [Configuration reference](/general-configuration) and [Troubleshoot missing or delayed alerts](/operations/troubleshooting)
