---
sidebar_position: 1
slug: /channels
title: Channels
description: all supported notification channels for kwatch with configuration examples
keywords: [kwatch, channels, notification, slack, discord, teams, rocket, telegram, pagerduty, mattermost, opsgenie, matrix, dingtalk, feishu, googlechat, zenduty, webhook]
pagination_next: null
pagination_prev: null
---

# Channels

kwatch sends alerts through **56 notification providers**. The 15 below each have a
dedicated configuration page; the rest follow the same shape from the
[providers reference](https://github.com/abahmed/kwatch/blob/main/docs/providers.md).
Configure one or more under `alert:` in your config.

## Supported Channels

| Channel | Config key | Type | Auth |
|---------|-----------|------|------|
| [Slack](/docs/channels/slack) | `slack` | Webhook or Bot Token | URL or `xoxb-*` |
| [Discord](/docs/channels/discord) | `discord` | Webhook | URL |
| [Microsoft Teams](/docs/channels/ms-teams) | `teams` | Webhook | URL |
| [Google Chat](/docs/channels/googlechat) | `googlechat` | Webhook | URL |
| [Rocket.Chat](/docs/channels/rocketchat) | `rocketchat` | Webhook | URL |
| [Mattermost](/docs/channels/mattermost) | `mattermost` | Webhook | URL |
| [Telegram](/docs/channels/telegram) | `telegram` | Bot API | Token + Chat ID |
| [Email](/docs/channels/email) | `email` | SMTP | Password |
| [PagerDuty](/docs/channels/pagerduty) | `pagerduty` | Events API | Integration Key |
| [Opsgenie](/docs/channels/opsgenie) | `opsgenie` | API | API Key |
| [Zenduty](/docs/channels/zenduty) | `zenduty` | API | Integration Key |
| [Matrix](/docs/channels/matrix) | `matrix` | Homeserver API | User + Password |
| [DingTalk](/docs/channels/dingtalk) | `dingtalk` | Webhook | URL |
| [FeiShu](/docs/channels/feishu) | `feishu` | Webhook | URL |
| [Custom Webhook](/docs/channels/webhook) | `webhook` | HTTP | Headers / Basic Auth |

---

## Common Features

All channels support these advanced delivery features:

### 📮 Routing

Control which incidents reach which provider:

```yaml
alert:
  slack:
    webhook: "..."
    routes:
      - namespaces: ["production"]      # only production namespace
        severities: ["high", "critical"] # only high/critical severity
        reasons: ["OOMKilled"]           # only OOM kills
```

An incident matches if it matches **all conditions in at least one route**.
If no routes are configured, all incidents are delivered.

### 🔁 Retry

```yaml
alert:
  slack:
    webhook: "..."
    retry:
      maxAttempts: 5       # max send attempts (default: 3, max: 20)
      delay: 5s            # delay between attempts (default: 1s base, 30s cap)
```

Uses exponential backoff: 1s → 2s → 4s → 8s → ... capped at 30s.

### 🆘 Fallback

If the primary provider fails after all retries, kwatch tries a fallback:

```yaml
alert:
  slack:
    webhook: "..."
    fallback: pagerduty    # must be configured at the top level of alert:
    retry:
      maxAttempts: 3
```

### 🔇 Compact mode

Hide common fields (namespace, node, etc.) to fit more incidents in a single
message:

```yaml
alert:
  slack:
    webhook: "..."
    compact: true
```

### ⚡ Threaded mode (Slack only)

When using Slack bot token, alerts become threaded conversations — root message
on first alert, updates as replies:

```yaml
alert:
  slack:
    token: "xoxb-..."
    channel: "#alerts"
```

---

## Delivery Architecture

```
Incident → AlertManager → per-provider buffered channel (cap 256)
                           → circuit breaker (3 fails → 60s cooldown)
                           → retry (exponential backoff)
                           → fallback (optional)
                           → either: HTTP 200 (delivered)
                           → or: dead-letter queue (last 100 failures)
```

All channels are dispatched **non-blocking** — a slow or down provider won't
delay alerts to other channels.

---

## Format

kwatch formats messages differently per channel type:

| Format | Channels |
|--------|----------|
| **Markdown** | Slack, Discord, Mattermost, RocketChat, Teams, GoogleChat |
| **HTML** | Email |
| **Plain Text** | Telegram, Matrix, DingTalk, FeiShu |

You can override the message template per incident reason:

```yaml
templates:
  OOMKilled: "🔴 {{.Incident.Name}} OOM in {{.Incident.Namespace}}"
  CrashLoopBackOff: "🔄 {{.Incident.Name}} crashing — {{.Incident.Hint}}"
```
