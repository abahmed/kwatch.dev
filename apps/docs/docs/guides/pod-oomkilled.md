---
sidebar_position: 2
title: "Why is my pod OOMKilled?"
sidebar_label: "Pod OOMKilled"
description: "OOMKilled means a container used more memory than its limit. Learn how to confirm it with kubectl and how kwatch tells you which limit to raise."
keywords: [OOMKilled, out of memory, memory limit, Kubernetes, kubectl describe pod, kwatch]
howto: {"name": "Why is my pod OOMKilled?", "step": [{"@type": "HowToStep", "name": "Confirm the reason", "text": "kubectl describe pod <pod> -n <namespace> Look for Last State: Terminated, Reason: OOMKilled."}, {"@type": "HowToStep", "name": "Read the memory limit", "text": "kubectl get pod <pod> -n <namespace> -o yaml Find resources.limits.memory."}, {"@type": "HowToStep", "name": "Check current usage (optional)", "text": "kubectl top pod -n <namespace> This needs metrics-server installed in the cluster."}]}
faq: [["What does OOMKilled mean?", "The container went over its memory limit and was stopped. Either the limit is too low or the app leaks."], ["How do I confirm a pod was OOMKilled?", "Run kubectl describe pod <pod> -n <namespace> and look for Last State: Terminated with Reason: OOMKilled."]]
---

# 🧭 Why is my pod OOMKilled?

[OOMKilled](/glossary#oomkilled): the container went over its memory limit and was stopped. Either the limit is too low or the app leaks.

## 🔎 Check it by hand

1. Confirm the reason. Look for Last State: Terminated, Reason: OOMKilled.

```bash
kubectl describe pod <pod> -n <namespace>
```

2. Read the memory limit. Find resources.limits.memory.

```bash
kubectl get pod <pod> -n <namespace> -o yaml
```

3. Check current usage (optional). This needs metrics-server installed in the cluster.

```bash
kubectl top pod -n <namespace>
```

## 🎯 What kwatch sends

The message reads like this.

### Example message

```text
🟠 api in shop (prod-eu-1) keeps running out of memory. Its registry is healthy and unchanged, so nothing outside it explains this. It was killed at its 512Mi memory limit; it used 470Mi at peak in the last 24 hours. Its last run lasted 1h59m; 4 restarts in the 1h1m since its pod was created. Fix in: deployment/api → container app → resources.limits.memory (512Mi). To read the output of the last crash, run kubectl logs api-d461a92b-a -c app -n shop --previous
```

## ⭐ Which edition

Community includes OOM detection and the root-cause headline. Pro adds log excerpts and the full proof.

## 🚀 Install kwatch

One command, and it walks you through it.

```bash
bash <(curl -fsSL https://kwatch.dev/kwatch.sh)
```

Community is free forever; Pro is free during early access. See
[Installation](/installation) and [Community vs Pro](/editions).
