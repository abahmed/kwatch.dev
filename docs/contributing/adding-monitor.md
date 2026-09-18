---
title: Add a monitor
description: How to add a maintainable Kubernetes monitor to kwatch.
sidebar_position: 2
---

# Add a monitor

A monitor detects a domain fact. It does not send notifications, own incident
identity, or write persistence.

## Before coding

Define:

- The Kubernetes resources the monitor observes.
- The exact failure condition.
- Whether the condition is state-based or event-based.
- The expected recovery condition.
- The incident reason and severity behavior.
- Required listers and RBAC.
- Time-based thresholds and the injected clock needed to test them.
- The logs, metrics, and health signals an operator needs.

## Implementation steps

1. Add or reuse observation and ownership logic.
2. Create a focused monitor package.
3. Add a descriptor with a stable name and feature ID.
4. Add explicit wiring in `internal/app` and the controller pipeline.
5. Define a typed source bundle and configure it once before processing starts.
6. Return structured facts beside human-readable hints.
7. Send findings through the incident engine boundary.
8. Add metrics with bounded labels.
9. Add structured logs at detection and failure boundaries.
10. Add configuration and semantic validation when required.
11. Add generated feature and RBAC metadata.

For Pod/container behavior, put deterministic state rules in
`internal/monitor/pod/policy`. A policy rule may read the Pod, container
status, configuration, and injected clock only. Put event lookup, owner
resolution, log retrieval, or API-backed suppression in
`internal/monitor/pod/enrichment`.

Use a family-specific interface or constructor. Do not add a method to a
universal monitor interface and do not pass the delivery manager, persistence
manager, or a whole controller into the monitor.

## Required tests

At minimum, test:

- Healthy resources produce no finding.
- The failure condition produces the expected finding.
- Thresholds use the injected clock.
- Recovery produces the expected resolve behavior.
- Suppression and namespace scope are respected.
- Missing listers or API errors fail clearly.
- Repeated reconciliation is idempotent.
- Source configuration is accepted once and rejected after processing starts.
- Missing sources skip detection and never create or resolve a synthetic
  incident; the safe reason appears in health diagnostics.

For state-based monitors, exercise `incident.Engine.Reconcile` with a finding,
the finding removed, and the object deleted. The handler should not carry its
own recovery map.

Use fake clients and deterministic clocks. Do not use sleeps or live provider
calls.

## Required documentation

Add or update:

- Feature reference metadata.
- Monitor configuration reference.
- A user-facing monitor guide when configuration is required.
- A troubleshooting guide for common false positives or missing alerts.
- Architecture documentation if the monitor introduces a new pattern.
- Release notes and migration notes for changed behavior.
