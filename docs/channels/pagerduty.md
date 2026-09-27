---
sidebar_position: 7
title: PagerDuty
description: Route clear Kubernetes incident alerts to PagerDuty — configure integration key and severity routing for kwatch
keywords: [kwatch, pagerduty, kubernetes incident alerts, incident response, k8s monitoring]
pagination_next: null
pagination_prev: null
---

# 🚨 PagerDuty

Use the [interactive kwatch manager](/docs/installation) to configure
PagerDuty alerts. It stores credentials in Kubernetes Secrets and verifies the
installation. The configuration fragments below explain provider settings;
they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.pagerduty.integrationKey` | 🔑 PagerDuty integration key | Yes |

## Configuration example

```yaml
alert:
  pagerduty:
    integrationKey: "${file:/config/pagerduty-integration-key}"
```

## Routing

```yaml
alert:
  pagerduty:
    integrationKey: "${file:/config/pagerduty-integration-key}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

## Retry

```yaml
alert:
  pagerduty:
    integrationKey: "${file:/config/pagerduty-integration-key}"
    retry:
      maxAttempts: 5
      delay: 5s
```

## Fallback

```yaml
alert:
  pagerduty:
    integrationKey: "${file:/config/pagerduty-integration-key}"
    fallback: <another_provider>
```

## Compact mode

```yaml
alert:
  pagerduty:
    integrationKey: "${file:/config/pagerduty-integration-key}"
    compact: true
```

## Screenshot

<p align="center">
    <img src="./../../img/pagerduty.png" max-height="700px" alt="PagerDuty notification screenshot" />
</p>
