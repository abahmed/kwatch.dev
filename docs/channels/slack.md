---
sidebar_position: 2
title: Slack
description: Send clear Kubernetes incident alerts to Slack — configure webhook, channels, and severity routing for kwatch
keywords: [kwatch, slack, kubernetes incident alerts, pod monitoring, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# 💬 Slack

If you want to enable Slack, provide either a webhook URL or a bot token with channel.

**Webhook mode:**

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.slack.webhook` | Slack webhook URL | Yes |
| `alert.slack.channel` | 📢 Override channel | No |
| `alert.slack.title` | ✏️ Custom title | No |
| `alert.slack.text` | ✏️ Custom text | No |
| `alert.slack.compact` | 📏 Single-line mode | No |

**Bot Token mode:**

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.slack.token` | Slack bot token (`xoxb-...`) | Yes |
| `alert.slack.channel` | 📢 Channel to post to | Yes |
| `alert.slack.title` | ✏️ Custom title | No |
| `alert.slack.text` | ✏️ Custom text | No |
| `alert.slack.compact` | 📏 Single-line mode | No |

> 💡 **Pro tip:** When using bot token mode, alerts become threaded conversations — root message on first alert, updates as replies. Clean and organized! 🧹

### Compact mode

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
    compact: true
```

### Routing & Retry

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
    retry:
      maxAttempts: 3
      delay: 5s
```

### Fallback provider

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
    fallback: "pagerduty"
    retry:
      maxAttempts: 3
```

### Example (Webhook)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kwatch
---
apiVersion: v1
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  slack-webhook: "replace-me"
  config.yaml: |
    alert:
      slack:
        webhook: "${file:/config/slack-webhook}"
        title: "optional customized title"
        text: "optional customized text"
```

### Example (Bot Token)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kwatch
---
apiVersion: v1
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  slack-token: "replace-me"
  config.yaml: |
    alert:
      slack:
        token: "${file:/config/slack-token}"
        channel: "#alerts"
        title: "optional customized title"
        text: "optional customized text"
```

### Screenshot

<p align="center">
    <img src="./../../img/slack.png" max-height="700px" alt="Slack notification screenshot" />
</p>
