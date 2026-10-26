---
sidebar_position: 5
title: "Alert when a Kubernetes node is NotReady"
sidebar_label: "Node NotReady alerts"
description: "A NotReady node stops running your pods. See how to check it with kubectl and how kwatch pages you when a node stops reporting."
keywords: [node NotReady, kubelet, Kubernetes node alerts, kubectl describe node, kwatch]
howto: {"name": "Alert when a Kubernetes node is NotReady", "step": [{"@type": "HowToStep", "name": "List the nodes", "text": "kubectl get nodes"}, {"@type": "HowToStep", "name": "Read the node conditions and events", "text": "kubectl describe node <node> Look at Conditions and Events."}]}
faq: [["What does a NotReady node mean?", "The node's kubelet stopped reporting or reports a problem, so Kubernetes stops sending it work."], ["How do I check a NotReady node?", "Run kubectl get nodes, then kubectl describe node <node> and read Conditions and Events."]]
---

# 🧭 Alert when a Kubernetes node is NotReady

A [node](/glossary#node) that is NotReady has a kubelet that stopped reporting or reports a problem, so Kubernetes stops sending it work.

## 🔎 Check it by hand

1. List the nodes

```bash
kubectl get nodes
```

2. Read the node conditions and events. Look at Conditions and Events.

```bash
kubectl describe node <node>
```

## 🎯 What kwatch sends

The message reads like this.

### Example message

```text
🔴 Node n1 (prod-eu-1) has not reported for about two minutes. It reports "Kubelet stopped posting node status". kwatch cannot see why from inside the cluster: the kubelet stopped reporting, so the node may be down or unreachable. To check the node's conditions and recent events, run kubectl describe node n1
```

## ⭐ Which edition

Community detects NotReady nodes. Node pressure and draining are Pro.

## 🚀 Install kwatch

One command, and it walks you through it.

```bash
bash <(curl -fsSL https://kwatch.dev/kwatch.sh)
```

Community is free forever; Pro is free during early access. See
[Installation](/installation) and [Community vs Pro](/editions).
