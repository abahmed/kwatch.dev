---
sidebar_position: 6
title: Rocket.Chat
description: Receive clear Kubernetes incident alerts in Rocket.Chat — configure webhook and channel for kwatch
keywords: [kwatch, rocketchat, kubernetes incident alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# 🚀 Rocket.Chat

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
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  rocketchat-webhook: "replace-me"
  config.yaml: |
    alert:
      rocketchat:
        webhook: "${file:/config/rocketchat-webhook}"
        text: "optional customized text"
```

### Routing

```yaml
alert:
  rocketchat:
    webhook: "${file:/config/rocketchat-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  rocketchat:
    webhook: "${file:/config/rocketchat-webhook}"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  rocketchat:
    webhook: "${file:/config/rocketchat-webhook}"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  rocketchat:
    webhook: "${file:/config/rocketchat-webhook}"
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/rocketchat.png" max-height="700px" alt="Rocket.Chat notification screenshot" />
</p>
