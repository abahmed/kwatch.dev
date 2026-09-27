---
title: Matrix alerts
description: Configure Matrix Kubernetes alerts with kwatch. Required settings include HomeServer URL and Access token; review Secret handling and routing.
keywords: [kwatch, Kubernetes alerts, Matrix, notification channel]
---

# Matrix alerts

Send kwatch incident alerts to **Matrix**. Use the
[interactive manager](/docs/installation) for installation and
credential setup. This page explains the provider fields and shows
a minimal configuration fragment.

**Before you start, have these values ready:**

- `homeServer` — HomeServer URL.
- `accessToken` — Access token.
- `internalRoomId` — Room ID.

For a guided setup, use the [Matrix channel guide](/docs/channels/matrix).

Credentials, tokens, keys, passwords, and webhook URLs must be mounted
from a Kubernetes Secret. Use an exact `${file:/absolute/path}` reference
for every field marked **Secret**.

## Configuration

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `homeServer` | `string` | yes | no | url | — | HomeServer URL |
| `accessToken` | `string` | yes | yes | — | — | Access token |
| `internalRoomId` | `string` | yes | no | — | — | Room ID |
| `title` | `string` | no | no | — | — | Custom title |
| `text` | `string` | no | no | — | — | Custom text |
| `routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `fallback` | `string` | no | no | — | — | Optional fallback provider name. |

## Minimal example

```yaml
alert:
  matrix:
    homeServer: <homeServer>
    accessToken: "${file:/config/matrix-accessToken}"
    internalRoomId: <internalRoomId>
```

Add `routes`, `retry`, and `fallback` when you need delivery filtering or recovery. See the [channels overview](/docs/channels) for guidance, or the [complete provider reference](/docs/channels/providers) for the catalog-wide view.

