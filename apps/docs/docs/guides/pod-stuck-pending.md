---
sidebar_position: 3
title: "Kubernetes pod stuck in Pending: why and how to fix it"
sidebar_label: "Pod stuck Pending"
description: "A Pending pod has not been placed on a node. Find out whether it is CPU, memory, a taint or a volume, and get one message that says which."
keywords: [pod Pending, FailedScheduling, unschedulable, Kubernetes, kubectl describe node, kwatch]
howto: {"name": "Kubernetes pod stuck in Pending: why and how to fix it", "step": [{"@type": "HowToStep", "name": "Read the pod events", "text": "kubectl describe pod <pod> -n <namespace> Read the Events at the bottom and look for FailedScheduling."}, {"@type": "HowToStep", "name": "List the nodes", "text": "kubectl get nodes"}, {"@type": "HowToStep", "name": "Check what a node has free", "text": "kubectl describe node <node>"}]}
faq: [["Why is my pod stuck in Pending?", "Kubernetes has not found a node for it. Usual causes: no node has enough CPU or memory, a taint or selector does not match, or a volume cannot attach."], ["How do I see why a pod is Pending?", "Run kubectl describe pod <pod> -n <namespace> and read the Events at the bottom for FailedScheduling."]]
---

# 🧭 Kubernetes pod stuck in Pending: why and how to fix it

Pending: Kubernetes has not found a [node](/glossary#node) for the [pod](/glossary#pod). Usual causes: no node has enough CPU or memory, a taint or selector does not match, or a volume cannot attach.

## 🔎 Check it by hand

1. Read the pod events. Read the Events at the bottom and look for FailedScheduling.

```bash
kubectl describe pod <pod> -n <namespace>
```

2. List the nodes

```bash
kubectl get nodes
```

3. Check what a node has free

```bash
kubectl describe node <node>
```

## 🎯 What kwatch sends

The message reads like this.

### Example message

```text
🟠 etl in analytics (prod-eu-1) has waited two minutes for a node because no node has enough cpu. It needs 1.5 CPU; the most any node has free is 1.2 CPU, on n1. No node fits: pool general has no node with 1.5 CPU free (best: n1 has 1.2 CPU free); pool bulk has no node with 1.5 CPU free (best: big1 has 1 CPU free). To see the object's state and events, run kubectl describe pod etl-4a6bfd72-a -n analytics
```

## ⭐ Which edition

Community includes scheduling detection.

## 🚀 Install kwatch

One command, and it walks you through it.

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

Community is free forever; Pro is free during early access. See
[Installation](/installation) and [Community vs Pro](/editions).
