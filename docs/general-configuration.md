---
sidebar_position: 3
title: General Configuration
description: general configuration used in kwatch
keywords: [kwatch, kubernetes, configuration, general]
pagination_next: null
pagination_prev: null
---

# General Configuration


| Parameter                |  Description                              | Required       | Default   |
|:-------------------------|:----------------------------------------- |:-------------- |:----------|
| `maxRecentLogLines`  |  Optional Max tail log lines in messages, if it's not provided it will get all log lines webhook URL                      | No            | 0  |
| `namespaces`    |  Optional list of namespaces that you want to watch, if it's not provided it will watch all namespaces      | No             | [] |


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
    maxRecentLogLines: 20
    namespaces:
      - default
```
