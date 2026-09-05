---
sidebar_position: 15
title: Heartbeat Monitor
description: configure kwatch's optional heartbeat monitor to detect when the Kubernetes monitor itself stops running
keywords: [kwatch, kubernetes, configuration, monitor, heartbeat, deadman, healthchecks]
pagination_next: null
pagination_prev: null
---

# 💓 Heartbeat monitor (dead man's switch)

This is an optional **watch-the-watcher** check. An external service expects a
regular ping from kwatch; if the pings stop, that service alerts you.

Sends periodic HTTP GET pings to an external health-check URL. If kwatch stops
or crashes, the external monitor stops receiving pings and pages you.

This is useful for detecting when kwatch itself is down — a "watch the watcher"
pattern.

## How it works

```
kwatch ── GET https://hc-ping.com/your-uuid ──► Healthchecks.io
         (every 300 seconds)

If kwatch crashes:
  Healthchecks.io stops receiving pings
  After grace period → sends you an alert (email, SMS, etc.)
```

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `heartbeatMonitor.enabled` | `bool` | `false` | Enable heartbeat pings. |
| `heartbeatMonitor.interval` | `int` (sec) | `300` | Seconds between pings (min: 1). |
| `heartbeatMonitor.url` | `string` | `""` | Secret-backed `${file:/absolute/path}` URL to ping. |

## Example with Healthchecks.io

[Healthchecks.io](https://healthchecks.io) is a free dead-man's switch service.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  heartbeat-url: "replace-me"
```

Add the monitor settings through `kwatch.sh`'s **Configure settings** flow (or
merge them into the config file used by your supported installation):

```yaml
heartbeatMonitor:
  enabled: true
  interval: 300
  url: "${file:/config/heartbeat-url}"
```

1. Sign up at [Healthchecks.io](https://healthchecks.io)
2. Create a new check
3. Copy the ping URL
4. Configure kwatch as shown above
5. In Healthchecks.io, set the grace period (e.g. 10 minutes)

## Example with Better Uptime

```yaml
heartbeatMonitor:
  enabled: true
  interval: 60
  url: "${file:/config/heartbeat-url}"
```
