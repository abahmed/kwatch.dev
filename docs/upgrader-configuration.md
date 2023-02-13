---
sidebar_position: 7
title: Upgrader Configuration
description: upgrader configuration used in kwatch
keywords: [kwatch, kubernetes, configuration, upgrader]
pagination_next: null
pagination_prev: null
---

# Upgrader Configuration

| Parameter                |  Description                              | Required       | Default   |
|:-------------------------|:----------------------------------------- |:-------------- |:----------|
| `upgrader.disableUpdateCheck` | If set to true, does not check for and notify about kwatch updates |

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
    upgrader:
        disableUpdateCheck: true
```
