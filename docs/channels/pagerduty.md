---
sidebar_position: 5
title: PagerDuty
description: kwatch configuration for pagerduty
keywords: [kwatch, pagerduty, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# PagerDuty

If you want to enable PagerDuty, provide the integration key

### Configuration

| Parameter                        |  Description                              | Required       |
|:---------------------------------|:----------------------------------------- |:-------------- |
| `alert.pagerduty.integrationKey` |  PagerDuty integration key [more info](https://support.pagerduty.com/docs/services-and-integrations)                        | Yes            |

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
      pagerduty:
        integrationKey: INTEGRATION_KEY
```

### Screenshot

<p align="center">
    <img src="./../../img/pagerduty.png" max-height="700px" />
</p>