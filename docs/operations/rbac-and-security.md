---
title: RBAC and deployment security
description: Review Kwatch permissions, diagnostics, and pod security before production rollout.
sidebar_position: 4
---

# RBAC and deployment security

Kwatch's service account needs permissions for the enabled monitor families,
the Lease election object, and restart-state ConfigMaps. Use the generated
feature-permission reference as the starting point rather than granting a
cluster-admin role.

## Review checklist

- Confirm the Lease Role and RoleBinding are namespaced to the installation.
- Confirm ConfigMap read/write access is limited to Kwatch state resources.
- Enable only the monitor permissions required by the installation.
- Review Secret access when TLS or dependency evidence is enabled; document
  why the feature needs metadata or content.
- Verify disabled optional monitors do not require unexplained permissions.
- Run `kubectl auth can-i` for every enabled feature in CI or the target
  cluster.
- Run as non-root with a read-only root filesystem, dropped capabilities, and
  seccomp enabled.
- Keep diagnostics and pprof disabled unless an authenticated operational
  workflow requires them.
- Use image digests for deployment and verify release signatures, checksums,
  SBOM, and provenance.

## Diagnostic exposure

`/healthz`, `/readyz`, `/health`, and `/metrics` are operational endpoints.
Incident, persistence, informer, provider, security, control-plane, test-alert,
dead-letter, and pprof endpoints are protected and should remain disabled by
default. Production-oriented configuration must provide a token when they are
enabled. Responses use safe reason codes and bounded fields; credentials,
tokens, payloads, secret-bearing URLs, and raw Kubernetes objects are excluded.

## Network and disruption controls

Review an optional NetworkPolicy for the API server, DNS, configured providers,
and any heartbeat endpoint. For two or more replicas, use a PodDisruptionBudget
with `minAvailable: 1`, a termination grace period longer than bounded shutdown,
and topology spread or preferred anti-affinity when node failure matters.
