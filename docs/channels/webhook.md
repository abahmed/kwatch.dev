---
sidebar_position: 15
title: Custom Webhook
description: Send Kubernetes crash alerts to any custom webhook — configure endpoint and payload format for kwatch
keywords: [kwatch, webhook, custom, kubernetes crash alerts, k8s notifications, webhook integration]
pagination_next: null
pagination_prev: null
---

# Custom Webhook

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.webhook.url` | 🔗 Webhook URL | Yes |
| `alert.webhook.headers` | 📋 Custom headers | No |
| `alert.webhook.basicAuth` | 🔐 Username + password | No |

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
      webhook:
        url: "https://hooks.example.com/alerts"
        headers:
          X-Custom: "value"
        basicAuth:
          username: "user"
          password: "pass"
```

### Routing

```yaml
alert:
  webhook:
    url: "https://hooks.example.com/alerts"
    headers:
      X-Custom: "value"
    basicAuth:
      username: "user"
      password: "pass"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  webhook:
    url: "https://hooks.example.com/alerts"
    headers:
      X-Custom: "value"
    basicAuth:
      username: "user"
      password: "pass"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  webhook:
    url: "https://hooks.example.com/alerts"
    headers:
      X-Custom: "value"
    basicAuth:
      username: "user"
      password: "pass"
    fallback: <another_provider>
```