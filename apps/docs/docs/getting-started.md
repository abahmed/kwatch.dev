---
sidebar_position: 1
slug: /
title: "kwatch docs: Kubernetes incident monitoring and alerting"
sidebar_label: Getting Started
description: When something breaks in your Kubernetes cluster, kwatch tells you what broke, why, and what to do, in Slack, Discord, email and 50+ other channels.
keywords: [kwatch, kubernetes monitoring, kubernetes alerts, pod crashes, incident diagnosis, beginner]
pagination_next: installation
pagination_prev: null
---

# Getting started

When something breaks in your Kubernetes cluster, kwatch tells you what
broke, why, and what to do, in Slack, Discord, email and 50+ other channels.

kwatch runs inside your [cluster](/glossary#cluster), traces every failure
back to what started it, and sends one message: what broke, why, who changed
it, and what to do next.

## 🧭 New to Kubernetes?

Kubernetes (often called **K8s**) runs your applications in containers. It
keeps them running, moves them between machines, and starts new ones when
needed. That also means many moving parts: a container can run out of memory,
a rollout can get stuck, or a service can lose its healthy backends.

If a word below is unfamiliar, the [glossary](/glossary) explains it in one
line: [cluster](/glossary#cluster), [node](/glossary#node),
[pod](/glossary#pod), [namespace](/glossary#namespace),
[CrashLoopBackOff](/glossary#crashloopbackoff),
[OOMKilled](/glossary#oomkilled), [RBAC](/glossary#rbac),
and [CRD](/glossary#crd).

## ✨ Why kwatch

| Benefit | What it means |
| --- | --- |
| 🔍 Root cause first | kwatch follows a failure upstream and names the one cause. |
| 🔒 Your data stays in your cluster | kwatch analyzes events and logs where they live. |
| 🔕 Quiet by default | One message, then silence until something new is true. |
| 🕵️ Who changed what | See who changed what, and when. |
| 👉 The next step | Every message ends with the command to run. |
| 📣 50+ channels | Slack, Teams, PagerDuty, email, webhooks and more. |

## ⚙️ How it works in 30 seconds

1. **Install.** Run one command. It asks a few questions.
2. **It watches.** kwatch runs as one small [pod](/glossary#pod) in your
   cluster and keeps a live map of what depends on what.
3. **You hear.** When something breaks you get one clear message: what broke,
   why, and what to do.

## 🎯 What an alert looks like

Instead of only seeing [`CrashLoopBackOff`](/glossary#crashloopbackoff), you
get a message like:

```text
🚨 OOMKilled — production / orders-api
   Pod: orders-api-7ffc9d4f9-x9p4t
   Node: worker-3 · severity: high

💡 Cause: the container exceeded its 512Mi memory limit.
➡️ Next step: increase limits.memory or reduce memory usage.

📄 Recent logs and Kubernetes events are included.
```

## 🔎 What does kwatch catch?

Community covers the failures that page you most. Pro, marked below, adds
the rest.

| Signal | What kwatch explains | Edition |
| --- | --- | --- |
| Pod crashes and OOM kills | Crash reason, restarts, root-cause headline and a next step | Community |
| Pending pods | Why the scheduler cannot place a pod | Community |
| Liveness and startup probe failures | Which probe failed and why | Community |
| Readiness probe failures | Sustained readiness failures | <span className="kw-pro">Pro</span> |
| Prometheus `/metrics` | Metrics endpoint for your dashboards | <span className="kw-pro">Pro</span> |
| Nodes | NotReady nodes | Community |
| Node pressure, draining and usage | Disk or memory pressure and draining | <span className="kw-pro">Pro</span> |
| Rollouts, readiness | Stuck rollouts and unavailable replicas | <span className="kw-pro">Pro</span> |
| Jobs and CronJobs, HPAs, PDBs | Failed, suspended or missed work, stuck autoscalers, blocked disruption | <span className="kw-pro">Pro</span> |
| Storage | Claim, volume and attachment failures, volumes nearly full | <span className="kw-pro">Pro</span> |
| Services, Ingress, network policy | Missing or unhealthy backends | <span className="kw-pro">Pro</span> |
| Certificates, admission, quota | Expiring certificates, webhook failures, exhausted quota | <span className="kw-pro">Pro</span> |
| Control plane | API server, etcd, DNS, scheduler and controller-manager | <span className="kw-pro">Pro</span> |

Pro also adds full root-cause proof, who changed what, impact, log excerpts,
routing and threads. Active probes and the heartbeat monitor are opt-in. See
[Community vs Pro](/editions), the [configuration
guide](/general-configuration), or the [complete configuration
reference](/configuration-reference). Pair kwatch with Prometheus, Grafana, or
Loki for long-term metrics and logs.

## 🚀 Install

One command, and it walks you through it.

### 1. Check your tools

You need Bash, `kubectl`, `curl`, and cluster install permissions. Confirm
that `kubectl` can reach your cluster:

```bash
kubectl cluster-info
```

### 2. Run the installer

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

The installer asks where alerts should go, stores credentials safely in a
Secret, installs kwatch, and verifies the installation.

### 3. Check the result

```bash
kubectl get pods -n kwatch
```

You should see one kwatch pod with `STATUS Running` and `READY 1/1`. kwatch
runs as a single replica with its state on a small volume. If the pod or its
[node](/glossary#node) fails, Kubernetes restarts it. There is no
high availability in v1: kwatch is always one pod.

### 4. Optional: add Pro

Pro is free during early access. [Get a key](https://app.kwatch.dev), then run
the same command again and choose **License / Pro**, then **Add or replace
key**. See [License](/license).

## 🔒 Your data stays in your cluster

Root cause, without your data leaving the cluster.

Only optional anonymous usage stats and Pro license checks reach kwatch.dev. Never cluster names, pod names, logs or events. Alerts go only to the channels you set up.

kwatch also redacts secrets from logs and messages. To turn usage stats off, see
[Minimal adoption telemetry](/general-configuration#-minimal-adoption-telemetry).

## What next

- Need the full lifecycle and troubleshooting guide? Read [Installation](/installation).
- Want Slack, Discord, email, or PagerDuty? Open [Channels](/channels).
- Want to change thresholds or silence known noise? Read [Configuration](/general-configuration).
- Want to understand the installer? Read [kwatch.sh manager](/kwatch-manager).
- Want the Pro features? Read [Community vs Pro](/editions) and [License](/license).
- Want to contribute code? Start with [Contributing](/contributing).

You can run the installer again later to configure, upgrade, check, or
uninstall kwatch.
