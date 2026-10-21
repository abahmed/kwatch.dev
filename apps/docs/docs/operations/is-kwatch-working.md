---
title: "Is kwatch working? How to check and what silence means"
sidebar_label: Is kwatch working?
description: Check that kwatch is running and can reach your notification channel, what the app's "Last seen" shows, and the usual reasons kwatch goes quiet.
sidebar_position: 3
keywords: [kwatch status, test alert, last seen, silent, heartbeat, troubleshooting]
---

# Is kwatch working?

kwatch runs as **one pod**. There is no high availability in v1: if that pod is
down, kwatch is not watching until Kubernetes restarts it. So it is worth
knowing how to check that it is alive, and that its alerts can reach you.

## Check it yourself

1. Run the [installer](/kwatch-sh) and choose **View status**. It shows the
   pod, the version and the license state. The installer can also show logs.
2. Choose **Send test alert**. It sends a clearly marked test through your real
   notification channel, so a pass proves the same path real alerts use.
3. Prefer the command line? The same test runs inside the pod:

   ```bash
   kubectl -n <namespace> exec deploy/kwatch -- kwatch test-alert
   ```

   Add `--provider <name>` to test one provider. A test alert is not stored as
   an incident.

If the test does not arrive, see the [silent failures](#common-silent-failures)
below.

## Last seen in the app

With an active Pro license, kwatch makes a daily license check.
[app.kwatch.dev](https://app.kwatch.dev) shows each cluster as "Cluster" plus
the first 8 characters of its ID, with a "Last seen" time. The check sends only
the license ID, a hashed cluster ID, the kwatch version and the node count.

"Last seen" is not an alert. To be told when kwatch stops, use the heartbeat
below.

## Your own heartbeat URL <span className="kw-pro">Pro</span>

If you want a message when kwatch goes quiet, point kwatch at a monitor you
own. See [Heartbeat monitor](/heartbeat-monitor-configuration).

## Common silent failures

- **A provider credential is wrong or expired.** The test alert reports the
  rejected credential. Fix it in **Edit notification providers**.
- **Community supports one provider.** Extra providers are ignored. See
  [Community vs Pro](/editions).
- **Namespace scope.** kwatch only watches the namespaces it is configured
  for. Check the namespace settings if one workload never alerts.
- **A NetworkPolicy blocks traffic.** kwatch needs outbound access to your
  provider (and to `api.kwatch.dev` for Pro), and to port 10250 on the nodes
  for node stats.
- **The startup baseline.** After a start kwatch learns what is already
  failing and sends one summary instead of announcing every old problem. Only
  new or worsening problems alert.

Still stuck? See [Getting help](/getting-help).
