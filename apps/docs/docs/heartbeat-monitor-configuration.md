---
sidebar_position: 15
title: Dead man's switch heartbeat monitor for kwatch
sidebar_label: Heartbeat Monitor
description: configure kwatch's optional heartbeat monitor to detect when the Kubernetes monitor itself stops running
keywords: [kwatch, kubernetes, configuration, monitor, heartbeat, deadman, healthchecks]
pagination_next: null
pagination_prev: null
---

# 💓 Heartbeat monitor (dead man's switch)

:::info Pro
This feature is part of kwatch Pro, which is free during early access. See [Community vs Pro](/editions).
:::

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

Add the monitor settings through the `kwatch.sh` installer's **Configure settings** flow:

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
5. In Healthchecks.io, set the period to match `interval` and a grace of at least two intervals

## How kwatch pings

- Each ping is an HTTP `GET` to the configured URL. A `2xx` response counts as accepted; anything else is counted as a failed ping (`heartbeat_failed` in [health reasons](/reference/generated/configuration)).
- Redirects are not followed, so use the final ping URL your provider shows.
- A ping times out after 10 seconds.
- kwatch pings as soon as it starts monitoring, then every `interval` seconds. A ping is sent only while monitoring is ready, so a kwatch that is running but not monitoring stops pinging, and the external monitor alerts you.
- The URL often contains a token. Keep it in the Secret as shown above; kwatch does not log it.

## Pick a period and grace

Set the provider's expected period to kwatch's `interval` (default 300 seconds), and the grace to at least two intervals. One missed or slow ping then does not page you, while a real outage still does within a few minutes. If you lower `interval` to 60, lower the period and grace with it.

## Point the heartbeat at an external service

The steps below only cover what kwatch needs: a ping URL that accepts `GET`. For everything else, such as notification routing, escalation and plan limits, follow the provider's own documentation.

### Healthchecks.io

1. Create a check in [Healthchecks.io](https://healthchecks.io).
2. Set its **Period** to your `interval` and its **Grace Time** to at least twice that.
3. Copy the check's ping URL into the Secret (`heartbeat-url`).
4. Enable `heartbeatMonitor` as shown above.

See the [Healthchecks.io documentation](https://healthchecks.io/docs/).

### PagerDuty

PagerDuty offers heartbeat monitors that alert when a ping does not arrive in time.

1. Create a heartbeat monitor in PagerDuty and choose the service that should be paged.
2. Choose an alert window that is at least twice your `interval`.
3. Copy the heartbeat URL PagerDuty shows into the Secret (`heartbeat-url`). Use exactly the URL and method PagerDuty documents for pinging a heartbeat; kwatch sends a `GET`.
4. Enable `heartbeatMonitor` as shown above.

See [PagerDuty heartbeat monitoring](https://support.pagerduty.com/docs/heartbeat-monitoring) for the current setup and the ping format it accepts.

### Opsgenie

Opsgenie heartbeats raise an alert when no ping arrives within the configured interval.

1. Create a heartbeat in Opsgenie with an interval of at least twice your `interval`.
2. Copy the ping URL into the Secret (`heartbeat-url`). Check in the [Opsgenie heartbeat documentation](https://support.atlassian.com/opsgenie/docs/what-are-heartbeats-and-how-to-use-them/) which URL form and authentication your region needs. kwatch sends a plain `GET` with no custom headers.
3. Enable `heartbeatMonitor` as shown above.

If the provider's ping needs a header or a `POST`, kwatch cannot send it. Pick a provider or ping URL form that accepts a plain `GET`.

## Related

- [Kubernetes failure coverage](/kubernetes-coverage): every detector and its edition
- [General configuration](/general-configuration) and the [generated configuration reference](/reference/generated/configuration)
- [Community vs Pro](/editions)
- [Troubleshoot missing or delayed alerts](/operations/troubleshooting)
