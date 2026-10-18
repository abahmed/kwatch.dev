---
sidebar_position: 9
title: Send Kubernetes alerts to Telegram with kwatch
sidebar_label: Telegram
description: Send clear Kubernetes incident alerts to Telegram — configure bot token and chat ID for kwatch notifications
keywords: [kwatch, telegram, kubernetes incident alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# ✈️ Telegram

Use the [interactive kwatch manager](/installation) to configure Telegram
alerts. It stores credentials in Kubernetes Secrets and verifies the
installation. The configuration fragments below explain provider settings;
they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.telegram.token` | 🔑 Bot token | Yes |
| `alert.telegram.chatId` | 💬 Chat ID | Yes |

## Configuration example

```yaml
alert:
  telegram:
    token: "${file:/config/telegram-token}"
    chatId: "YOUR_CHAT_ID"
```

## Routing <span className="kw-pro">Pro</span>

```yaml
alert:
  telegram:
    token: "${file:/config/telegram-token}"
    chatId: "YOUR_CHAT_ID"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

## Retry

```yaml
alert:
  telegram:
    token: "${file:/config/telegram-token}"
    chatId: "YOUR_CHAT_ID"
    retry:
      maxAttempts: 5
      delay: 5s
```

## Fallback

```yaml
alert:
  telegram:
    token: "${file:/config/telegram-token}"
    chatId: "YOUR_CHAT_ID"
    fallback: <another_provider>
```

## Compact mode

```yaml
alert:
  telegram:
    token: "${file:/config/telegram-token}"
    chatId: "YOUR_CHAT_ID"
    compact: true
```

## Screenshot

<p align="center">
    <img src="./../../img/telegram.png" max-height="700px" alt="Telegram notification screenshot" />
</p>

## Related

- [Telegram provider settings](/channels/provider-guides/telegram) for every field
- [All alert providers](/channels/providers) and [troubleshoot missing alerts](/operations/troubleshooting)
