---
sidebar_position: 12
title: Matrix
description: Get clear Kubernetes incident alerts in Matrix — configure homeserver and room ID for kwatch
keywords: [kwatch, matrix, kubernetes incident alerts, pod monitoring, k8s notifications]
pagination_next: null
pagination_prev: null
---

# 🏗️ Matrix

Use the [interactive kwatch manager](/installation) to configure Matrix
alerts. It stores credentials in Kubernetes Secrets and verifies the
installation. The configuration fragments below explain provider settings;
they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.matrix.homeServer` | 🖥️ HomeServer URL | Yes |
| `alert.matrix.accessToken` | 🔑 Access token | Yes |
| `alert.matrix.internalRoomID` | 🆔 Room ID | Yes |

## Configuration example

```yaml
alert:
  matrix:
    homeServer: "https://matrix.example.com"
    accessToken: "${file:/config/matrix-access-token}"
    internalRoomID: "!roomid:example.com"
```

## Routing <span className="kw-pro">Pro</span>

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

## Retry

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

## Fallback

```yaml
alert:
  matrix:
    homeServer: "https://matrix.example.com"
    accessToken: "${file:/config/matrix-access-token}"
    internalRoomID: "!roomid:example.com"
    fallback: <another_provider>
```

## Compact mode

```yaml
alert:
  matrix:
    homeServer: "https://matrix.example.com"
    accessToken: "${file:/config/matrix-access-token}"
    internalRoomID: "!roomid:example.com"
    compact: true
```

## Screenshot

<p align="center">
    <img src="./../../img/matrix.png" max-height="700px" alt="Matrix notification screenshot" />
</p>
