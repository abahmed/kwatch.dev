---
sidebar_position: 1
slug: /
title: Getting Started
description: an introduction to kwatch — a beginner-friendly Kubernetes crash monitor
keywords: [kwatch, introduction, kubernetes, monitor, crashes, cluster, slack, discord, teams, rocket, telegram, pagerduty, channels, notifications, realtime]
pagination_next: null
pagination_prev: null
---

# Getting Started

> **👋 New to Kubernetes? No problem.**

kwatch watches your cluster and sends you a **friendly alert** the moment
something breaks — with a plain-English explanation of what went wrong and
**how to fix it**.

✨ **60 seconds to install. No backend. No dashboards. No YAML spaghetti.**

---

## 🧐 What is kwatch?

kwatch is like a **smart friend** for your Kubernetes cluster:

- 💥 **Something crashes** → you get a message that says *why* (not just "pod is broken")
- 🔇 **Smart about noise** — groups related issues, ignores flapping, sends a digest when things get crazy
- 🧠 **Explains itself** — every alert names the cause, the impact, and what recently changed
- ⚡ **Works in under a minute** — just one command and a config file

No Prometheus. No Grafana. No 50-step setup. Just alerts that **make sense**.

---

## 🆚 kwatch vs the scary stuff

| | ✨ kwatch | 😰 DIY Prometheus + Alertmanager | 💸 Heavy SaaS |
|---|---|---|---|
| ⏱️ Setup time | **~5 minutes** | hours of YAML | agent + backend setup |
| 📦 Size | ~20 MB single binary | whole monitoring stack | per-node agents + cloud costs |
| 💬 Alerts | Self-explaining ("OOMKilled — raise memory limit") | Rule-defined message | Depends on configuration |
| 🗄️ Storage | None (stateless) | Prometheus TSDB | Full retention (costly) |
| 📚 Learning curve | One ConfigMap | PromQL + alert rules | Platform-specific DSL |

---

## 🚨 Before vs After

| Raw kubectl output 🤷 | kwatch tells you 💡 |
|---|---|
| `CrashLoopBackOff` | 🚨 **OOMKilled** (memory limit: 512Mi) — try raising `limits.memory` · here are the logs + events |
| `Error` | 🚨 **HTTP probe** failing on `:8080/healthz` (exit 137) — container ran out of memory |

---

## 🎯 What does it catch?

Every monitor below is **on by default** — zero config needed:

| Signal | What kwatch does |
|--------|-----------------|
| 🟥 Pod crashes (CrashLoop, OOM, ImagePull, Error) | Container state + previous logs + events — tells you *why* |
| ⏳ Pending pods (stuck Unschedulable) | Alerts after 300s stuck |
| 🖥️ Node issues (NotReady, Disk/Memory pressure) | Per-condition severity |
| 💾 PVC running out of space | Warn at 80%, critical at 90% |
| ❌ Failed Jobs | JobFailed / JobSuspended |
| 🚀 Stuck rollouts & StatefulSets | ProgressDeadlineExceeded — deployment didn't finish |
| 📡 DaemonSet pods not running | Unavailable pods detected |
| ⏰ CronJob suspended or missing runs | Not scheduled in 24h? Alert. |
| 📈 HPA stuck at max replicas | After 20 minutes sustained |
| 📣 Cluster autoscaler can't scale | FailedToScaleUp / NotTriggerScaleUp |
| 🔒 TLS certs expiring | Enable if you want cert expiry warnings |
| 💓 Heartbeat (dead man's switch) | Enable to page you if kwatch goes down |

> ✅ **TLS and heartbeat are the only ones off** — everything else just works out of the box.

---

## 🚀 Quick Start (under 60 seconds)

### 1. Create a config file

```yaml
# config.yaml
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
      slack:
        webhook: "https://hooks.slack.com/services/..."
```

### 2. Apply it

```bash
kubectl apply -f config.yaml
```

### 3. Deploy kwatch

```bash
kubectl apply -f https://raw.githubusercontent.com/abahmed/kwatch/v0.11.0-rc.6/deploy/deploy.yaml
```

### 4. Check it's running

```bash
kubectl get pods -n kwatch
```

That's it. You'll now get alerts in Slack when something breaks. 🎉

---

## 📚 Next Steps

- [Installation](/docs/installation) — full install guide with Helm, kubectl, and config options
- [General Configuration](/docs/general-configuration) — all configuration options explained
- [Configure Channels](/docs/channels) — set up Slack, Discord, email, PagerDuty, and more
- [Architecture](/docs/architecture/overview) — how kwatch works under the hood
