---
title: Dingtalk provider settings for kwatch Kubernetes alerts
sidebar_label: Dingtalk alerts
description: Configure Dingtalk Kubernetes alerts with kwatch. Required settings include Access token; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Dingtalk, notification channel]
---

# Dingtalk alerts

Send kwatch incident alerts to **Dingtalk**. Use the
[interactive manager](/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `accessToken` — Access token.

For a guided setup, use the [Dingtalk channel guide](/channels/dingtalk).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `accessToken` | `string` | yes | yes | — | — | Access token |
| `secret` | `string` | no | yes | — | — | Signing secret |
| `title` | `string` | no | no | — | — | Custom title |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-accessToken}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/channels) for guidance, or the [complete provider reference](/channels/providers) for the catalog-wide view.

## Related

- [Set up Dingtalk alerts step by step](/channels/dingtalk)
- [All alert providers](/channels/providers) and [how channels work](/channels)
- [Configuration reference](/general-configuration) and [Troubleshoot missing or delayed alerts](/operations/troubleshooting)
