---
sidebar_position: 1
slug: /channels
title: "Kubernetes alert channels: Slack, Discord, PagerDuty, email"
sidebar_label: Channels
description: configure kwatch Kubernetes alerts for Slack, Discord, PagerDuty, email, webhooks, and 50+ notification channels
keywords: [kwatch channels, Kubernetes notifications, Kubernetes alerts, Slack, Discord, PagerDuty, webhooks]
pagination_next: channels/slack
pagination_prev: null
---

# 📣 Channels

kwatch can send the same clear alert to **50+ channels**. Pick the place your
team already checks:

| You want... | Try... |
| --- | --- |
| 💬 Team chat | Slack, Discord, Microsoft Teams, Mattermost, Rocket.Chat |
| 🚨 On-call pages | PagerDuty, Opsgenie, Zenduty, SIGNL4, Squadcast |
| 📧 Email or SMS | Email, SendGrid, AWS SES, Twilio |
| 🔗 Your own system | Custom Webhook, Ntfy, Gotify, n8n, Zapier |
| 📋 Tickets | Jira, ClickUp, GitHub, GitLab, Gitea |

## 🌟 Dedicated setup guides

The most common providers have a step-by-step page:

| Channel | Config key | What you need |
| --- | --- | --- |
| [Slack](/channels/slack) | `slack` | Webhook URL or bot token |
| [Discord](/channels/discord) | `discord` | Webhook URL |
| [Microsoft Teams](/channels/ms-teams) | `teams` | Webhook URL |
| [Google Chat](/channels/googlechat) | `googlechat` | Webhook URL |
| [Telegram](/channels/telegram) | `telegram` | Bot token and chat ID |
| [Email](/channels/email) | `email` | SMTP server and password |
| [PagerDuty](/channels/pagerduty) | `pagerduty` | Integration key |
| [Opsgenie](/channels/opsgenie) | `opsgenie` | API key |
| [Zenduty](/channels/zenduty) | `zenduty` | Integration key |
| [Mattermost](/channels/mattermost) | `mattermost` | Webhook URL |
| [Rocket.Chat](/channels/rocketchat) | `rocketchat` | Webhook URL |
| [Matrix](/channels/matrix) | `matrix` | Homeserver, token, and room ID |
| [DingTalk](/channels/dingtalk) | `dingtalk` | Access token |
| [FeiShu](/channels/feishu) | `feishu` | Webhook URL |
| [Custom Webhook](/channels/webhook) | `webhook` | Endpoint URL |

The [complete provider reference](/channels/providers) lists every supported
provider, every catalog field, its type, whether it is required, and whether it
must come from a Secret. It is generated from the same provider catalog used by
`kwatch.sh`.

The sidebar's **All provider guides** section gives each provider its own page
and minimal configuration example.

## 🧩 Basic configuration

Put one or more providers under `alert:`. This example sends alerts to Slack:

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
```

The Community edition sends to one provider; if you configure several, set
`app.communityProvider` to choose which one is kept (the default is the first
by name). Pro sends each incident to all matching providers.

## 🎯 Send only the alerts you need <span className="kw-pro">Pro</span>

Routes filter alerts by namespace, severity, reason, or owner. All conditions in one
route must match:

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
        reasons: ["OOMKilled"]
```

If you do not add routes, the provider receives all alerts.

## 🔁 Delivery that can recover

The same delivery options work for every provider:

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
    retry:
      maxAttempts: 3
      delay: 5s
    fallback: pagerduty
```

- 🔁 **Retry** tries temporary failures again, such as timeouts and server errors.
- 🆘 **Fallback** sends to another configured provider when the first one fails.
- 📏 **Compact** reduces message size when your channel has strict limits.
- 🧵 **Threads** (<span className="kw-pro">Pro</span>) keep Slack updates together when using a bot token.

Invalid requests and bad credentials are not retried forever. They are reported
so you can fix the provider configuration.

## 🔐 Keep credentials safe

The `kwatch.sh` installer stores credentials in a Kubernetes Secret and mounts
them at `/config`. Use exact `${file:/absolute/path}` references in the config.
Plain credentials and environment substitutions in sensitive fields are
rejected at startup. Read the
[configuration reference](/general-configuration) for details.

## ✅ Test your channel

1. Run `kwatch lint` to validate the configuration.
2. Run `kwatch lint --check` to test credentials for providers that support checks.
3. Start kwatch and check the startup message in the channel. There is no
   test-alert endpoint; `kwatch lint --check` is the supported credential check.

For installation help, start with [Getting Started](/) or [Installation](/installation).
