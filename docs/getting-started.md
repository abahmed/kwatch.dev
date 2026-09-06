---
sidebar_position: 1
slug: /
title: Getting Started
description: learn how kwatch monitors Kubernetes incidents and sends clear alerts with causes and next steps
keywords: [kwatch, kubernetes monitoring, kubernetes alerts, pod crashes, incident diagnosis, beginner]
pagination_next: installation
pagination_prev: null
---

# 👋 Getting started

## What is Kubernetes?

Kubernetes (often called **K8s**) runs your applications in containers. It
keeps those containers running, moves them between machines, and starts new
ones when needed.

That also means there are many moving parts. A container can run out of memory,
a deployment can get stuck, or a service can lose its healthy backends.

## What is kwatch?

kwatch is the **alarm for your Kubernetes cluster**. It watches your workloads
and sends a clear message when something needs attention:

1. 👀 **Watch** — kwatch reads Kubernetes status, events, and recent logs.
2. 🧠 **Explain** — it connects the clues and finds the likely cause.
3. 📣 **Alert** — it sends the reason, impact, and next step to your team.

You do not need Prometheus, Grafana, or a new dashboard to get started. kwatch
is small, runs in your cluster, and stores no logs or metrics database.

## 🚨 What an alert looks like

Instead of only seeing `CrashLoopBackOff`, you get a message like:

```text
🚨 OOMKilled — production / orders-api
   Cause: the container used more than its 512Mi memory limit.
   Next step: increase limits.memory or reduce memory usage.
   Evidence: recent logs and Kubernetes events
```

## 🎯 What does kwatch watch?

Most monitors are enabled by default:

| Signal | What kwatch explains |
| --- | --- |
| 🟥 Pod crashes | Crash reason, logs, events, and a next step |
| ⏳ Pending pods | Why the scheduler cannot place a pod |
| 🖥️ Nodes | Readiness and disk or memory pressure |
| 🚀 Deployments | Stuck rollouts and unavailable replicas |
| 🧩 StatefulSets and DaemonSets | Unavailable or stuck workloads |
| 🧑‍💼 Jobs and CronJobs | Failed, suspended, or missed work |
| 📈 HPA | An autoscaler stuck at its replica limit |
| 📣 Cluster autoscaler | Evidence that scaling could not happen |
| 💾 PVCs | Storage pressure and volume failures |
| 🌐 Services and Ingress | Missing or unhealthy backends |
| 🏛️ Control plane | API server and platform health signals |

TLS certificate monitoring and heartbeat notifications are **opt-in**. See the
[configuration guide](/docs/general-configuration) or the [complete configuration
reference](/docs/configuration-reference) for every available key.

## 🚀 Install in three steps

### 1. Check your tools

You need `kubectl`, `curl`, and access to a Kubernetes cluster. Confirm that
`kubectl` can reach it:

```bash
kubectl cluster-info
```

### 2. Run the manager

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

The manager asks where alerts should go, stores credentials safely in a Secret,
installs kwatch, and waits until it is ready. No Helm is required.

### 3. Check the result

```bash
kubectl get pods -n kwatch
```

You should see a kwatch pod with `READY 1/1` and `STATUS Running`. 🎉

## 🛠️ What next?

- Need the full lifecycle and troubleshooting guide? Read [Installation](/docs/installation).
- Want Slack, Discord, email, or PagerDuty? Open [Channels](/docs/channels).
- Want to change thresholds or silence known noise? Read [Configuration](/docs/general-configuration).
- Want to understand the manager? Read [kwatch.sh manager](/docs/kwatch-manager).
- Want to contribute code? Start with [Contributing](/docs/contributing).

If you are unsure where to begin, install with the manager first. You can run
it again later to configure, upgrade, check, or uninstall kwatch. ✨
