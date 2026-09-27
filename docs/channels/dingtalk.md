---
sidebar_position: 13
title: DingTalk
description: Send clear Kubernetes incident alerts to DingTalk — configure webhook and security tokens for kwatch
keywords: [kwatch, dingtalk, kubernetes incident alerts, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# 🔔 DingTalk

Use the [interactive kwatch manager](/docs/installation) to configure DingTalk
alerts. It stores credentials in Kubernetes Secrets and verifies the
installation. The configuration fragments below explain provider settings;
they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.dingtalk.accessToken` | 🔑 Access token | Yes |
| `alert.dingtalk.secret` | 🔐 Signing secret | No |
| `alert.dingtalk.title` | ✏️ Custom title | No |

## Configuration example

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-access-token}"
    secret: "${file:/config/dingtalk-secret}"
    title: "optional customized title"
```

## Routing

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-access-token}"
    secret: "${file:/config/dingtalk-secret}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

## Retry

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-access-token}"
    secret: "${file:/config/dingtalk-secret}"
    retry:
      maxAttempts: 5
      delay: 5s
```

## Fallback

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-access-token}"
    secret: "${file:/config/dingtalk-secret}"
    fallback: <another_provider>
```

## Compact mode

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-access-token}"
    secret: "${file:/config/dingtalk-secret}"
    compact: true
```
