---
title: Troubleshoot missing alerts
description: A systematic path for investigating missing or delayed kwatch alerts.
sidebar_position: 2
---

# Troubleshoot missing alerts

Follow the runtime path instead of changing several configuration settings at
once.

## 1. Check health

Confirm that Kwatch is live and ready. If readiness is failing, inspect the
component status and informer synchronization details first.

## 2. Check Kubernetes permissions

Confirm that the Kwatch service account can list and watch the resource kind
that should produce the finding. Permission errors should be visible in the
Kwatch logs and health diagnostics.

## 3. Check scope and suppression

Review:

- Namespace allow and deny rules.
- Reason allow and deny rules.
- Silence rules.
- Maintenance annotations.
- Monitor enablement.
- Thresholds and sustain windows.

## 4. Check incident state

Kwatch may have observed the problem but suppressed a duplicate because of:

- Startup baseline.
- Cooldown.
- Node inhibition.
- Mass-failure suppression.
- Cascading suppression.
- Smart grouping.

Use the diagnostic incident view and audit records to identify the decision.

## 5. Check delivery

If the incident exists but no message arrived, inspect provider configuration,
authentication, rate limits, retries, and dead-letter records.

Do not immediately increase retry counts. First determine whether the failure
is retryable or permanent.
