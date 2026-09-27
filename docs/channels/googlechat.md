---
sidebar_position: 5
title: Google Chat
description: Send clear Kubernetes incident alerts to Google Chat — configure webhook URL for kwatch notifications
keywords: [kwatch, google chat, kubernetes incident alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# 💬 Google Chat

Use the [interactive kwatch manager](/docs/installation) to configure Google
Chat alerts. It stores credentials in Kubernetes Secrets and verifies the
installation. The configuration fragments below explain provider settings;
they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.googlechat.webhook` | 🔗 Webhook URL | Yes |
| `alert.googlechat.text` | ✏️ Custom text | No |

## Configuration example

```yaml
alert:
  googlechat:
    webhook: "${file:/config/googlechat-webhook}"
    text: "optional customized text"
```

## Routing

```yaml
alert:
  googlechat:
    webhook: "${file:/config/googlechat-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

## Retry

```yaml
alert:
  googlechat:
    webhook: "${file:/config/googlechat-webhook}"
    retry:
      maxAttempts: 5
      delay: 5s
```

## Fallback

```yaml
alert:
  googlechat:
    webhook: "${file:/config/googlechat-webhook}"
    fallback: <another_provider>
```

## Compact mode

```yaml
alert:
  googlechat:
    webhook: "${file:/config/googlechat-webhook}"
    compact: true
```

## Screenshot

<p align="center">
    <img src="./../../img/googlechat.png" max-height="700px" alt="Google Chat notification screenshot" />
</p>
