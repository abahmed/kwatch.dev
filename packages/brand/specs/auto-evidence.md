# Auto-evidence spec (Pro): kwatch reads, you fix

Owner: kwatch-core (`internal/notification/compose/`, provider writers,
`internal/dashboard/web`). Plan: `/Users/macos/kwatch-dev/AUTO_EVIDENCE_PLAN.md`
(decisions in its section 5). Copy follows `../MESSAGING.md`. Designer review
before merge. Extends `dashboard-phase2.md` and `community-pro-teasers.md`;
where they disagree, this file wins for auto-evidence only.

The rule, in product terms: **if a command only reads state, kwatch runs it
and shows the result. Only commands that change the cluster stay commands for
the reader.** A Pro message therefore contains zero `kubectl get`,
`describe`, `logs` or `top` lines.

Facts to respect: Pro is free during early access, no prices, no "trial".
Licenses only via the installer. Pro copy states what kwatch did, never what
the reader lacks. All example names below are invented; the shapes are what
engineers build.

## 0. Open items for the lead and kwatch-core

1. **No dashboard base URL exists in config or the chart** (checked
   `internal/config`, `internal/dashboard`, `deploy/chart/values.yaml`).
   The dashboard is off by default and, in `local` mode, only reachable by
   port-forward. A "Full evidence" link needs a new value, proposed
   `dashboard.publicURL` (Helm) / `dashboard.publicUrl` (config). With no
   value the link is **omitted**, never a localhost link, never a dead one.
   The incident URL is `{publicURL}/issues/{id}` (confirm with core).
2. Helm value names used in section 4 that do not exist yet and are
   **proposals to confirm**: `rbac.readyz`, `rbac.metricsApi`,
   `config.investigation.logs`. Existing and confirmed: `watch.secrets`,
   `rbac.mode`, `dashboard.enabled`.
3. `config.investigation.logs: false` is an opt-out, not a denial. The
   dashboard shows it as status `denied` with reason `off` (section 2.3).
4. Section 5's `N` is only true if core's coverage test (plan 3.5) passes:
   every read-only step has a covering check. Core to confirm before the
   teaser ships.

## 1. Channel messages

### 1.1 Anatomy (every provider, this order)

| # | Part | Content | Limit | Cut? |
| --- | --- | --- | --- | --- |
| 1 | Cause | Marker (existing 🔴 🟠 🟡 ✅ from real kwatch output) and one sentence naming what broke and why, in the confirmed phrasing (section 3.1) | 250 chars | Never |
| 2 | Proof | Key facts kwatch read, one per line, most decisive first | 4 facts, 200 bytes each (existing `Bounded`) | From the bottom, last facts first (cut order 3) |
| 3 | Quote | The log or event lines that carry the signature, as a mono block, labelled with container and current/previous | 5 lines, 120 runes each (existing `maxQuote`) | Trim from the top, then drop (cut order 1, 4) |
| 4 | Fix | Only steps that change the cluster, each with its sentence and command, labelled `changes the cluster` | 3 steps | **Never** |
| 5 | Footer | `Full evidence: {link}` plus the check count | 1 line | Never; omitted if no `dashboard.publicURL` |

Rules:

- Part 1 is the title/first line in every provider (it is also the `Short`
  form already used for notifications and subjects).
- Proof facts are statements, not commands: `orders-db has 0 ready
  endpoints; its selector app=orders-db matches no pod.`
- Names only for Secrets and ConfigMaps. Never values (plan 3.8).
- One message, then silence until something new is true (unchanged).
  A re-investigation that changes the cause is an update message in the
  existing update format with the same anatomy.
- Resolved messages are unchanged: no evidence, no link.
- If a check was denied or timed out and it matters to the cause, it takes
  the last proof slot as one line (section 3.3), not a fix step.
- If no cause could be confirmed, parts 2 to 4 keep the existing
  "unclear" form (`cause_unclear.go`); the footer link still shows if any
  check ran.

### 1.2 Truncation order (one deterministic function for all providers)

Applied in this order until the message fits the provider budget. Reuse
`notification.Truncate` only for the final byte safety net, never on a
whole message.

1. Quote: drop lines from the top (keep the last lines; the signature line is
   pinned and never dropped), down to 2 lines.
2. Proof: drop the "also affected" fact (blast radius), then the change fact.
3. Proof: drop facts from the bottom, down to 1 fact.
4. Quote: drop the block entirely; replace with nothing (the link carries it).
5. Cause: shorten with the existing compose shortening (clauses, not bytes).

Never cut: cause, fix steps, footer link. If cause plus fix alone exceed the
budget (Telegram 4096 is the tightest hard limit), send the cause and fix and
move the fix commands to the end, uncut. A truncated message ends the proof
section with `More in Full evidence.` so a cut is never silent. Golden tests
per provider and per cut level 1 to 5.

### 1.3 Budgets

Target is what the example messages weigh; Hard is the provider limit
(engineers confirm against the writers; figures here are the constants found
in the code or the provider's documented limit).

| Provider | Target (chars) | Hard limit | Structure |
| --- | --- | --- | --- |
| Slack | 1200 | 3000 per section text (`maxSectionTextChars`), 50 blocks | Section (cause), section (proof), section (quote in a code block), section (fix), context (footer) |
| Teams | 1500 | card about 28 KB | Adaptive Card: TextBlock (cause, bolder), FactSet or TextBlocks (proof), Container with Monospace TextBlock (quote), TextBlocks (fix, commands Monospace), ActionSet with one `Action.OpenUrl` "Full evidence" |
| Discord | 1200 | content 2000, embed description 4096, 6000 per message | One embed: title = cause, description = proof, fields `Log` (code block) and `Fix`, footer = check count, embed `url` = Full evidence |
| Telegram | 1500 | 4096 | HTML parse mode: bold cause, plain proof lines, `<pre>` quote, `<pre>` commands, last line is a link |
| Email | one screen (about 2500) | none practical | Subject = cause (`Short`). HTML body in the same order, mono blocks on Fog; plain-text alternative with identical order |
| Generic webhook | n/a | n/a | Additive JSON, section 1.5 |

Fix commands are always in a code block or mono run that copies cleanly:
one command per block, no wrapping prompt characters (`$`), no line
continuations unless the command is longer than 120 characters.

### 1.4 Example messages

Shown as plain text with the Slack mapping marked; other providers use the
same words. "Check count" in the footer is the number of checks that ran
(status ok or finding), not the number of facts.

#### A. CrashLoop: connection refused to a Service with 0 endpoints

```
🟠 checkout in shop is crash looping because it can't reach orders-db: the Service has 0 ready endpoints. Confirmed.

What kwatch found
- checkout logs: "dial tcp 10.96.14.7:5432: connect: connection refused" (container app, previous run, 4 times in 6 minutes)
- 10.96.14.7 is Service orders-db in shop. It has 0 ready endpoints.
- orders-db selects app=orders-db. The pods behind it carry app=ordersdb.
- orders-db was edited at 13:41 UTC by bob. checkout started failing at 13:42.

Log, container app, previous run
  2026-10-29T13:42:07Z connecting to orders-db:5432
  2026-10-29T13:42:07Z dial tcp 10.96.14.7:5432: connect: connection refused
  2026-10-29T13:42:07Z fatal: database unavailable

Fix (changes the cluster)
Point the Service at the label the pods carry:
  kubectl patch service orders-db -n shop --type merge -p '{"spec":{"selector":{"app":"ordersdb"}}}'

Full evidence: https://kwatch.example.com/issues/inc_7f3a · 6 checks
```

Slack mapping: line 1 section (bold lead, marker first); "What kwatch found"
section with `•` bullets; quote in a triple-backtick block under a context
line `Log, container app, previous run`; Fix section with the command in a
code block; footer context block with the link as mrkdwn `<url|Full evidence>`.

#### B. OOMKilled

```
🔴 api in shop was killed for using more memory than its 256Mi limit. Confirmed.

What kwatch found
- Last exit: OOMKilled, exit code 137, 4 restarts in 40 minutes.
- Memory climbed from 118Mi to 255Mi in 9 minutes before each kill, and never levelled off.
- The limit is 256Mi and the request is 128Mi. This is the only container in the pod.
- api:2.9 rolled out at 12:58 UTC; the 2.8 revision stayed under 140Mi.

Log, container api, previous run
  2026-10-29T13:30:51Z cache warm: 41,882 entries
  2026-10-29T13:31:12Z cache warm: 96,310 entries

Fix (changes the cluster)
Raise the limit above the observed peak (255Mi plus half again):
  kubectl set resources deployment/api -n shop -c api --limits=memory=384Mi
Or return to the revision that stayed under 140Mi:
  kubectl rollout undo deployment/api -n shop --to-revision=11

Full evidence: https://kwatch.example.com/issues/inc_9b21 · 5 checks
```

Core owns the suggested number's formula; it must come from the gathered
peak, never a fixed guess, and the sentence names the peak it used.

#### C. ImagePull: missing pull secret

```
🟠 reports in billing can't start: the registry refused the image pull because the pull secret regcred doesn't exist in billing. Confirmed.

What kwatch found
- Event: "Failed to pull image registry.example.com/team/reports:3.1: 401 Unauthorized".
- The pod spec names imagePullSecrets: regcred.
- billing has no Secret named regcred. It does have db-credentials and tls-reports.
- The tag 3.1 exists on the registry (the registry answered, so the failure is access, not the tag).

Fix (changes the cluster)
Create the pull secret in billing (use your registry user and token):
  kubectl create secret docker-registry regcred -n billing --docker-server=registry.example.com --docker-username=<user> --docker-password=<token>

Full evidence: https://kwatch.example.com/issues/inc_c4d0 · 4 checks
```

No quote block: the evidence is an event, not a log. The proof line quotes
the event. Placeholders stay literal angle-bracket words.

#### D. Missing Secret key

```
🟠 invoices in billing can't start: its Secret db-credentials has no key password. Confirmed.

What kwatch found
- Pod status: CreateContainerConfigError, "couldn't find key password in Secret billing/db-credentials".
- db-credentials has the keys host, username. It was last changed at 09:12 UTC.
- invoices reads password from it as DB_PASSWORD.
- kwatch read key names only, never values.

Fix (changes the cluster)
Add the key password to the Secret:
  kubectl edit secret db-credentials -n billing

Full evidence: https://kwatch.example.com/issues/inc_1e88 · 4 checks
```

#### E. Pending PVC

```
🟠 uploads in media is waiting for storage: its volume claim names the StorageClass fast, and the cluster has no class called fast. Confirmed.

What kwatch found
- PVC media/uploads has been Pending for 22 minutes (no volume bound).
- Its StorageClass is fast. The cluster has standard (default) and gp3.
- Event: "storageclass.storage.k8s.io \"fast\" not found".
- No volume (PV) matches the claim, so nothing can bind.

Fix (changes the cluster)
Delete the unbound claim (it holds no data), then apply it again with a class that exists:
  kubectl delete pvc uploads -n media
Set storageClassName: gp3 in your manifest and apply it.

Full evidence: https://kwatch.example.com/issues/inc_52aa · 5 checks
```

#### F. Node memory pressure

```
🟠 Node n1 is low on memory: etl in batch uses about 11 GiB of its 15.4 GiB and has no memory limit. Confirmed.

What kwatch found
- n1: MemoryPressure True since 14:07 UTC; memory use 96%.
- etl-7 (batch) uses 11.2 GiB. Next: api 1.1 GiB, web 0.6 GiB.
- Pods on n1 request 3.1 GiB in total, so the scheduler saw room that the real use took.
- api and web in shop run on n1 and are affected as well.

Fix (changes the cluster)
Cap etl so it can't take the node:
  kubectl set resources deployment/etl -n batch --limits=memory=6Gi

Full evidence: https://kwatch.example.com/issues/inc_aa07 · 5 checks
```

#### Same CrashLoop (A) per provider, structural differences only

- **Teams.** Card title = line 1. Proof as a FactSet with title cells
  `Logs`, `Service`, `Selector`, `Change`. Quote in a Container with
  `fontType: Monospace`, `wrap: false`, `maxLines: 5`. Fix as a TextBlock
  plus a Monospace TextBlock. One action `Full evidence`. No `Action.Submit`.
- **Discord.** Embed colour: severity token (failing, degraded, resolved).
  Proof as the description. Fields `Log (app, previous)` and `Fix (changes
  the cluster)` as code blocks. Footer `6 checks`. Title links to the incident.
  If the description would pass 4096 characters, apply cut order 1 to 4.
- **Telegram.** `<b>` cause. Proof as lines starting `- `. `<pre>` quote.
  `<pre>` fix command. Last line `<a href>Full evidence</a> · 6 checks`.
  Escape `<`, `>`, `&` in log text; never let a log line close a tag.
- **Email.** Subject: `checkout in shop is crash looping: orders-db has 0 ready endpoints`.
  Body: cause as a 20px heading line, then four labelled blocks (What
  kwatch found, Log, Fix), button-style link `Full evidence` in Ink on
  Paper (never Signal, never a coloured fill beyond the severity chip).
  Mono blocks on Fog, text in Ink, light only; dark is left to the mail client
  (use `color-scheme: light dark` and Fog/Ink inversion via media query).
  Plain-text part has the same order and ends with the bare URL.

### 1.5 Generic webhook (additive only)

Existing fields are untouched. Add one object; consumers that ignore it keep
working. Cut order does not apply (JSON is not rendered), but the same caps
apply to the arrays so payloads stay small.

```json
"evidence": {
  "confirmed": true,
  "checks": 6,
  "facts": ["checkout logs: ...", "10.96.14.7 is Service orders-db ..."],
  "quote": { "container": "app", "run": "previous", "lines": ["..."] },
  "fix": [{ "text": "Point the Service at the label the pods carry",
            "command": "kubectl patch service ...", "mutating": true }],
  "url": "https://kwatch.example.com/issues/inc_7f3a"
}
```

`url` is absent, not empty, when no `dashboard.publicURL` is set. Every
`fix[].mutating` is true in Pro. Community payloads do not carry `evidence`.

## 2. Dashboard: the Evidence tab

Source of truth for data: plan 3.1 and 3.7 (`GET /api/incidents/{id}` gains
`evidence: [Section]` and `correlation`). Shell, tokens, CSP, breakpoints and
the one-Signal rule are as in `dashboard-phase2.md` section 0: no inline
script or style, `textContent` for every API string, mono blocks on `--ink`
in both modes.

### 2.1 Page structure

The incident page gains two tabs under the title and chips. Tab 1 is today's
page unchanged (Why it happened, What to do, What kwatch saw, What happened
in order, Facts). Tab 2 is new.

```
< Active issues
[urgent] [confirmed]
checkout in shop is crash looping because it can't reach orders-db

 Summary | Evidence 6                          <- tablist, count = checks

```

- `role="tablist"`; tabs are links (`?tab=evidence`) so a link opens the
  right tab and back/forward works; the active tab has `aria-selected="true"`
  and weight 600; the count is part of the accessible name ("Evidence, 6
  checks").
- Tab title: `Evidence: checkout - kwatch`.
- The "What to do" section stays on Summary (and is repeated, collapsed, at
  the bottom of Evidence as `Fix`, so nobody has to switch back).
- Community (no `evidence` in the response): no tab strip, the page is
  exactly today's page.

### 2.2 Evidence tab layout

Desktop (content `--max-app` 1000px; main column about 640px, side column
about 300px, uneven on purpose):

```
 Evidence                                           [Expand all] [Collapse all]
 6 checks ran in 3.2 s at 13:44 UTC. 5 read, 1 not allowed.

 +- Correlation --------------------------------------------+  +- Related ---------+
 | Confirmed: checkout can't reach orders-db because ...    |  | Ingress    -      |
 |  Signature   connection refused to 10.96.14.7:5432       |  | Service    orders-db
 |  Matches     Service orders-db, 0 ready endpoints        |  |   0 ready endpoints
 |  Change      Service edited 13:41 by bob, 1 min before   |  | Endpoints  none   |
 |  Spread      3 of 3 checkout pods, node-independent      |  | Pods       2 ordersdb
 +----------------------------------------------------------+  |   (labels do not  |
                                                                |    match selector)|
 v Pod state                                       [ok]         +-------------------+
   Phase Running, container app waiting (CrashLoopBackOff)...
 v Logs                                            [ok]
   Container [app v]   Run (o) Previous ( ) Current   5 of 200 lines  [Copy all]
   +--------------------------------------------------------+
   | 13:42:07Z connecting to orders-db:5432                 |
   | 13:42:07Z dial tcp 10.96.14.7:5432: connection refused | <- matched
   +--------------------------------------------------------+
 v Events                                          [ok]
 v Service and endpoints                           [ok]
 > Secrets                                         [not allowed]   (collapsed)
 > Metrics                                         [timed out]

 Fix                                      (what to do, same text as Summary)
```

Order: Correlation first (the answer), then one section per check in the
priority order core uses for the summary, then Fix. Related objects sit in
the side column (desktop) and move **above** the check sections on tablet and
mobile.

### 2.3 Check section

One collapsible `<section>` per check: a button heading (`aria-expanded`),
the title, the status badge, and a one-line result when collapsed.

| Status | Badge word | Badge style | Body | Default |
| --- | --- | --- | --- | --- |
| `ok` | `Read` | neutral (`--surface`, text), never green fill | Facts as a `dl`, lines as a mono block | Expanded if it carries the cause or the matched signature, else collapsed |
| `denied` | `Not allowed` | `--degraded` chip inside an alert-like row | Denied text (3.3) | Expanded |
| `timeout` | `Timed out` | `--degraded` chip inside an alert-like row | Timeout text (3.4) | Expanded |
| `absent` | `Nothing to read` | neutral | Absent text (3.5) | Collapsed |

- Denied with reason `off` (opt-out): badge `Turned off`, same colour as
  `denied`, body per 3.3.
- Badge word is always present; colour is never the only signal.
- Facts: `dl` with term/definition, values in Geist Mono when they come from
  the cluster (names, ids, numbers with units).
- Every section shows `Read at 13:44:02 UTC` (a `time` element) in its
  footer in text-muted, and when it comes from a re-investigation,
  `Updated 13:46 UTC`.

### 2.4 Log viewer

- Controls row: container `select` (labelled "Container"), a two-option
  segmented control "Previous run | Current run" (`role="radiogroup"`; default
  Previous when the pod restarted, else Current), line count (`Showing 5 of
  200 lines`), and `Copy all` (text button, copies what is shown, redacted).
- Viewer: `role="region"` with `aria-label="Log of container app, previous
  run"` and `tabindex="0"`, Geist Mono 13px, no wrap with horizontal scroll,
  line numbers in a non-selectable column (CSS `user-select: none`, not part
  of Copy), up to 500 lines per section.
- Signature lines are marked with a 3px left bar in Ink-on-Ink contrast
  (`--ink-line`, lighter) **and** the word `matched` in the gutter for
  screen readers and monochrome: the bar is decoration, `matched` is the
  signal. The first matched line is scrolled into view on open.
- Empty states: `No previous run. This container has not restarted.` /
  `This container wrote nothing yet.` / denied and timeout per section 3.
- Containers with no logs captured (init containers that never ran) are
  listed in the select as `name (not started)` and disabled.
- Multiple pods (label-matched, deduplicated by signature): a first
  `select` "Pod" appears only when more than one distinct signature exists;
  otherwise a note `Same output in 3 of 3 pods.` replaces it.

### 2.5 Related objects chain

A chain from the failing object toward what it depends on or serves, each
node one row: kind (text-muted), name (mono), state word.

```
Ingress   storefront        Ready
  Service   orders-db      0 ready endpoints
    Endpoints  orders-db   none
      Pods     2 matching by IP, 0 matching by selector
```

- Desktop side column: vertical list with a 1px `--line` connector; wide
  content area (Evidence tab at >960px with no side column space, or in the
  Correlation block) may lay it out horizontally with `>` separators.
- At or below 700px: vertical list only, full width.
- The broken node (first node whose state breaks the chain) has the word
  `breaks here` and a `--degraded`/`--failing` chip according to severity.
  Colour only inside this chip. The rest of the chain stays neutral.
- Each node links to nothing (the dashboard is read-only and has no object
  pages); copy button for the name only (`Copy orders-db`).
- Healthy neighbours are shown collapsed as `+ 3 more pods` (a `button`
  that expands).

### 2.6 Correlation block

One card at the top of the tab. Heading `Correlation`, then the confirmed
sentence (3.1), then up to four rows (term/definition), in this fixed order,
omitting rows with nothing to say:

| Row | Content |
| --- | --- |
| Signature | The classified log line: what, and to which host/port |
| Matches | The cluster object the signature points to and its state |
| Change | Closest change before the first failure: who, what, how long before |
| Spread | Same signature across pods or nodes; `Only this pod` when it is one |
| Before and after | Rollouts only: what differs between the failing and the last healthy revision (image, env key names, resources) |

Each row ends with `Read from {check title}` as text-muted, so every claim
traces to a section below; the check title is plain text on desktop and an
anchor link (`#check-logs`) that expands and focuses that section.

When confidence is `Likely` (not confirmed): heading stays, sentence uses the
"likely" form (3.1), and a single line states what would confirm it:
`kwatch could not read {X}, so this stays likely.`

### 2.7 Responsive, dark, accessibility

- Breakpoints 960 / 700 / 480 as in `dashboard-phase2.md`. At <=960 the side
  column drops under Correlation. At <=700 the check headings wrap: badge
  moves under the title; controls row of the log viewer stacks (container
  select full width, then radio group, then count and Copy). At <=480 log
  font 12px, gutter 16px.
- Light and dark follow the system. Log, commands and any mono block:
  `--ink` background, `--ink-text`, `--ink-line` borders in both modes.
  Badges and chips use the paired `-bg` tokens; check contrast of
  `--degraded` on `--degraded-bg` in dark.
- Signal: still exactly one element per view, the kwatch mark. Do not use
  Signal for `matched`, active tab, focus or buttons.
- Keyboard: tabs follow the tablist pattern (arrow keys move, Enter
  activates); section headings are buttons reachable by Tab; the log region
  is focusable and scrolls with arrow keys; `Escape` does nothing special.
- `aria-live="polite"` on the "ran in" summary and the badge text only when a
  re-investigation updates a section; never announce on first load.
- Focus ring uses the existing `--focus` token; sections never trap focus.
- Reduced motion: expand/collapse is instant; no transitions on the log.
- Print: sections all expanded, logs not truncated to viewport.
- All strings via `textContent`; log text is untrusted (CSP forbids inline,
  but also do not interpret ANSI: strip escape sequences in the capture).

## 3. Copy (exact strings)

Style: say the cause, then the fix. Calm, specific, no exclamation marks, no
emoji in dashboard (emoji markers stay only in channel text), no "trial",
no prices. Cluster names in Geist Mono where the surface supports it.

### 3.1 Confirmed and likely cause

Confidence ladder (reuse existing `Confidence` strings for the rest):

| Level | When | Phrasing |
| --- | --- | --- |
| Confirmed | A gathered fact matches the predicted cause (the rule in plan 3.4) | `{Subject} {fails} because {cause}.` then the word `Confirmed.` as a separate short sentence in channels; chip `Confirmed` in the dashboard |
| Likely | Cause fits the evidence but one check was denied, timed out or missing | `{Subject} {fails}, most likely because {cause}.` chip `Likely` |
| Unclear | No cause fits | Existing unclear text; no chip |

Patterns (fill with real names; one `because`, no stacked clauses):

- Crash with unreachable dependency: `checkout in shop is crash looping because it can't reach orders-db: the Service has 0 ready endpoints.`
- OOM: `api in shop was killed for using more memory than its 256Mi limit.`
- Image: `reports in billing can't start: the registry refused the image pull because the pull secret regcred doesn't exist in billing.`
- Config: `invoices in billing can't start: its Secret db-credentials has no key password.`
- Storage: `uploads in media is waiting for storage: its volume claim names the StorageClass fast, and the cluster has no class called fast.`
- Node: `Node n1 is low on memory: etl in batch uses about 11 GiB of its 15.4 GiB and has no memory limit.`

The word `Confirmed` is only used when at least one proof fact is shown or
linked. If a message is cut to the point of no proof fact (cut order 3 floor
is 1 fact), the fact stays.

Footer text: `Full evidence: {link} · {N} checks` (`1 check` when N is 1).
Dashboard summary line: `{N} checks ran in {S} s at {time} UTC. {R} read, {D} not allowed, {T} timed out.` Omit zero parts; if all
read: `{N} checks ran in {S} s at {time} UTC. All read.`

### 3.2 Section titles (the check names)

`Pod state`, `Logs`, `Events`, `Memory use`, `Node`, `Pods on this node`,
`Volume`, `Secrets and ConfigMaps`, `Service and endpoints`, `Ingress`,
`Webhook`, `Rollout`, `Control plane`, `Image`, `Certificates`, `Quota`,
`Autoscaler`, `Job`, `Probes`, `Correlation`. Sentence case, no "Check:"
prefix.

### 3.3 Denied read (status `denied`)

Pattern: `kwatch isn't allowed to read {what}. {Effect}. To allow it, set {value} in your Helm values, or run the installer's Update menu.`

The effect sentence says what the reader still gets and stays positive:

| What | Text |
| --- | --- |
| Pod logs | `kwatch isn't allowed to read pod logs. The rest of the evidence is shown. To allow it, set rbac.mode and check that pods/log is granted in your Role, or run the installer's Update menu.` Helm value named: `rbac.mode` (existing; default grants `pods/log`). |
| Secrets (names only) | `kwatch isn't allowed to read Secret names in {namespace}. Other checks are shown. To allow it, set watch.secrets: true in your Helm values.` |
| Readiness endpoint | `kwatch isn't allowed to read the control plane's readiness endpoint. To allow it, set rbac.readyz: true in your Helm values.` (proposed value) |
| Metrics API | `kwatch isn't allowed to read the metrics API, so memory use over time isn't shown. To allow it, set rbac.metricsApi: true in your Helm values.` (proposed value) |
| Any other kind | `kwatch isn't allowed to read {kind} in {namespace}. To allow it, set rbac.mode: full in your Helm values, or grant get on {kind} in your Role.` |
| Opt-out (`off`) | `Log capture is turned off (investigation.logs: false). Set investigation.logs: true to show logs here.` Badge `Turned off`. |

Rules: name exactly one value; code spans (backticks in docs, mono in UI).
Never use "denied", "forbidden", "blocked" or "failed" in user text (status
word is `Not allowed`). "The installer's Update menu" is only used when the
kwatch.sh installer has such a menu; core to confirm, else drop the clause
and keep the Helm value.

In a channel message, a denied read that matters becomes one proof line:
`kwatch isn't allowed to read pod logs, so the crash output isn't shown. Details in Full evidence.` and the cause moves to `Likely`.

### 3.4 Timeout (status `timeout`)

Dashboard body: `This check took longer than {S} s, so kwatch moved on. The other checks are shown. kwatch looks again at the next update.`

Channel proof line (only when it matters): `The {check title} check took longer than {S} s. Other checks are shown.`

If the overall 10 s budget ended the plan: summary line (3.1) ends with
`{T} timed out.` and no per-section apology.

### 3.5 Absent (status `absent`)

The check ran and the thing is not there. Specific to the check:

| Check | Text |
| --- | --- |
| Logs, previous | `No previous run. This container has not restarted.` |
| Logs, current | `This container has written nothing yet.` |
| Ingress | `No Ingress routes to this Service.` |
| Webhook | `No admission webhook touches this object.` |
| Any other | `Nothing to read here: {object} doesn't exist in {namespace}.` |

Absent is not an error: neutral badge `Nothing to read`.

### 3.6 Other dashboard strings

- Tab: `Summary`, `Evidence`.
- Buttons: `Expand all`, `Collapse all`, `Copy all`.
- Footer of the tab (replaces the read-only note's position): `This page is read-only. To change anything, use the commands under Fix.`
- Page `aria-label` for the chain: `Related objects`.
- Redaction note, under logs, text-muted: `Credentials are hidden in these lines.` (true: redacted at capture and
  at serve).

## 4. Tokens and type (no new tokens)

All from `packages/brand/tokens.css`: `--bg`, `--surface`, `--line`, `--text`,
`--muted`, `--ink`, `--ink-text`, `--ink-line`, `--failing(-bg)`,
`--degraded(-bg)`, `--resolved(-bg)`, `--focus`. Type: Bricolage Grotesque
800 for the page title only, Instrument Sans for text and controls, Geist Mono
for every string from the cluster (names, commands, log lines, numbers with
units). Signal: none beyond the kwatch mark. No gradients, no icons beyond the
existing sprite (`#i-back`); expand/collapse uses a CSS chevron drawn with
borders, not a stock icon.

## 5. Community: "Pro gathered N checks" teaser

**Recommendation: do not show "Pro gathered N checks" in Community.** Community
does not gather anything, so a number of checks gathered would be invented.
That breaks the rule not to promise what the code does not do.

**Yes to a count that is true: the number of read-only commands in the message
itself.** A Community message already lists them. Pro runs exactly those
(guaranteed by the coverage test, plan 3.5). The teaser says so, once, in the
existing Pro line slot of `community-pro-teasers.md`.

Copy (replaces the per-type note when N >= 1, exact strings):

- N = 1: `Pro runs this check for you and shows the result. Get Pro free during early access: kwatch.dev/pro`
- N >= 2: `Pro runs these {N} checks for you and shows the result. Get Pro free during early access: kwatch.dev/pro`

`N` is the count of non-mutating steps in that very message (`Step.Mutating
== false`), so it is always right and never needs interpolating facts. If the
message has no read-only steps (for example only a fix), use the existing
per-type note from `community-pro-teasers.md`.

Rules (same as that spec):

- One Pro line per alert, last line, never before the cause or the fix.
- Only in alerts that already show read-only steps; never in resolved
  messages; removed by `app.hideProHints: true`.
- Never name what Pro would find. The count describes work, not findings.
- Plural/singular as above. No urgency, no "upgrade", no exclamation mark, no
  prices, no "trial", no emoji.
- Slack: context block. Plain text: last line. Length-limited channels: drop
  the second sentence.

Section 3 of the teaser spec (count-only line for startup/weekly) is
unchanged. Community output stays byte-identical to today's goldens except
the Pro line, so the golden diff for Community is exactly that line.

Example, Community CrashLoop:

```
🟠 checkout in shop is crash looping. It fails with "dial tcp 10.96.14.7:5432: connect: connection refused". To read the output of the last crash, run kubectl logs checkout-5c8 -c app -n shop --previous
Pro runs this check for you and shows the result. Get Pro free during early access: kwatch.dev/pro
```

## 6. States checklist for engineers

- Channel: confirmed, likely, unclear; with and without `publicURL`; each of
  the six scenarios; every cut level 1 to 5; denied-and-matters; timeout-and-
  matters; resolved (unchanged); Community with N=0, 1, 3.
- Dashboard: tab strip present only with `evidence`; each of ok / denied /
  timeout / absent / off per check; logs with previous and current, with
  multiple containers, with multiple pods and distinct signatures, with none;
  chain with a break at each level; correlation with 0 to 4 rows; light and
  dark; 480, 700, 960 and desktop; keyboard only; screen reader name for
  tabs, badges and the log region.
- Goldens: one per provider per scenario in `compose/testdata/`; Community
  goldens unchanged except the new Pro line.

## 7. Spec changes to confirm with the lead

- `Full evidence` link depends on a new public URL value (section 0.1).
- The proposed Helm value names (0.2).
- Plan decision 3 ("designer proposes") is answered by section 5; lead to
  approve before core builds it.
