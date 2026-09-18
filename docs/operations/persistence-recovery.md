---
title: Persistence and recovery
description: Back up, migrate, and recover Kwatch restart state safely.
sidebar_position: 3
---

# Persistence and recovery

Kwatch stores restart-critical state in ConfigMaps in its own namespace. The
wire format and ConfigMap names are compatibility boundaries. Do not edit their
JSON by hand unless following an incident recovery procedure.

## State stores

The startup migration report covers startup metadata, schema state, baseline,
incidents, groups, engine, provider threads, PVC state, RCA state, telemetry,
feedback, and change history. Missing optional state may degrade; missing or
corrupt required state prevents unsafe active startup.

## Backup before an upgrade

Use a namespace-scoped export with restricted file permissions:

```sh
kubectl -n "$KWATCH_NAMESPACE" get configmap \
  kwatch-state kwatch-baseline kwatch-incidents kwatch-groups \
  kwatch-engine kwatch-threads kwatch-pvc kwatch-changes \
  kwatch-rca kwatch-telemetry -o yaml > kwatch-state-backup.yaml
chmod 600 kwatch-state-backup.yaml
```

The exact set of stores can vary with enabled features. Confirm the names in
the target release's generated reference and retain the backup until the new
leader has been ready and delivered a controlled test notification.

## Migration behavior

- Missing version: use the compatible legacy path.
- Supported older version: migrate and record `completed` or `failed`.
- Current version: record `not_required`.
- Future version: preserve the data and record `unsupported`.
- Malformed metadata or corrupt payload: preserve the data and block unsafe
  overwrite.

Each startup produces one detached report with source format, destination
format, status, recoverability, continuation safety, and a bounded operator
reason. Inspect protected diagnostics and structured logs; raw payloads and
secrets are not exposed.

## Recovery procedure

1. Stop or scale down the active deployment if writes must be frozen.
2. Preserve the current ConfigMaps and controller logs.
3. Restore only the last known-good backup into the original namespace and
   names, using normal Kubernetes conflict safeguards.
4. Start one controlled leader and wait for `/readyz`.
5. Confirm the migration report, active incident identity, baseline, and
   delivery status.
6. Scale back to the desired replica count and verify one Lease holder.

If required restore fails, Kwatch remains not-ready and does not start active
incident or delivery processing. A monitoring gap is reported from the last
persisted liveness stamp; expired Kubernetes Events are unknown history.

Never claim that a notification was delivered exactly once after a crash or
leadership transition. Use incident state, audit records, provider logs, and
dead letters to reconcile the result.
