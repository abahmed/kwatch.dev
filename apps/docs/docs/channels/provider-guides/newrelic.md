---
title: New Relic provider settings for kwatch Kubernetes alerts
sidebar_label: New Relic alerts
description: Configure New Relic Kubernetes alerts with kwatch. Required settings include User API key and Account ID; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, New Relic, notification channel]
---

# New Relic alerts

Send kwatch incident alerts to **New Relic**. Use the
[interactive manager](/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `apiKey` — User API key.
- `accountId` — Account ID.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `apiKey` | `string` | yes | yes | — | — | User API key |
| `accountId` | `string` | yes | no | — | — | Account ID |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  newrelic:
    apiKey: "${file:/config/newrelic-apiKey}"
    accountId: <accountId>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/channels) for guidance, or the [complete provider reference](/channels/providers) for the catalog-wide view.

## Related

- [All alert providers](/channels/providers) and [how channels work](/channels)
- [Configuration reference](/general-configuration) and [Troubleshoot missing or delayed alerts](/operations/troubleshooting)
