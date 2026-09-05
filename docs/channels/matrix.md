---
sidebar_position: 12
title: Matrix
description: Get clear Kubernetes incident alerts in Matrix — configure homeserver and room ID for kwatch
keywords: [kwatch, matrix, kubernetes incident alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# 🏗️ Matrix

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.matrix.homeServer` | 🖥️ HomeServer URL | Yes |
| `alert.matrix.accessToken` | 🔑 Access token | Yes |
| `alert.matrix.internalRoomID` | 🆔 Room ID | Yes |
| `alert.matrix.title` | ✏️ Custom title | No |
| `alert.matrix.text` | ✏️ Custom text | No |

### Example

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kwatch
---
apiVersion: v1
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  matrix-access-token: "replace-me"
  config.yaml: |
    alert:
      matrix:
        homeServer: "https://matrix.example.com"
        accessToken: "${file:/config/matrix-access-token}"
        internalRoomID: "!roomid:example.com"
        title: "optional customized title"
        text: "optional customized text"
```

### Routing

```yaml
alert:
  matrix:
    homeServer: "https://matrix.example.com"
    accessToken: "${file:/config/matrix-access-token}"
    internalRoomID: "!roomid:example.com"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  matrix:
    homeServer: "https://matrix.example.com"
    accessToken: "${file:/config/matrix-access-token}"
    internalRoomID: "!roomid:example.com"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  matrix:
    homeServer: "https://matrix.example.com"
    accessToken: "${file:/config/matrix-access-token}"
    internalRoomID: "!roomid:example.com"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  matrix:
    homeServer: "https://matrix.example.com"
    accessToken: "${file:/config/matrix-access-token}"
    internalRoomID: "!roomid:example.com"
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/matrix.png" max-height="700px" alt="Matrix notification screenshot" />
</p>
