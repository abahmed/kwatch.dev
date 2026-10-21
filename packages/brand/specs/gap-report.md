# Gap report copy (Pro)

Owner: kwatch-core (`internal/app/startup_message.go`). Copy follows
`../MESSAGING.md`. Strings are final; placeholders in `{braces}`. No
engineering in this file.

## What it says, and what it does not

The gap report compares the cluster before and after the gap. It reports the
net difference, not the journey. So:

- A cluster shut down overnight and back unchanged reports nothing.
- Something changed and changed back is not shown.
- Who made a change is never known; say so once, do not guess.
- Problems still broken after the restart are normal incidents and are not
  repeated in this message.
- Crashes are only counted on nodes that did not reboot during the gap.

Applies when the gap is 5 minutes or more (`minReportableDowntime`).
Marker stays `MarkerNotify` as today. No emoji beyond the marker kwatch
already prepends. Sent as one message; plain text, readable in Slack, Teams
and email.

## Shared opener (all Pro cases)

`kwatch was not running from {HH:MM} to {HH:MM} UTC ({duration}).`

Same time format as today (`15:04`, UTC, `format.Duration`).

## (a) Nothing found

`{opener} Compared with before, nothing changed and nothing crashed.`

Example: `kwatch was not running from 02:10 to 07:45 UTC (5h 35m). Compared with before, nothing changed and nothing crashed.`

## (b) Changes and/or crashes found

```
{opener} Since then:

Changed (who is unknown, kwatch was down):
- {Kind} {namespace}/{name}: {path} changed
- Node {name}: taints changed

Crashed:
- {namespace}/{pod}, container {container}: last stopped by OOMKilled, {n} restarts in total
- {namespace}/{pod}, container {container}: last stopped with exit code {code}, {n} restarts in total

Anything still broken is reported as its own incident.
```

Rules:
- Omit the `Changed` or `Crashed` block when it is empty (with its blank line).
- `{path}` is the attribute path kwatch already uses (`spec.template`,
  `data`, `taints`). Do not invent a friendlier name, and do not claim
  "new image" unless the path says so.
- Cap: 10 items in total across both blocks, changes first, then crashes.
  The rest collapse into one line directly under the last block, before the
  closing sentence: `and {N} more.`
- Count: the container's total restart count, not restarts inside the gap: `1 restart in total`, `{n} restarts in total`. Only the last stop is shown.
- Reason: `OOMKilled` or `exit code {code}`. Never both on one line.
- Layout in Pro: the startup sentence first, a blank line, then this report, as one message.
- Closing sentence is always shown.

Example:

```
kwatch was not running from 02:10 to 07:45 UTC (5h 35m). Since then:

Changed (who is unknown, kwatch was down):
- Deployment shop/api: spec.template changed
- ConfigMap shop/api-config: data changed

Crashed:
- shop/worker-6d9f, container worker: OOMKilled, 3 times

Anything still broken is reported as its own incident.
```

## (c) What can't be seen

Show only when at least one node went not-ready during the gap (a reboot that never turned the node NotReady is not detected, so the line never says "rebooted"), appended as the
last line of (a) or (b), before the closing sentence in (b):

`Crashes on {N} node(s) that went not-ready during the gap can't be told apart, so they are not listed.`

Use `1 node that went not-ready` / `{N} nodes that went not-ready` (pick singular or
plural; the `(s)` above is not literal). Do not add any "not seen" line
otherwise: the report already states the rule of comparing before and after.

## (d) Community (not entitled)

Today's message is unchanged. Append one sentence, after the existing
"... went unreported":

`Pro adds a gap report: what changed and what crashed meanwhile. Free during early access.`

Same trailing period handling as today. No link in the message; the
installer's License / Pro menu is the only place keys are managed. No
"trial", no price, no countdown.

## Claims to confirm with kwatch-core before merge

- Crash counts come from last-termination state inside the gap, not from
  events (events may have expired).
- "Rebooted" detection is per node and complete enough to omit those crashes.
- Changes include nodes, ConfigMaps, Secrets, workloads, services, webhooks
  (list in `pipeline/downtime.go`), so the `Changed` block never promises a
  kind that is not tracked.

## Accessibility and dark/light

Plain text with hyphen lists; no colour or emoji needed to read it. Names
and paths come from the cluster; they are monospace in any surface that
renders it (Geist Mono in the app preview).
