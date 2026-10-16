---
title: Gitea alerts
description: Configure Gitea Kubernetes alerts with kwatch. Required settings include Access token and Repository owner; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Gitea, notification channel]
---

# Gitea alerts

Send kwatch incident alerts to **Gitea**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `token` — Access token.
- `owner` — Repository owner.
- `repo` — Repository name.

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `token` | `string` | yes | yes | — | — | Access token |
| `owner` | `string` | yes | no | — | — | Repository owner |
| `repo` | `string` | yes | no | — | — | Repository name |
| `url` | `string` | no | no | url | — | Optional endpoint override (e.g. self-hosted Gitea) |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  gitea:
    token: "${file:/config/gitea-token}"
    owner: <owner>
    repo: <repo>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.
