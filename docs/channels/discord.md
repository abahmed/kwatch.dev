---
sidebar_position: 3
title: Discord
description: Receive clear Kubernetes incident alerts in Discord — configure webhook integration and channel routing for kwatch
keywords: [kwatch, discord, kubernetes incident alerts, pod monitoring, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# 💬 Discord

Use the [interactive kwatch manager](/docs/installation) to configure Discord
alerts. It stores credentials in Kubernetes Secrets and verifies the
installation. The configuration fragments below explain provider settings;
they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.discord.webhook` | 🔗 Discord webhook URL | Yes |
| `alert.discord.title` | ✏️ Custom title | No |
| `alert.discord.text` | ✏️ Custom text | No |

## Configuration example

```yaml
alert:
  discord:
    webhook: "${file:/config/discord-webhook}"
    title: "optional customized title"
    text: "optional customized text"
```

## Routing

```yaml
alert:
  discord:
    webhook: "${file:/config/discord-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

## Retry

```yaml
alert:
  discord:
    webhook: "${file:/config/discord-webhook}"
    retry:
      maxAttempts: 5
      delay: 5s
```

## Fallback

```yaml
alert:
  discord:
    webhook: "${file:/config/discord-webhook}"
    fallback: <another_provider>
```

## Compact mode

```yaml
alert:
  discord:
    webhook: "${file:/config/discord-webhook}"
    compact: true
```

## Screenshot

<p align="center">
    <img src="./../../img/discord.png" max-height="700px" alt="Discord notification screenshot" />
</p>
