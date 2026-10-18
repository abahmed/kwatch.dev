---
sidebar_position: 4
title: Send Kubernetes alerts to Microsoft Teams with kwatch
sidebar_label: Microsoft Teams
description: Get clear Kubernetes incident alerts in Microsoft Teams — configure webhook connector for kwatch
keywords: [kwatch, microsoft teams, kubernetes incident alerts, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# 💼 Microsoft Teams

Use the [interactive kwatch manager](/installation) to configure
Microsoft Teams alerts. It stores credentials in Kubernetes Secrets and
verifies the installation. The configuration fragments below explain provider
settings; they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.teams.webhook` | 🔗 Webhook URL | Yes |
| `alert.teams.title` | ✏️ Custom title | No |

## Configuration example

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
    title: "optional customized title"
```

## Routing <span className="kw-pro">Pro</span>

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

## Retry

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
    retry:
      maxAttempts: 5
      delay: 5s
```

## Fallback

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
    fallback: <another_provider>
```

## Compact mode

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
    compact: true
```

## Screenshot

<p align="center">
    <img src="./../../img/teams.png" max-height="700px" alt="Microsoft Teams notification screenshot" />
</p>
