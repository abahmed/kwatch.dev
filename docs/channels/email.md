---
sidebar_position: 16
title: Email
description: Get Kubernetes crash alerts via Email (SMTP) — configure SMTP server and recipients for kwatch
keywords: [kwatch, email, smtp, kubernetes crash alerts, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# Email

Sends alerts via SMTP. Uses HTML formatting for rich email content.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.email.from` | 📧 Sender email address | Yes |
| `alert.email.to` | 📧 Recipient email address | Yes |
| `alert.email.password` | 🔑 SMTP password or app password | Yes |
| `alert.email.host` | 🖥️ SMTP server hostname | Yes |
| `alert.email.port` | 🔌 SMTP server port (e.g. 587) | Yes |

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
      email:
        from: "kwatch@example.com"
        to: "team@example.com"
        password: "your-smtp-password"
        host: "smtp.gmail.com"
        port: "587"
```

### Routing

```yaml
alert:
  email:
    from: "kwatch@example.com"
    to: "team@example.com"
    password: "..."
    host: "smtp.gmail.com"
    port: "587"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  email:
    from: "kwatch@example.com"
    to: "team@example.com"
    password: "..."
    host: "smtp.gmail.com"
    port: "587"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  email:
    from: "kwatch@example.com"
    to: "team@example.com"
    password: "..."
    host: "smtp.gmail.com"
    port: "587"
    fallback: slack
```
