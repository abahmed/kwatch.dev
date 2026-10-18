---
title: "Is kwatch working? How to check and what silence means"
sidebar_label: Is kwatch working?
description: Check that kwatch is running and can reach your notification channel, what Pro Cluster check-ins show, and the usual reasons kwatch goes quiet.
sidebar_position: 3
keywords: [kwatch status, test alert, cluster check-ins, silent, heartbeat, troubleshooting]
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

## Cluster check-ins <span className="kw-pro">Pro</span>

With an active Pro license, kwatch checks in with `api.kwatch.dev` every 30
minutes. [app.kwatch.dev](https://app.kwatch.dev) shows each cluster's last
seen time and its state:

| State | Meaning |
| --- | --- |
| Checking in | kwatch checked in recently. |
| Silent | Nothing heard for 60 minutes. kwatch stopped talking; your apps may be fine, but kwatch cannot alert you. |
| Stopped | kwatch shut down cleanly, for example scaled down on purpose. Not a problem. |
| Check-ins off | You turned them off. |

Nothing is sent to anyone: no email, no message. You look at the page. A crash,
an out-of-memory kill, a lost node or blocked outbound access shows as Silent
after 60 minutes.

Community sends no check-ins. To turn them off, open the installer's
**License / Pro** menu and choose **Cluster check-ins**.

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
