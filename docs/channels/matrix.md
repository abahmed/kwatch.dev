---
sidebar_position: 9
title: Matrix
description: kwatch configuration for matrix
keywords: [kwatch, matrix, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Matrix

If you want to enable Matrix, provide homeServer, accessToken and internalRoomID
with optional text and title

### Configuration

| Parameter                           | Description                            |
|:------------------------------------|:-------------------------------------- |
| `alert.matrix.homeServer`           | HomeServer URL                         |
| `alert.matrix.accessToken`          | Account access token                   |
| `alert.matrix.internalRoomID`       | Internal room ID                       |
| `alert.matrix.title`                | Customized title in message            |
| `alert.matrix.text`                 | Customized text in message             |

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
      matrix:
        accessToken: ACCESS_TOKEN
```

### Screenshot

<p align="center">
    <img src="./../../img/matrix.png" max-height="700px" />
</p>