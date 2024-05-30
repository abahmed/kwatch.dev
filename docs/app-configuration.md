---
sidebar_position: 4
title: App Configuration
description: app configuration used in kwatch
keywords: [kwatch, kubernetes, configuration, app]
pagination_next: null
pagination_prev: null
---

# App Configuration

| Parameter                |  Description                              | Required       | Default   |
|:-------------------------|:----------------------------------------- |:-------------- |:----------|
| `app.proxyURL` | used in outgoing http(s) requests except Kubernetes requests to cluster optionally | false | "" |
| `app.clusterName` | used in notifications to indicate which cluster has issue | true | "" |
| `app.logFormatter` | used for setting custom formatter when app prints logs: text, json  | false | text |


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
    app:
        clusterName: dev
```
