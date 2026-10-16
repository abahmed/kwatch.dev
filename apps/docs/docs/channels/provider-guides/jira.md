---
title: Jira alerts
description: Configure Jira Kubernetes alerts with kwatch. Required settings include Jira base URL and Email or username; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Jira, notification channel]
---

# Jira alerts

Send kwatch incident alerts to **Jira**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `url` — Jira base URL.
- `user` — Email or username.
- `apiToken` — API token.
- `projectKey` — Project key.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `url` | `string` | yes | no | url | — | Jira base URL |
| `user` | `string` | yes | no | — | — | Email or username |
| `apiToken` | `string` | yes | yes | — | — | API token |
| `projectKey` | `string` | yes | no | — | — | Project key |
| `issueType` | `string` | no | no | — | Task | Issue type (default: Task) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  jira:
    url: <url>
    user: <user>
    apiToken: "${file:/config/jira-apiToken}"
    projectKey: <projectKey>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.

