---
sidebar_position: 9
title: Telegram
description: Send Kubernetes crash alerts to Telegram — configure bot token and chat ID for kwatch notifications
keywords: [kwatch, telegram, kubernetes crash alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# Telegram

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.telegram.token` | 🔑 Bot token | Yes |
| `alert.telegram.chatId` | 💬 Chat ID | Yes |

### Example

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kwatch
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kwatch
  namespace: kwatch
data:
  config.yaml: |
    alert:
      telegram:
        token: "YOUR_BOT_TOKEN"
        chatId: "YOUR_CHAT_ID"
```

### Routing

```yaml
alert:
  telegram:
    token: "YOUR_BOT_TOKEN"
    chatId: "YOUR_CHAT_ID"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  telegram:
    token: "YOUR_BOT_TOKEN"
    chatId: "YOUR_CHAT_ID"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  telegram:
    token: "YOUR_BOT_TOKEN"
    chatId: "YOUR_CHAT_ID"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  telegram:
    token: "YOUR_BOT_TOKEN"
    chatId: "YOUR_CHAT_ID"
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/telegram.png" max-height="700px" alt="Telegram notification screenshot" />
</p>
