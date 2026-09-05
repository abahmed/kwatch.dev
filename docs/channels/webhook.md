---
sidebar_position: 15
title: Custom Webhook
description: Send clear Kubernetes incident alerts to any custom webhook — configure endpoint and payload format for kwatch
keywords: [kwatch, webhook, custom, kubernetes incident alerts, k8s notifications, webhook integration]
pagination_next: null
pagination_prev: null
---

# 🔗 Custom Webhook

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
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  webhook-url: "replace-me"
  webhook-header: "replace-me"
  webhook-password: "replace-me"
  config.yaml: |
    alert:
      webhook:
        url: "${file:/config/webhook-url}"
        headers:
          - name: X-Custom
            value: "${file:/config/webhook-header}"
        basicAuth:
          username: "user"
          password: "${file:/config/webhook-password}"
```

### Routing

```yaml
alert:
  webhook:
    url: "${file:/config/webhook-url}"
    headers:
      - name: X-Custom
        value: "${file:/config/webhook-header}"
    basicAuth:
      username: "user"
      password: "${file:/config/webhook-password}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  webhook:
    url: "${file:/config/webhook-url}"
    headers:
      - name: X-Custom
        value: "${file:/config/webhook-header}"
    basicAuth:
      username: "user"
      password: "${file:/config/webhook-password}"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  webhook:
    url: "${file:/config/webhook-url}"
    headers:
      - name: X-Custom
        value: "${file:/config/webhook-header}"
    basicAuth:
      username: "user"
      password: "${file:/config/webhook-password}"
    fallback: <another_provider>
```
