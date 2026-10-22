# Community alerts that point to Pro (copy spec)

Owner: kwatch-core (`internal/notification/compose/community.go`, /status,
installer License / Pro screen). Docs and web reuse the table in section 6.
Copy follows `../MESSAGING.md`. Designer review before merge.

## Principles

- At most one Pro line per alert. It never comes before the cause or the
  fix. It is the last line of the message.
- Say what Pro shows, not what the reader is missing. No urgency, no
  "upgrade", no "trial", no prices, no exclamation marks, no emoji.
- Pro is free during early access, so the way in is always the installer:
  `Get Pro free during early access: kwatch.dev/pro`.
- Never mention `kwatch license` commands. Licenses are handled only
  through the kwatch.sh installer's License / Pro menu.
- `app.hideProHints: true` removes the per-alert line, the root-cause teaser
  and the count-only line in the startup/weekly message. /status and the
  installer screen keep their count line, because the user asked for them.
- A resolved alert carries no Pro line (unchanged).
- Never name or describe a Pro finding in Community. Counts by category only.

## 1. Alert line (Slack and plain text)

Format: the note, then one link, as one line in the footer style of the
message (Slack: context block; plain text: last line).

```
{note} Get Pro free during early access: kwatch.dev/pro
```

If the channel limits length (SMS-style, 160 characters), drop the second
sentence and keep `{note}`.

Choosing the note: pick the first row that matches the incident's root kind
and reason. If nothing matches, use Generic.

## 2. Per-alert-type notes (exact strings)

| Type | Reasons covered | Note |
| --- | --- | --- |
| Crash | CrashLoopBackOff, Error exit, liveness/startup failures | `Pro would show the change that caused this crash.` |
| OOM | OOMKilled | `Pro would show what changed memory use and the limit to set.` |
| Image | ImagePullBackOff, ErrImagePull, InvalidImageName | `Pro would show who changed the image and when.` |
| Pending | Pending, Unschedulable | `Pro would show which nodes were ruled out and why.` |
| Node | NodeNotReady | `Pro would show which pods this node took down.` |
| Generic | anything else (config errors, Evicted, Failed, Terminating) | `Pro would show the recent change behind this and the services it affects.` |

Rules for engineers:

- Show a note only when the engine found something Pro would show (as
  `proNote` does today). If it found nothing, show no note.
- Notes are fixed strings, not built from the finding. Do not interpolate
  names, counts or details.
- Where the finding is a shared factor or a recent change, the teaser in
  section 5 replaces the note (still one line).

## 3. Count-only line (startup, weekly, /status, installer)

In Community the Pro detectors run and only count. Categories (exact
labels, this order, lowercase in sentences):

`readiness probes`, `shared causes`, `preemption and admission`,
`scheduling gates`

(Use `Pro checks` as the collective noun. "Issues" means findings, not
alerts.)

### Startup / weekly message

```
Pro checks found 7 issues in the last 7 days: 4 readiness probes, 2 shared causes, 1 preemption and admission. Get Pro free during early access to see them: kwatch.dev/pro
```

- Weekly: window is "the last 7 days". Startup: `since kwatch started`.
- Omit categories with 0. Singular/plural by count: `1 issue`, `1 shared cause`.
- Zero total: send nothing (no "Pro found 0 issues").
- Appears at most once per message, never in an alert.

### /status (text)

One line under the cluster summary, same wording without the link sentence:

```
Pro checks: 7 issues in the last 7 days (4 readiness probes, 2 shared causes, 1 preemption and admission). Details are in Pro.
```

Zero total: `Pro checks: no issues in the last 7 days.`

### Installer, License / Pro screen

Body line above the menu items:

```
Pro checks found 7 issues in the last 7 days: 4 readiness probes, 2 shared causes, 1 preemption and admission.
Pro is free during early access. Choose "Add or replace key" to see them.
```

Zero total: `Pro checks found no issues in the last 7 days.` and only the second
line.

## 4. Metrics endpoint (moved to Pro)

Community: the endpoint is off. When a user sets it in config, log once at
startup (cluster output, mono):

```
metrics endpoint is part of Pro. Pro is free during early access; add a key in the installer's License / Pro menu.
```

No Pro line in alerts for this.

## 5. Root-cause teaser

Shown when a Pro-only analysis (shared factor or recent change) explains a
Community incident. The cause is not shown, not hinted, not named.

```
Pro found a likely cause for this. Get Pro free during early access: kwatch.dev/pro
```

- Replaces the section 2 note for that alert (one Pro line total).
- Not shown if the Community one-line cause already names the same cause.
- Never include node, change, user or time. Never say "likely cause is X".
- Do not say "we found", it implies the data left the cluster. Use the
  wording above.

## 6. Community vs Pro (for docs and web)

| | Community | Pro |
| --- | --- | --- |
| Pod crash, CrashLoop, OOM, image pull, config errors | Yes | Yes |
| Pending, Unschedulable, Evicted, Failed, stuck Terminating | Yes | Yes |
| Liveness and startup probe failures | Yes | Yes |
| Node NotReady | Yes | Yes |
| One-line cause | Yes | Yes |
| Dedupe, namespace filters, ignore lists, silences | Yes | Yes |
| Providers | 1 | All, 50+ channels |
| /status | Short | Full |
| Readiness probe failures | No | Yes |
| Shared-factor causes ("node X explains N failures") | No | Yes |
| Recent change and who made it | No | Yes |
| Prometheus /metrics endpoint | No | Yes |
| PodPreempted, PodPreemptedRepeatedly, PodAdmissionRejected, PodKilledAtGrace, SchedulingGated | No | Yes |
| Everything else Pro adds (proof, affected services, logs) | No | Yes |

Footnote under the table: `Community is free forever. Pro is free during
early access. In Community, Pro checks still run and show how many issues
they found, by category only.`

Use "Yes"/"No" or the check and dash from MESSAGING.md section 3. No price
row.

## 7. Open questions for the lead

- "Everything else Pro adds" and "Full /status", "All providers" assume the
  lists in the current code; kwatch-core to confirm before docs copy ships.
- The counts are computed in-cluster. Confirm no count is sent to kwatch.dev
  (the data small print in MESSAGING.md says only stats and license checks
  are sent).
- Category labels above are proposals; core to confirm they match the
  detectors' categories.

## Accessibility and tone checks

- All lines are plain text, readable without color or link.
- Link text is the visible URL, never "click here".
- Lines stay under 160 characters except the weekly count line, which may wrap.
