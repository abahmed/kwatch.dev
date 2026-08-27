---
sidebar_position: 6
title: Rocket.Chat
description: Receive Kubernetes crash alerts in Rocket.Chat — configure webhook and channel for kwatch
keywords: [kwatch, rocketchat, kubernetes crash alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# Rocket.Chat

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.rocketchat.webhook` | 🔗 Webhook URL | Yes |
| `alert.rocketchat.text` | ✏️ Custom text | No |

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
      rocketchat:
        webhook: WEBHOOK_URL
        text: "optional customized text"
```

### Routing

```yaml
alert:
  rocketchat:
    webhook: WEBHOOK_URL
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  rocketchat:
    webhook: WEBHOOK_URL
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  rocketchat:
    webhook: WEBHOOK_URL
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  rocketchat:
    webhook: WEBHOOK_URL
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/rocketchat.png" max-height="700px" alt="Rocket.Chat notification screenshot" />
</p>
