---
sidebar_position: 4
title: "ImagePullBackOff explained"
sidebar_label: "ImagePullBackOff"
description: "ImagePullBackOff means Kubernetes cannot download a container image. Check the name, tag and registry credentials, and see what kwatch reports."
keywords: [ImagePullBackOff, ErrImagePull, image pull, registry credentials, Kubernetes, kwatch]
howto: {"name": "ImagePullBackOff explained", "step": [{"@type": "HowToStep", "name": "Read the pull error", "text": "kubectl describe pod <pod> -n <namespace> The Events show the pull error."}, {"@type": "HowToStep", "name": "Read the image the deployment uses", "text": "kubectl get deployment <name> -n <namespace> -o jsonpath='{.spec.template.spec.containers[*].image}'"}]}
faq: [["What does ImagePullBackOff mean?", "The node cannot pull the image. The name or tag is wrong, a private-registry credential is missing, or the registry is down. Kubernetes retries with a growing delay."], ["How do I see the image pull error?", "Run kubectl describe pod <pod> -n <namespace>; the Events show the pull error."]]
---

# 🧭 ImagePullBackOff explained

The [node](/glossary#node) cannot pull the image: the name or tag is wrong, a private-registry credential is missing, or the registry is down. Kubernetes retries with a growing delay; that is the BackOff.

## 🔎 Check it by hand

1. Read the pull error. The Events show the pull error.

```bash
kubectl describe pod <pod> -n <namespace>
```

2. Read the image the deployment uses

```bash
kubectl get deployment <name> -n <namespace> -o jsonpath='{.spec.template.spec.containers[*].image}'
```

## 🎯 What kwatch sends

The message reads like this.

### Example message

```text
🟠 checkout is failing in shop (prod-eu-1) after the 10:01 release of registry.corp.example/shop/checkout:1.9.O. The previous image was registry.corp.example/shop/checkout:1.9.0. Its image cannot be pulled. Fix in: deployment/checkout → container app → image (registry.corp.example/shop/checkout:1.9.O). To see the rollout state, run kubectl rollout status deployment/checkout -n shop
```

For a registry that rejects credentials:

```text
🟠 ledger in billing (prod-eu-1) cannot pull its image because registry registry.corp.example rejects the credentials. Its pods name no pull secret, so the registry sees anonymous pulls, and the registry answers "401 Unauthorized". Every error mentions it. Three failing workloads all depend on it. api and worker in shop are affected as well. To see why the container cannot start, run kubectl describe pod ledger-e005c2f7-c -n billing
```

## ⭐ Which edition

Community detects image pull failures. The parts of these messages that name the release ("after the 10:01 release") and the other affected workloads ("affected as well") are Pro-level analysis (recent changes and impact), so do not expect them in Community.

## 🚀 Install kwatch

One command, and it walks you through it.

```bash
bash <(curl -fsSL https://kwatch.dev/kwatch.sh)
```

Community is free forever; Pro is free during early access. See
[Installation](/installation) and [Community vs Pro](/editions).
