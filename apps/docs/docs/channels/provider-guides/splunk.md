---
title: Splunk alerts
description: Configure Splunk Kubernetes alerts with kwatch. Required settings include HEC endpoint URL and HEC token; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Splunk, notification channel]
---

# Splunk alerts

Send kwatch incident alerts to **Splunk**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `url` — HEC endpoint URL.
- `token` — HEC token.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `url` | `string` | yes | no | url | — | HEC endpoint URL |
| `token` | `string` | yes | yes | — | — | HEC token |
| `source` | `string` | no | no | — | — | Source name (optional) |
| `sourcetype` | `string` | no | no | — | — | Source type (optional) |
| `index` | `string` | no | no | — | — | Index name (optional) |
| `host` | `string` | no | no | — | — | Host name (optional) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  splunk:
    url: <url>
    token: "${file:/config/splunk-token}"
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.

