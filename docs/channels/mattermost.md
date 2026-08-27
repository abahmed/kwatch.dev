---
sidebar_position: 10
title: Mattermost
description: Send Kubernetes crash alerts to Mattermost — configure webhook integration for kwatch notifications
keywords: [kwatch, mattermost, kubernetes crash alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# Mattermost

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.mattermost.webhook` | 🔗 Webhook URL | Yes |
| `alert.mattermost.title` | ✏️ Custom title | No |
| `alert.mattermost.text` | ✏️ Custom text | No |

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
      mattermost:
        webhook: WEBHOOK_URL
        title: "optional customized title"
        text: "optional customized text"
```

### Routing

```yaml
alert:
  mattermost:
    webhook: WEBHOOK_URL
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  mattermost:
    webhook: WEBHOOK_URL
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  mattermost:
    webhook: WEBHOOK_URL
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  mattermost:
    webhook: WEBHOOK_URL
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/mattermost.png" max-height="700px" alt="Mattermost notification screenshot" />
</p>
