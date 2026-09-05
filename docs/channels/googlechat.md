---
sidebar_position: 5
title: Google Chat
description: Send clear Kubernetes incident alerts to Google Chat — configure webhook URL for kwatch notifications
keywords: [kwatch, google chat, kubernetes incident alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# 💬 Google Chat

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.googlechat.webhook` | 🔗 Webhook URL | Yes |
| `alert.googlechat.text` | ✏️ Custom text | No |

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
  googlechat-webhook: "replace-me"
  config.yaml: |
    alert:
      googlechat:
        webhook: "${file:/config/googlechat-webhook}"
        text: "optional customized text"
```

### Routing

```yaml
alert:
  googlechat:
    webhook: "${file:/config/googlechat-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  googlechat:
    webhook: "${file:/config/googlechat-webhook}"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  googlechat:
    webhook: "${file:/config/googlechat-webhook}"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  googlechat:
    webhook: "${file:/config/googlechat-webhook}"
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/googlechat.png" max-height="700px" alt="Google Chat notification screenshot" />
</p>
