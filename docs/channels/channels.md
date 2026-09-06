---
sidebar_position: 1
slug: /channels
title: Channels
description: configure kwatch Kubernetes alerts for Slack, Discord, PagerDuty, email, webhooks, and 56 notification providers
keywords: [kwatch channels, Kubernetes notifications, Kubernetes alerts, Slack, Discord, PagerDuty, webhooks]
pagination_next: channels/slack
pagination_prev: null
---

# 📣 Channels

kwatch can send the same clear alert to **56 providers**. Pick the place your
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
| [Slack](/docs/channels/slack) | `slack` | Webhook URL or bot token |
| [Discord](/docs/channels/discord) | `discord` | Webhook URL |
| [Microsoft Teams](/docs/channels/ms-teams) | `teams` | Webhook URL |
| [Google Chat](/docs/channels/googlechat) | `googlechat` | Webhook URL |
| [Telegram](/docs/channels/telegram) | `telegram` | Bot token and chat ID |
| [Email](/docs/channels/email) | `email` | SMTP server and password |
| [PagerDuty](/docs/channels/pagerduty) | `pagerduty` | Integration key |
| [Opsgenie](/docs/channels/opsgenie) | `opsgenie` | API key |
| [Zenduty](/docs/channels/zenduty) | `zenduty` | Integration key |
| [Mattermost](/docs/channels/mattermost) | `mattermost` | Webhook URL |
| [Rocket.Chat](/docs/channels/rocketchat) | `rocketchat` | Webhook URL |
| [Matrix](/docs/channels/matrix) | `matrix` | Homeserver, token, and room ID |
| [DingTalk](/docs/channels/dingtalk) | `dingtalk` | Access token |
| [FeiShu](/docs/channels/feishu) | `feishu` | Webhook URL |
| [Custom Webhook](/docs/channels/webhook) | `webhook` | Endpoint URL |

The [complete provider reference](/docs/channels/providers) lists every supported
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

You can configure several providers. kwatch sends each incident to all matching
providers.

## 🎯 Send only the alerts you need

Routes filter alerts by namespace, severity, or reason. All conditions in one
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
- 🧵 **Threaded mode** keeps Slack updates together when using a bot token.

Invalid requests and bad credentials are not retried forever. They are reported
so you can fix the provider configuration.

## 🔐 Keep credentials safe

The interactive manager stores credentials in a Kubernetes Secret and mounts
them at `/config`. Use exact `${file:/absolute/path}` references in the config.
Plain credentials and environment substitutions in sensitive fields are
rejected at startup. Read the
[configuration reference](/docs/general-configuration) for details.

## ✅ Test your channel

1. Run `kwatch lint` to validate the configuration.
2. Run `kwatch lint --check` to test credentials for providers that support checks.
3. Enable `healthCheck.diagnostics` and call `/test-alert` if you need a real
   test message.

For installation help, start with [Getting Started](/docs) or [Installation](/docs/installation).
