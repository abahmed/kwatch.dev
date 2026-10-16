---
sidebar_position: 8
title: Community vs Pro
description: What kwatch Community includes, what kwatch Pro adds, and how early access licensing works.
keywords: [kwatch Pro, kwatch Community, editions, early access, license]
---

# Community vs Pro

kwatch ships in two editions from the same binary. Community needs no account
and no key. Pro needs a license key, one per cluster.

:::info Early access
Pro is **free during early access**. A license lasts 3 months and may be
renewed. You can have up to 2 clusters per account, or per company domain for
work emails. There are no prices and no payment details.
:::

## At a glance

| | Community | Pro |
| --- | --- | --- |
| Cost | Free, no account, no key | Free during early access |
| Detection | Pod crashes, OOM kills and Pending pods; node NotReady | Adds node pressure and draining, readiness, rollouts, Jobs and CronJobs, PDBs, HPAs, storage, network, admission, certificates, quota, custom resources, control plane, probes and unusual events |
| Analysis | Root-cause headline | Full proof, shared-factor suspects, who changed what, impact and redacted log excerpts |
| Incidents | Basic dedup and noise control, state in memory | Flapping detection, startup summary, state kept on disk across restarts, changes made while kwatch was down |
| Delivery | 1 provider, namespace filters and silences | All providers, routing by scope, threads, text templates, audit log |
| Operations | RBAC audit, secret redaction, health, metrics, text `/status` | Severity overrides, maintenance holds, runbook links, heartbeat, `/status` JSON, flight recorder and `replay-export`, standby replicas |

The per-capability list is on the [pricing page](/pricing) and in the
[generated feature reference](/docs/reference/generated/features). Every
capability there carries its tier.

## Community

Community is free forever and works without contacting any server.

- **Detection** of pod crashes, OOM kills, Pending pods and restarts, and node
  failures.
- **Root cause** headline on every incident.
- **Noise control**: basic deduplication, settling, and symptom merging.
- **Scope**: namespace, reason and label filters, and silences.
- **One alert provider.** If you configure several, Community keeps the one in
  `app.communityProvider`, or the first by name when that is empty.
- **State in memory.** After a restart kwatch takes a fresh baseline: existing
  failures are not re-sent, and only new or worsening ones alert.

Community messages end with a short note naming what Pro adds. Set
`app.hideProHints: true` to remove it.

## Pro

Pro adds everything marked <span className="kw-pro">Pro</span> across these
docs: the extra detectors, the full root-cause and change history, routing,
threads, templates, severity overrides, maintenance holds, runbooks, audit
log, heartbeat and probes, persistence, the flight recorder, `/status` JSON
and standby replicas. Configuration for Pro features is accepted in
Community and ignored; `kwatch lint` prints an `info:` line for each one, and
the file stays valid when you upgrade.

## How Pro licensing works

- **One license, one cluster.** The first successful check binds the key to
  that cluster.
- **Early access limits.** Up to 2 clusters per account. With a work email the
  limit is 2 per company domain, shared by everyone using it. With a free
  mailbox provider such as Gmail the limit is per account.
- **3 months, renewable.** Each license runs for 3 months from the day you
  start it, and we may renew it.
- **Offline for 7 days.** kwatch renews daily. A renewal is valid for 3 days,
  followed by a 4-day grace period.
- **3 moves per 30 days** to another cluster, with the installer
  (**License / Pro**, then **Move license to this cluster**) or **Transfer** on
  your account page.
- **When a license ends**, kwatch falls back to Community. Detection and
  alerting never stop.
- **What is sent:** a hashed cluster id, the kwatch version and the node count.
  A Community install without a key makes no license calls.

## Get Pro

1. [Sign up](/signup) and open the sign-in link.
2. Choose **Get 3 months of Pro free** on your [account](/account) page.
3. Run the [installer](/docs/kwatch-sh), open **License / Pro** and choose
   **Add or replace key**.

Details, moving a license and troubleshooting are on the
[License](/docs/license) page, and the commands are in the
[CLI reference](/docs/cli-commands).

## Source available

kwatch is source available under the Elastic License 2.0 (ELv2). You may run
it for free in your own clusters, read and change the code, and share it. You
may not offer it as a hosted service or remove its license-key checks.
Releases up to and including `v1.0.0-rc.10` stay under the MIT License. See
[licensing](/docs/licensing).
