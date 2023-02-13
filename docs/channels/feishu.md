---
sidebar_position: 11
title: FeiShu
description: kwatch configuration for feishu
keywords: [kwatch, feishu, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# FeiShu

If you want to enable FeiShu, provide accessToken with optional secret and
title

### Configuration

| Parameter                | Description                 |
|:-------------------------|:----------------------------|
| `alert.feishu.webhook`   | FeiShu bot webhook URL      |
| `alert.feishu.title`     | Customized title in message |

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
      feishu:
        webhook: WEB_HOOK
```

### Screenshot

<p align="center">
    <img src="./../../img/feishu.png" max-height="700px" />
</p>