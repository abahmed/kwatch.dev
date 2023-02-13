---
sidebar_position: 10
title: DingTalk
description: kwatch configuration for dingtalk
keywords: [kwatch, dingtalk, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# DingTalk

If you want to enable DingTalk, provide accessToken with optional secret and
title

### Configuration

| Parameter                           | Description                            |
|:------------------------------------|:-------------------------------------- |
| `alert.dingtalk.accessToken`        | Chat access token                      |
| `alert.dingtalk.secret`             | Optional secret used to sign requests  |
| `alert.dingtalk.title`              | Customized title in message            |

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
      dingtalk:
        accessToken: ACCESS_TOKEN
```
