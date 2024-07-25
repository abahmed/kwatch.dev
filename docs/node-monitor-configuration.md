---
sidebar_position: 7
title: Node Monitoring Configuration
description: node monitoring configuration used in kwatch
keywords: [kwatch, kubernetes, configuration, monitor, node, machine]
pagination_next: null
pagination_prev: null
---

## Node Monitoring Configuration

| Parameter                |  Description                              | Required       | Default   |
|:-------------------------|:----------------------------------------- |:-------------- |:----------|
| `nodeMonitor.enabled`    | to enable or disable this module (default: true) | false | true |


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
    nodeMonitor:
        enabled: true
```
