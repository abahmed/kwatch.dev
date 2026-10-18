---
sidebar_position: 6
title: "Kubernetes TLS certificate expiry alerts"
sidebar_label: "Certificate expiry alerts"
description: "An expired TLS certificate makes clients reject your service. See how to check certificates with kubectl and how kwatch warns you."
keywords: [TLS certificate expiry, expired certificate, Kubernetes Secret, openssl, kwatch Pro]
howto: {"name": "Kubernetes TLS certificate expiry alerts", "step": [{"@type": "HowToStep", "name": "Read the expiry date", "text": "kubectl get secret <name> -n <namespace> -o jsonpath='{.data.tls\\.crt}' | base64 -d | openssl x509 -noout -enddate This decodes the certificate in the Secret and prints its expiry date."}]}
faq: [["What happens when a TLS certificate expires?", "Clients refuse the connection and everything that uses it fails, often with no change on your side."], ["How do I check when a certificate in a Secret expires?", "Decode tls.crt from the Secret and pass it to openssl x509 -noout -enddate."]]
---

# 🧭 Kubernetes TLS certificate expiry alerts

TLS certificates stored in Secrets expire. When one does, clients refuse the connection and everything that uses it fails, often with no change on your side.

## 🔎 Check it by hand

1. Read the expiry date. This decodes the certificate in the Secret and prints its expiry date.

```bash
kubectl get secret <name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate
```

## 🎯 What kwatch sends

The message reads like this.

### Example message

```text
🟠 Secret bank-client-tls in shop (prod-eu-1) has a TLS certificate that expired one hour ago. All of its dependents are failing. Its last run lasted 10s. Clients are rejecting it now. payments is affected as well. To list the keys of the Secret the pods depend on, run kubectl describe secret bank-client-tls -n shop
```

## ⭐ Which edition

<span className="kw-pro">Pro</span> only: certificate detection is not in Community. Pro is free during early access; see [Community vs Pro](/editions).

## 🚀 Install kwatch

One command, and it walks you through it.

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

Community is free forever; Pro is free during early access. See
[Installation](/installation) and [Community vs Pro](/editions).
