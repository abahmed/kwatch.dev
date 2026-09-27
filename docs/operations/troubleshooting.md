---
title: Troubleshoot missing or delayed alerts
description: Trace a missing kwatch Kubernetes alert from leader readiness and source access through suppression, incident state, and provider delivery.
sidebar_position: 2
keywords: [kwatch missing alerts, Kubernetes alert troubleshooting, notification delivery, readiness]
---

# Troubleshoot missing or delayed alerts

Follow the path from observation to delivery. Change one setting at a time so
you can tell which step fixed the problem.

## 1. Check the active leader

The default installation runs one active leader and one standby. A standby can
be healthy without being ready to monitor. Do not use its `/readyz` response
to decide that the whole installation is broken.

Start with the managed workload:

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

`/healthz` reports process liveness. `/readyz` succeeds only on an active
leader whose required state and informer sources are ready. `/health` exposes
safe leadership and degradation reason codes. See
[production readiness](/docs/operations/production-readiness) for the full
endpoint contract.

## 2. Confirm that kwatch can see the source

Check that the monitor is enabled and that the affected namespace is in scope.
A missing or unavailable lister causes kwatch to skip detection; it does not
create a synthetic incident. Source and permission problems appear in health
or logs.

If the failure is a Pod crash, inspect the same Pod directly:

```bash
kubectl describe pod -n production <pod-name>
kubectl logs -n production <pod-name> --previous
```

For node, network, or storage findings, inspect the corresponding Kubernetes
resource and confirm the monitor's [coverage](/docs/kubernetes-coverage).
If access is denied, review the [RBAC guide](/docs/operations/rbac-and-security)
before changing permissions.

## 3. Check scope and suppression

If kwatch sees the condition, look for a deliberate decision to stay quiet:

- Namespace or reason filters may exclude the resource.
- A silence or maintenance marker may suppress the finding.
- Startup baseline can summarize pre-existing problems instead of sending
  individual alerts.
- Cooldown, node inhibition, mass-failure suppression, cascading suppression,
  or grouping may fold related symptoms into another incident.

Review the [configuration guide](/docs/general-configuration) for these
controls. The stable audit skip reasons include `baseline`,
`node_inhibition`, `mass_failure`, `cascading_suppression`, and `cooldown`.
Check the corresponding audit record before removing a silence or changing a
threshold.

## 4. Separate incident creation from delivery

If an incident exists but no message arrived, check the selected provider,
its Secret-backed credentials, routes, rate limits, retries, and any fallback.
Provider errors may be permanent, retryable, or rate limited. Increasing retry
counts will not repair an invalid credential or destination.

Use `kwatch lint` after a configuration change. `kwatch lint --check` can
test credentials for providers that support checks. Protected diagnostics such
as `/incidents`, `/deadletters`, and `/test-alert` are disabled unless you
enable them and supply a bearer token. See [production readiness](/docs/operations/production-readiness)
before exposing diagnostics.

## 5. Verify recovery

After fixing the source, configuration, or provider, wait for the active leader
to become ready and check a real incident or a supported test notification.
Confirm that the expected destination received it. If the leader changed,
review [replication and failover](/docs/operations/replication-and-failover)
for state restore and monitoring-gap behavior.
