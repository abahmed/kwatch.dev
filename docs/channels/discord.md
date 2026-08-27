---
sidebar_position: 3
title: Discord
description: Receive Kubernetes crash alerts in Discord — configure webhook integration and channel routing for kwatch notifications
keywords: [kwatch, discord, kubernetes crash alerts, pod monitoring, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# Discord

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.discord.webhook` | 🔗 Discord webhook URL | Yes |
| `alert.discord.title` | ✏️ Custom title | No |
| `alert.discord.text` | ✏️ Custom text | No |

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
      discord:
        webhook: WEBHOOK_URL
        title: "optional customized title"
        text: "optional customized text"
```

### Routing

```yaml
alert:
  discord:
    webhook: WEBHOOK_URL
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  discord:
    webhook: WEBHOOK_URL
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  discord:
    webhook: WEBHOOK_URL
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  discord:
    webhook: WEBHOOK_URL
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/discord.png" max-height="700px" alt="Discord notification screenshot" />
</p>
