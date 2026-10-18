---
sidebar_position: 1
title: "Get Slack alerts for CrashLoopBackOff (and fix it)"
sidebar_label: "CrashLoopBackOff alerts"
description: "A pod stuck in CrashLoopBackOff keeps starting and failing. See how to find the cause with kubectl, and get one Slack message that names it."
keywords: [CrashLoopBackOff, Slack alerts, Kubernetes, kubectl logs, pod restarts, kwatch]
howto: {"name": "Get Slack alerts for CrashLoopBackOff (and fix it)", "step": [{"@type": "HowToStep", "name": "List the pods in the namespace", "text": "kubectl get pods -n <namespace>"}, {"@type": "HowToStep", "name": "Read the output of the last crash", "text": "kubectl logs <pod> -n <namespace> --previous"}, {"@type": "HowToStep", "name": "Read the pod events and last state", "text": "kubectl describe pod <pod> -n <namespace>"}]}
faq: [["What does CrashLoopBackOff mean?", "A pod starts, fails, and Kubernetes waits longer before each restart. The app inside is crashing; the status is a symptom, not a cause."], ["How do I find why a pod is in CrashLoopBackOff?", "Read the output of the last crash with kubectl logs <pod> -n <namespace> --previous, then read the pod events with kubectl describe pod."]]
---

# 🧭 Get Slack alerts for CrashLoopBackOff (and fix it)

[CrashLoopBackOff](/glossary#crashloopbackoff) means a [pod](/glossary#pod) starts, fails, and Kubernetes waits longer before each restart. The app inside is crashing; the status is a symptom, not a cause.

## 🔎 Check it by hand

1. List the pods in the namespace

```bash
kubectl get pods -n <namespace>
```

2. Read the output of the last crash

```bash
kubectl logs <pod> -n <namespace> --previous
```

3. Read the pod events and last state

```bash
kubectl describe pod <pod> -n <namespace>
```

## 🎯 What kwatch sends

The message reads like this.

### Example message

```text
🟠 warehouse in staging (prod-eu-1) keeps crashing. Its node and registry are healthy and unchanged, so nothing outside it explains this. It fails with "FileNotFoundException: Could not load file or assembly 'Trella.Models.Common, Version=3.1.120.0'". Its last run lasted 10s. It runs a single replica, so this is downtime, not degradation. To read the output of the last crash, run kubectl logs warehouse-b3e14f5e-a -c app -n staging --previous
```

Community sends to one channel; Pro sends to all your channels. See [Channels](/channels).

## ⭐ Which edition

Community detects crash loops and sends the root-cause headline to one channel. Slack is a supported channel. Pro adds the full proof, who changed what, and delivery to all your channels.

## 🚀 Install kwatch

One command, and it walks you through it.

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

Community is free forever; Pro is free during early access. See
[Installation](/installation) and [Community vs Pro](/editions).
