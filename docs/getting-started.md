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

kwatch is a source-available Kubernetes incident monitor. It turns failures into
clear alerts that explain what broke, why it happened, and what to do next:

1. 👀 **Watch** — kwatch reads Kubernetes status, events, and recent logs.
2. 🧠 **Explain** — it connects the clues and finds the likely cause.
3. 📣 **Alert** — it sends the reason, impact, and next step to your team.

kwatch runs in your own cluster. The Community edition is free and needs no
account. [Pro](/docs/editions) adds deeper detectors and analysis and is free
during early access. Pair kwatch with Prometheus, Grafana, or Loki for
long-term metrics and logs.

## 🚨 What an alert looks like

Instead of only seeing `CrashLoopBackOff`, you get a message like:

```text
🚨 OOMKilled — production / orders-api
   Pod: orders-api-7ffc9d4f9-x9p4t
   Node: worker-3 · severity: high

💡 Cause: the container exceeded its 512Mi memory limit.
➡️ Next step: increase limits.memory or reduce memory usage.

📄 Recent logs and Kubernetes events are included.
```

## 🎯 What does kwatch watch?

Community covers the failures that page you most. Pro, marked below, adds
the rest.

| Signal | What kwatch explains | Edition |
| --- | --- | --- |
| 🟥 Pod crashes and OOM kills | Crash reason, restarts, root-cause headline and a next step | Community |
| ⏳ Pending pods | Why the scheduler cannot place a pod | Community |
| 🖥️ Nodes | NotReady nodes | Community |
| 🖥️ Node pressure, draining and usage | Disk or memory pressure and draining | <span className="kw-pro">Pro</span> |
| 🚀 Rollouts, readiness | Stuck rollouts and unavailable replicas | <span className="kw-pro">Pro</span> |
| 🧑‍💼 Jobs and CronJobs, HPAs, PDBs | Failed, suspended or missed work, stuck autoscalers, blocked disruption | <span className="kw-pro">Pro</span> |
| 💾 Storage | Claim, volume and attachment failures, volumes nearly full | <span className="kw-pro">Pro</span> |
| 🌐 Services, Ingress, network policy | Missing or unhealthy backends | <span className="kw-pro">Pro</span> |
| 🔐 Certificates, admission, quota | Expiring certificates, webhook failures, exhausted quota | <span className="kw-pro">Pro</span> |
| 🏛️ Control plane | API server, etcd, DNS, scheduler and controller-manager | <span className="kw-pro">Pro</span> |

Pro also adds full root-cause proof, who changed what, impact, log excerpts,
routing and threads. Active probes and the heartbeat monitor are opt-in. See
[Community vs Pro](/docs/editions), the [configuration
guide](/docs/general-configuration), or the [complete configuration
reference](/docs/configuration-reference).

## 🚀 Install in minutes

### 1. Check your tools

You need Bash, `kubectl`, `curl`, and cluster install permissions. Confirm
that `kubectl` can reach your cluster:

```bash
kubectl cluster-info
```

### 2. Run the manager

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

The manager asks where alerts should go, stores credentials safely in a Secret,
installs kwatch, and verifies the installation.

### 3. Check the result

```bash
kubectl get pods -n kwatch
```

You should see one kwatch pod with `STATUS Running` and `READY 1/1`. kwatch
runs as a single replica with its state on a small volume. If the pod or its
node fails, Kubernetes restarts it. Running more than one replica for high
availability is a [Pro](/docs/editions) feature. 🎉

### 4. Optional: add Pro

[Sign up](/signup) for a free Pro license (early access), then run the same
command again and choose **License / Pro**, then **Add or replace key**.
See [License](/docs/license).

## 🛠️ What next?

- Need the full lifecycle and troubleshooting guide? Read [Installation](/docs/installation).
- Want Slack, Discord, email, or PagerDuty? Open [Channels](/docs/channels).
- Want to change thresholds or silence known noise? Read [Configuration](/docs/general-configuration).
- Want to understand the manager? Read [kwatch.sh manager](/docs/kwatch-manager).
- Want the Pro features? Read [Community vs Pro](/docs/editions) and [License](/docs/license).
- Want to contribute code? Start with [Contributing](/docs/contributing).

If you are unsure where to begin, install with the manager first. You can run
it again later to configure, upgrade, check, or uninstall kwatch. ✨
