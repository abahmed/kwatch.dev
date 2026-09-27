---
sidebar_position: 10
title: Mattermost
description: Send clear Kubernetes incident alerts to Mattermost — configure webhook integration for kwatch notifications
keywords: [kwatch, mattermost, kubernetes incident alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# 🌐 Mattermost

Use the [interactive kwatch manager](/docs/installation) to configure
Mattermost alerts. It stores credentials in Kubernetes Secrets and verifies
the installation. The configuration fragments below explain provider settings;
they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.mattermost.webhook` | 🔗 Webhook URL | Yes |
| `alert.mattermost.title` | ✏️ Custom title | No |
| `alert.mattermost.text` | ✏️ Custom text | No |

## Configuration example

```yaml
alert:
  mattermost:
    webhook: "${file:/config/mattermost-webhook}"
    title: "optional customized title"
    text: "optional customized text"
```

## Routing

```yaml
alert:
  mattermost:
    webhook: "${file:/config/mattermost-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

## Retry

```yaml
alert:
  mattermost:
    webhook: "${file:/config/mattermost-webhook}"
    retry:
      maxAttempts: 5
      delay: 5s
```

## Fallback

```yaml
alert:
  mattermost:
    webhook: "${file:/config/mattermost-webhook}"
    fallback: <another_provider>
```

## Compact mode

```yaml
alert:
  mattermost:
    webhook: "${file:/config/mattermost-webhook}"
    compact: true
```

## Screenshot

<p align="center">
    <img src="./../../img/mattermost.png" max-height="700px" alt="Mattermost notification screenshot" />
</p>
