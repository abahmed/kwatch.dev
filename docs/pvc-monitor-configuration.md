---
sidebar_position: 6
title: PVC Monitoring Configuration
description: PVC (Persistent Volume Claim) monitoring configuration used in kwatch
keywords: [kwatch, kubernetes, configuration, monitor, pvc, persistent, volume, claim]
pagination_next: null
pagination_prev: null
---

## PVC (Persistent Volume Claim) Monitoring Configuration

| Parameter                |  Description                              | Required       | Default   |
|:-------------------------|:----------------------------------------- |:-------------- |:----------|
| `pvcMonitor.enabled`         | to enable or disable this module (default: true) | false | true |
| `pvcMonitor.interval`        | the frequency (in minutes) to check pvc usage in the cluster  (default: 15) | false | 15 |
| `pvcMonitor.threshold`       | the percentage of accepted pvc usage. if current usage exceeds this value, it will send a notification (default: 80) | false | 80 |

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
    pvcMonitor:
        enabled: true
```
