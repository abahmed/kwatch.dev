---
title: Troubleshoot missing or delayed alerts
description: Trace a missing kwatch Kubernetes alert from Pod readiness and source access through suppression, incident state, and provider delivery.
sidebar_position: 2
keywords: [kwatch missing alerts, Kubernetes alert troubleshooting, notification delivery, readiness]
---

# Troubleshoot missing or delayed alerts

Follow the path from observation to delivery. Change one setting at a time so
you can tell which step fixed the problem.

## 1. Check the Pod

The default installation runs one kwatch Pod. If it is not Ready, nothing is being monitored.

```bash
kubectl get pods -n kwatch -l app=kwatch
kubectl logs -n kwatch deployment/kwatch
```

If you need endpoint details, port-forward the Deployment and inspect health:

```bash
kubectl port-forward -n kwatch deployment/kwatch 8060:8060
curl http://localhost:8060/healthz
curl http://localhost:8060/readyz
curl http://localhost:8060/health
```

`/healthz` reports process liveness. `/readyz` succeeds only when the Pod holds the state lock and its required state and informer sources are ready. `/health` exposes safe degradation reason codes. A Pod that cannot get the volume, or that waits for the lock behind an old Pod, stays unready. See [production readiness](/docs/operations/production-readiness) for the endpoint contract.

Also check your edition. Without a license, kwatch runs Community: one provider, a smaller set of detectors, and state in memory. A detector or delivery feature marked Pro is not active until a license is added; see [Community vs Pro](/docs/editions).

## 2. Confirm that kwatch can see the source

Check that the affected namespace is in scope. kwatch always watches every supported resource; `namespaces`, `reasons` and `silences` only filter what is delivered. A missing or unavailable lister causes kwatch to skip detection; it does not create a synthetic incident. Source and permission problems appear in `/health` (including its `coverage` object) or in the logs.

If the failure is a Pod crash, inspect the same Pod directly:

```bash
kubectl describe pod -n production <pod-name>
kubectl logs -n production <pod-name> --previous
```

For node, network, or storage findings, inspect the corresponding Kubernetes resource and confirm the [coverage](/docs/kubernetes-coverage). If access is denied, review the [RBAC guide](/docs/operations/rbac-and-security) before changing permissions.

## 3. Check scope and suppression

If kwatch sees the condition, look for a deliberate decision to stay quiet:

- Namespace or reason filters may exclude the resource.
- A silence or a maintenance marker (Pro) may suppress the finding.
- The startup baseline summarizes problems that already existed when kwatch started instead of sending individual alerts (after a restart, Community takes a fresh baseline because its state is in memory).
- Settling, cooldown, merging of symptoms under one root cause, and node-level incidents may fold related symptoms into another incident. Check the incident's root before assuming something was dropped.
- Low-priority problems go to a digest (one message every 30 minutes) instead of their own message.

Review the [configuration guide](/docs/general-configuration) for these controls. With the audit log (Pro), every incident decision is written as a JSON line you can search before removing a silence or changing a setting.

## 4. Separate incident creation from delivery

If an incident exists but no message arrived, check the selected provider,
its Secret-backed credentials, routes (Pro), rate limits, retries, and any fallback. On Community only one provider is active (`app.communityProvider`); `kwatch lint` shows which.
Provider errors may be permanent, retryable, or rate limited. Increasing retry
counts will not repair an invalid credential or destination.

Use `kwatch lint` after a configuration change. `kwatch lint --check` can
test credentials for providers that support checks. Use `/status` (opt-in) and the
`kwatch_delivery_*` metrics to see open incidents and failed deliveries.

## 5. Verify recovery

After fixing the source, configuration, or provider, wait for the Pod
to become ready and check a real incident or a supported test notification.
Confirm that the expected destination received it. If the Pod restarted,
review [replication and failover](/docs/operations/replication-and-failover)
for state restore and monitoring-gap behavior.
