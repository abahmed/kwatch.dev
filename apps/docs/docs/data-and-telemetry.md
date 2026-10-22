---
sidebar_position: 3
title: "Your data and what kwatch sends"
sidebar_label: Your data
description: Root cause, without your data leaving the cluster. What kwatch sends to kwatch.dev, when, and how to turn it off.
keywords: [kwatch telemetry, kwatch privacy, anonymous usage stats, license check, data]
---

# 🔒 Your data stays in your cluster

**Root cause, without your data leaving the cluster.**

kwatch analyzes events and logs where they live.

Only optional anonymous usage stats and Pro license checks reach kwatch.dev. Never cluster names, pod names, logs or events. Alerts go only to the channels you set up.

## What kwatch sends

| What | When | Contains | Control |
| --- | --- | --- | --- |
| Anonymous usage stats | At most once a week | An anonymous ID derived from your cluster (a one-way hash that can't be traced back to the cluster or linked to your license) and the kwatch version | On by default; turn off with `telemetry.enabled: false` or `KWATCH_TELEMETRY=false` |
| Pro license check | About once a day (also renews after an upgrade), Pro only | License ID, hashed cluster ID, kwatch version, node count, plus a signed proof and timestamp. No cluster names, namespaces, pod names, logs or events | Part of Pro; Community sends none |

Never sent: cluster names, namespaces, pod names, logs or events. Alerts go
only to the channels you set up.

## Turn usage stats off

Change the `telemetry.enabled` setting in the installer under **Edit settings**,
set `KWATCH_TELEMETRY=false`, or with Helm set `config.telemetry.enabled: false`. See
[General configuration](/general-configuration#-minimal-adoption-telemetry).

## More

- [License](/license) covers the Pro license check and its grace period.
- [Privacy policy](https://kwatch.dev/privacy).
