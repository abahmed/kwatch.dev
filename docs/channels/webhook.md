---
sidebar_position: 12
title: FeiShu
description: kwatch configuration for custom webhook
keywords: [kwatch, webhook, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Custom webhook

If you want to enable custom webhook, provide url with optional headers and
basic auth

### Configuration

| Parameter                 | Description                     |
|:--------------------------|:--------------------------------|
| `alert.webhook.url`       | Webhook URL                     |
| `alert.webhook.headers`   | optional list of name and value |
| `alert.webhook.basicAuth` | optional username and password  |

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
      webhook:
        url: URL
        headers:
          - name: HEADER_NAME
            value: HEADER_VALUE
        basicAuth:
          username: USERNAME
          password: PASSWORD
```
