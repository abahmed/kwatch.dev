---
title: kwatch RBAC permissions and Kubernetes security review
sidebar_label: RBAC and deployment security
description: Review Kwatch permissions, diagnostics, and pod security before production rollout.
sidebar_position: 4
---

# RBAC and deployment security

kwatch never needs write access to monitored workloads. Its ClusterRole is read-only for observed resources. The chart value `rbac.mode` selects `least-privilege` (the chart default: an explicit `list`/`watch` set for the kinds kwatch understands; custom resources and kinds added later show as `permission_denied` in `/health` coverage) or `full` (`list` and `watch` on every resource). To watch custom resources and kinds added later, opt in with `--set rbac.mode=full`; the raw `deploy.yaml` stays `full`. Use the [General configuration](/general-configuration#-kubernetes-permissions-and-graceful-degradation) permission section as the starting point rather than granting a cluster-admin role.

## Review checklist

- Confirm the namespaced Role for the state lock Lease is limited to kwatch's own Lease name (`get`/`update`); `create` on Leases in kwatch's namespace cannot be limited by name.
- `get` is granted only where a single object is read: namespaces, nodes, `nodes/stats`, `nodes/metrics` and `pods/log`. `nodes/proxy` and `pods/exec` are never granted.
- **Secrets.** By default kwatch's ServiceAccount can read every Secret in the cluster; kwatch keeps only hashes, never values. Set `watch.secrets: false` to remove every Secret permission. Checks that need Secrets (missing references, certificate expiry) then report that they cannot verify. `rbac.mode: least-privilege` alone does not remove it.
- The license instance key is the one Secret exception: `get` and `update` on the single Secret `kwatch-license-instance` in kwatch's namespace, in both modes and even with `watch.secrets: false`.
- Run `kubectl auth can-i` for the permissions you rely on in the target cluster.
- Run as non-root with a read-only root filesystem, dropped capabilities and seccomp enabled (the shipped manifests do).
- Use image digests and verify release signatures, checksums, SBOM and provenance (see [Release integrity](/release-integrity)).

## Endpoint exposure

kwatch serves only `/healthz`, `/readyz`, `/availabilityz`, `/health` and `/metrics` (Pro), plus the opt-in `/status` (`healthCheck.statusEndpoint`, Pro for JSON). There are no diagnostic, profiling or test-alert endpoints. None has authentication, so keep the health port inside the cluster. `/status` shows object names; read it with `kubectl port-forward`. Responses use safe reason codes; credentials, tokens, payloads and raw Kubernetes objects are excluded.

## Network controls

The chart includes an opt-in NetworkPolicy (off by default). With it on, the health port is reachable only from the release namespace, the node ranges in `networkPolicy.kubeletCIDRs` and the peers in `networkPolicy.healthIngressFrom`. Egress allows DNS, the API server and HTTPS providers, and the kubelet port (10250). Anything else kwatch dials, such as active probe targets, `app.proxyURL` or providers on a non-443 port, must be opened with `networkPolicy.extraEgressPorts` or `networkPolicy.egress`.
