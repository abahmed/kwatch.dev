---
title: Configuration reference
description: Generated configuration fields and defaults for kwatch.
sidebar_position: 1
generated: true
---

# Configuration reference

> This page is generated from the Kwatch configuration catalog. Edit the Go
> configuration source and catalog metadata instead of editing this page.

## Performance

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `resyncSeconds` | integer | `300` | active | Periodic safety resync interval in seconds; zero keeps event-driven mode, otherwise at least 30. |

## Scope

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `namespaces` | list | `all` | active | Comma-separated namespaces to watch; leave empty to watch every namespace. |
| `namespaceSelector` | string | `empty` | active | Kubernetes label selector used to choose namespaces. |
| `reasons` | list | `all` | active | Comma-separated event reasons to allow or exclude with a leading !. |
| `watch.secrets` | boolean | `true` | active | Watch Secrets (values hashed, never stored); false removes Secret RBAC and Secret-based checks report that they cannot verify. |

## Alerts

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `severityByOwnerKind` | json | `&#123;&#125;` | active | JSON map overriding severity by workload owner kind. |
| `severityByReason` | json | `&#123;&#125;` | active | JSON map overriding severity by detected reason. |

## Monitors

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `heartbeatMonitor.enabled` | boolean | `false` | active | Send a periodic external dead-man heartbeat. |
| `heartbeatMonitor.interval` | integer | `300` | active | Seconds between heartbeat notifications. |
| `activeProbeMonitor.enabled` | boolean | `false` | active | Run explicitly configured application probes. |
| `activeProbeMonitor.intervalSeconds` | integer | `30` | active | Seconds between active probe rounds. |
| `activeProbeMonitor.timeoutSeconds` | integer | `5` | active | Timeout for each active probe. |
| `activeProbeMonitor.failureThreshold` | integer | `3` | active | Consecutive probe failures before alerting. |
| `activeProbeMonitor.autoServices` | boolean | `false` | active | Probe discoverable Service ports automatically; opt in to avoid unexpected traffic. |
| `activeProbeMonitor.excludeNamespaces` | list | `[]` | active | Namespaces automatic Service probing skips, for default-deny ingress that does not admit kwatch. |
| `activeProbeMonitor.http` | json | `[]` | active | JSON array of HTTP probe targets with optional paths, headers, and latency limits. |
| `activeProbeMonitor.tcp` | json | `[]` | active | JSON array of TCP probe targets. |
| `activeProbeMonitor.dns` | json | `[]` | active | JSON array of DNS probe targets. |
| `activeProbeMonitor.autoDependencies` | boolean | `false` | active | Probe the endpoints outside the cluster that pod environments name, over TCP; a refused dependency explains its callers. |

## Operations

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `upgrader.disableUpdateCheck` | boolean | `false` | active | Disable the update notification. |
| `telemetry.enabled` | boolean | `true` | active | Send the weekly adoption heartbeat. |
| `maintenance.enabled` | boolean | `true` | active | Honor maintenance annotations while preserving cluster-level alerts. |
| `maintenance.annotation` | string | `kwatch.dev/maintenance` | active | Annotation that marks deliberate maintenance on a resource. |
| `maintenance.untilAnnotation` | string | `kwatch.dev/maintenance-until` | active | Optional annotation containing the maintenance expiry timestamp. |
| `app.clusterName` | string | `empty` | active | Cluster name shown in notifications. |
| `app.proxyURL` | string | `empty` | active | Optional proxy for outbound provider requests. |
| `app.disableStartupMessage` | boolean | `false` | active | Disable the startup notification. |
| `app.logFormatter` | string | `text` | active | Log output format: text or json. |
| `healthCheck.enabled` | boolean | `true` | active | Expose the built-in health endpoint. |
| `healthCheck.port` | integer | `8060` | active | Port for health and optional diagnostic endpoints. |
| `crd.enabled` | boolean | `false` | active | Watch KwatchConfig and supported CRD status conditions; restart kwatch when configuration changes; enabled by the interactive installer after installing the CRD. |
| `auditLog.enabled` | boolean | `true` | active | Write structured incident lifecycle records to the configured audit sink. |
| `auditLog.output` | string | `stdout` | active | Audit output: stdout or a supported output sink. |
| `templates` | json | `&#123;&#125;` | active | JSON map of optional reason-specific message templates. |
| `runbooks` | json | `&#123;&#125;` | active | JSON map of reason-to-runbook URLs. |
| `app.hideProHints` | boolean | `false` | active | Remove the note that names what kwatch Pro adds from Community messages. |
| `license.key` | string | `empty` | active | kwatch Pro license key; reference it as $&#123;KWATCH_LICENSE_KEY&#125;. The KWATCH_LICENSE_KEY variable wins over this setting. Empty runs the Community edition. |
| `app.communityProvider` | string | `empty` | active | Alert provider the Community edition keeps when several are configured; empty keeps the first by name. |
| `dashboard.enabled` | boolean | `false` | active | Serve the read-only incident dashboard API on a separate listener; Pro only, off by default. |
| `dashboard.port` | integer | `8061` | active | Port for the dashboard API listener; must not equal healthCheck.port. |

## Security

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `app.insecureSkipTLSVerify` | boolean | `false` | active | Skip TLS verification for outbound providers; strongly discouraged. |
| `app.caBundlePath` | string | `empty` | active | Path to a mounted PEM bundle for outbound provider TLS. |
| `heartbeatMonitor.url` | string | `empty` | secret | External dead-man heartbeat URL; stored only through a mounted Secret. |
| `kubelet.insecureSkipVerify` | boolean | `false` | active | Skip kubelet serving certificate verification for direct node stats reads; only for self-signed kubelet certificates. |
| `healthCheck.statusEndpoint` | boolean | `false` | active | Serve the read-only /status view (object names, no authentication) on the health port; off by default. |
| `dashboard.mode` | string | `local` | active | How people reach the dashboard: local (port-forward) or shared (Ingress, https only; sign-in over plain http is refused). |
| `dashboard.trustProxy` | boolean | `false` | active | Honour X-Forwarded-Proto and X-Forwarded-For from the proxy that terminates TLS in front of the dashboard. |
| `dashboard.tlsCertFile` | string | `empty` | active | Certificate file kwatch serves on the dashboard port itself (with tlsKeyFile); reloaded when it changes. |
| `dashboard.tlsKeyFile` | string | `empty` | active | Key file for dashboard.tlsCertFile. |

## Noise reduction

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `silences` | json | `[]` | active | JSON array of scoped silence rules, including eventMessages substring matches for attached Kubernetes Events. |

## Compatibility

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `ignoreContainerNames` | list | `legacy` | deprecated | Legacy container suppression field. |
| `ignorePodNames` | list | `legacy` | deprecated | Legacy pod-name suppression field. |
| `ignoreContainerMessages` | list | `legacy` | deprecated | Legacy container-message suppression field. |
| `ignoreNodeReasons` | list | `legacy` | deprecated | Legacy node-reason suppression field. |
| `ignoreNodeMessages` | list | `legacy` | deprecated | Legacy node-message suppression field. |
| `clusterCheckins` | boolean | `empty` | deprecated | Removed: kwatch no longer sends cluster check-ins. Accepted and ignored with a deprecation notice; use heartbeatMonitor to learn when kwatch stops. |
