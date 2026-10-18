---
sidebar_position: 6
title: Send Kubernetes alerts to Rocket.Chat with kwatch
sidebar_label: Rocket.Chat
description: Receive clear Kubernetes incident alerts in Rocket.Chat — configure webhook and channel for kwatch
keywords: [kwatch, rocketchat, kubernetes incident alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# 🚀 Rocket.Chat

Use the [interactive kwatch manager](/installation) to configure
Rocket.Chat alerts. It stores credentials in Kubernetes Secrets and verifies
the installation. The configuration fragments below explain provider settings;
they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.rocketchat.webhook` | 🔗 Webhook URL | Yes |

## Configuration example

```yaml
alert:
  rocketchat:
    webhook: "${file:/config/rocketchat-webhook}"
```

## Routing <span className="kw-pro">Pro</span>

```yaml
alert:
  rocketchat:
    webhook: "${file:/config/rocketchat-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

## Retry

```yaml
alert:
  rocketchat:
    webhook: "${file:/config/rocketchat-webhook}"
    retry:
      maxAttempts: 5
      delay: 5s
```

## Fallback

```yaml
alert:
  rocketchat:
    webhook: "${file:/config/rocketchat-webhook}"
    fallback: <another_provider>
```

## Compact mode

```yaml
alert:
  rocketchat:
    webhook: "${file:/config/rocketchat-webhook}"
    compact: true
```

## Screenshot

<p align="center">
    <img src="./../../img/rocketchat.png" max-height="700px" alt="Rocket.Chat notification screenshot" />
</p>

## Related

- [Rocket.Chat provider settings](/channels/provider-guides/rocketchat) for every field
- [All alert providers](/channels/providers) and [troubleshoot missing alerts](/operations/troubleshooting)
