---
sidebar_position: 3
title: "kwatch dashboard API: read incidents and status over HTTP"
sidebar_label: Dashboard API
description: Reference for the read-only kwatch dashboard API. List incidents, read one in detail, get kwatch status, and sign in with a password or bearer token.
keywords: [kwatch dashboard API, /api/incidents, /api/status, bearer token, REST API, Kubernetes incidents]
---

# 🔌 Dashboard API <span className="kw-pro">Pro</span>

:::info Pro
The dashboard is part of kwatch Pro, which is free during early access. It needs kwatch v1.2 or newer.
:::

The dashboard reads its data from a small HTTP API, and you can read the same
data from scripts. The API is read-only: every data endpoint answers `GET`
only, and nothing in it changes your cluster. Paths are unversioned and all
responses are JSON.

Turn the dashboard on first (see [Dashboard](/dashboard) or
[Dashboard setup](/dashboard-setup)). The API lives on the dashboard port, so
the examples below use a port-forward:

```bash
kubectl -n kwatch port-forward svc/kwatch-dashboard 8061:8061
```

## Authenticate

Every `/api/*` request needs one of these:

- **A bearer token.** Send `Authorization: Bearer <token>`. The token is the
  `token` key of the `<release>-dashboard` Secret. Use this for scripts.
- **A session cookie.** `POST /login` with the dashboard password. This is what
  the web page does.

```bash
TOKEN=$(kubectl -n kwatch get secret kwatch-dashboard -o jsonpath='{.data.token}' | base64 -d)
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8061/api/status
```

Keep the token to yourself: it reads everything the dashboard shows. If you
manage the Secret yourself, see
[GitOps in Dashboard setup](/dashboard-setup#gitops-set-your-own-secret).

### Sign in and out

| Request | What it does |
|---|---|
| `POST /login` with `{"password": "..."}` | `204` and a `kwatch_session` cookie. `401` for a wrong password |
| `POST /logout` | Signs the session out and clears the cookie. Always `204` |
| `GET /api/session` | `204` when you are signed in, `401` when not |

The password is accepted with or without dashes and in any case. The cookie is
HttpOnly and SameSite=Strict, and lasts 12 hours. A kwatch restart or a password
change signs everyone out. In shared mode, sign-in over plain http is refused
with `403` and `{"error": "https_required"}`.

### Limits

After 10 wrong credentials in a minute from one client, kwatch answers `429` with a
`Retry-After` header (seconds) until the next minute. A request with no
credential at all does not count. Behind a proxy, set `dashboard.trustProxy` so
the limit applies per real client.

## Errors

Errors are JSON, like `{"error": "unauthorized"}`.

| Status | Meaning |
|---|---|
| `400` | A query value is not valid, such as `invalid severity` or `invalid since` |
| `401` | No valid token or session |
| `403` | `https_required` in shared mode over plain http, or a cross-origin sign-in |
| `404` | No such incident |
| `405` | Not a `GET` (the `Allow` header says which method) |
| `429` | Too many failed attempts |

## `GET /api/incidents`

Lists incidents, newest first.

| Query | Values |
|---|---|
| `state` | `active` (default list) or `resolved`. To narrow the active list, also use `settling`, `open`, `recovering` or `flapping`. Repeat the parameter or separate values with commas |
| `namespace` | One namespace name |
| `severity` | `page`, `notify`, `digest` or `silent`. Repeatable. In the dashboard these show as Urgent (`page`), Needs attention (`notify`) and Low (`digest`). Silent incidents are left out unless you ask for `silent` |
| `q` | Search text, up to 200 characters |
| `since` | A duration back from now, like `24h`, or an RFC 3339 time. For resolved issues it is when they resolved; for active ones, when they were last seen |
| `limit` | How many to return. Default `100`, largest `500` |

Different parameters combine with AND. Several values of one parameter combine
with OR.

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8061/api/incidents?state=active&severity=page&namespace=shop"
```

```json
{
  "incidents": [
    {
      "id": "…",
      "title": "…",
      "severity": "page",
      "state": "open",
      "namespace": "shop",
      "workload": "checkout",
      "workloadKind": "Deployment",
      "firstSeen": "2026-10-28T09:12:00Z",
      "lastSeen": "2026-10-28T09:40:00Z",
      "repeatCount": 3
    }
  ],
  "total": 1,
  "truncated": false,
  "counts": {"page": 1, "notify": 0, "digest": 0}
}
```

- `total` is how many incidents matched. `truncated` is `true` when `limit` or
  the response size left some out, so ask for a narrower list.
- `counts` is how many incidents of the requested list there are by severity,
  before the other filters and the limit.
- `ackedBy` (who acknowledged it, when anyone did) and `resolvedAt` appear when they apply.
- `state` values show in the dashboard as: `settling` Looking into it, `open` Happening now, `recovering` Looks better, `flapping` Keeps coming back, `resolved` Resolved.

## `GET /api/incidents/{id}`

One incident in full. It has every field of the list item, plus:

| Field | What it holds |
|---|---|
| `rootCause` | The likely cause in plain words |
| `suggestedFix` | The fix as a sentence or two, when there is one |
| `fixSteps` | The steps, each with `text` and, when it is a command, `command` |
| `fixCommands` | The commands alone, ready to copy |
| `timeline` | What happened, each with `at`, `kind`, `text` and sometimes `reason` and `entity` |
| `capturedLogLines` | Log lines kwatch captured |
| `docsLink` | A link to a guide, when there is one |

`kind` is a stable code: `repeated`, `cause_revised`, `acknowledged`,
`ack_removed`, `flapping`, `paged_again`, `paged_together`, `same_outage`,
`resolved` or `note`. Use it rather than reading the text. For a `resolved`
event, `reason` is `recovered`, `recovered_unheard`, `superseded`,
`stopped_tracking` or `other`.

## `GET /api/namespaces`

The namespaces that have incidents, A to Z. Takes the same `state` parameter as
the list, and is what fills the namespace filter.

```json
{"namespaces": ["payments", "shop"]}
```

## `GET /api/status`

How kwatch is doing.

```json
{
  "version": "1.2.0",
  "edition": "pro",
  "lastScan": "2026-10-28T09:40:05Z",
  "lastScanLate": false,
  "scanEverySeconds": 15,
  "kwatchNamespace": "kwatch",
  "kwatchDeployment": "kwatch",
  "watchedNamespaces": ["*"],
  "perChannelHealth": [
    {
      "channel": "…",
      "type": "slack",
      "name": "…",
      "lastSuccess": "2026-10-28T09:12:03Z"
    }
  ]
}
```

- `watchedNamespaces` is `["*"]` when kwatch watches every namespace.
  `excludedNamespaces` lists any left out.
- `lastScanLate` is `true` when the last check is older than kwatch allows.
- `perChannelHealth` shows when each alert channel last delivered and last
  failed. `lastErrorMessage` is short and never contains a webhook URL or
  token.

The example values above are illustrative.
