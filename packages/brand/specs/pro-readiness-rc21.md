# Pro readiness before v1.0.0-rc.21: four features

Status: draft for the lead. Specs only, no production code.
Audience: paying Pro users who are new to Kubernetes. Copy follows `MESSAGING.md`: Pro is free during early access (no prices, no "trial"), install is installer-first, licenses live only in the installer's License / Pro menu, "source available". Free tiers only (Cloudflare Workers and D1, Resend; no new paid service).

**Decisions (user, final):** Resend quota is limited, so (1) the managed heartbeat sends no notification of any kind (no email, no webhook): the app only shows each cluster's last seen and a silent state computed on read; (2) support sends exactly one text-only email per request, to the support inbox with Reply-To set to the user, and no confirmation email; (3) no file is ever uploaded to our API: diagnostics are saved to a file on the user's machine and attached by the user to their own email reply. Existing sign-in and license emails are unchanged.

Owners: kwatch-core (Go, `kwatch test-alert`, managed ping), kwatch-web (`kwatch.sh`, `/support`), kwatch-api (Worker, D1), kwatch-app (app.kwatch.dev).

## Shared rules

- Words: say the cause, then the fix. No "oops", no "something went wrong". No emoji on kwatch.dev or app.kwatch.dev. The installer (`kwatch.sh`) keeps its existing emoji menu style.
- Signal (#C8F542, #B5DE3C dark) is never text on white and appears at most once per view. All new buttons here are Ink (primary) or outline (secondary). Status colours appear only inside alert-like blocks: failing #E5484D, degraded #F5A524, resolved #2F80ED.
- Cluster output (commands, `/status`, filenames, ids) is Geist Mono. Headings Bricolage Grotesque 800. Text Instrument Sans.
- Light and dark follow the system. Every text/background pair is at least 4.5:1, borders and focus rings at least 3:1. Hit targets 44px. Layout works from 320px; one column under 640px.
- New to Kubernetes: first use of a term per page is explained with the glossary line from `MESSAGING.md` section 4.
- Never promise a response time, delivery guarantee or uptime. "Sent" means "the channel accepted it".

---

## 1. Managed heartbeat: "see when my cluster goes quiet"

### 1.1 What it is, and what it cannot say

kwatch Pro pings `api.kwatch.dev` every 30 minutes. app.kwatch.dev shows each cluster's last seen time, and marks it **silent** when nothing has been heard for 60 minutes. **Nothing is sent to anyone**: no email, no webhook, no push. The user looks at the app. (Notifications are a later decision.)

A cluster that is shut down on purpose (for example a staging cluster scaled down after work hours) is **not** silent. When kwatch stops cleanly it sends a last "stopping" check-in, and the app shows the neutral state **Stopped** until the next check-in. Silent means check-ins stopped *without* a clean stop.

The app must be honest about what silence means: **kwatch stopped talking.** The cluster may be fine. Three usual causes: the kwatch pod stopped, the cluster or node is down, or the cluster lost outbound access to `api.kwatch.dev`.

**No high availability in v1.** kwatch runs as one pod, so one cluster has one check-in sender. If that pod is down, the cluster is Stopped or Silent; there is no second replica to take over. The app and docs must not suggest otherwise.

Name in all UI: **Cluster check-ins** for the feature and **Silent** for the state (not "alerts", because nothing is sent). Never "uptime monitoring", never "we monitor your cluster", never "we will notify you".

### 1.2 Relation to the existing heartbeat monitor

`kwatch/internal/heartbeat` (config `heartbeatMonitor`) GETs a URL the user owns (Healthchecks.io and similar), only while monitoring is ready. It stays unchanged and is the way to actually get notified today.

| | Your URL (existing) | Cluster check-ins (new) |
|---|---|---|
| Who watches | A service you choose | kwatch Worker |
| Needs | An account elsewhere | Pro license, app.kwatch.dev sign-in |
| Where you hear | Whatever that service sends | You look at the Clusters page |
| Config | `heartbeatMonitor.url` | License / Pro menu toggle |

They can run together. The app links the existing option: `Want a message when it goes quiet? kwatch can ping a monitor you own.` Reuse the same readiness rule: no ping while kwatch is not ready, so a pod that is up but not monitoring is quiet. Keep the ping separate from the daily `/license/renew` (24h lease, unchanged).

### 1.3 Defaults and toggle

- **On by default** for an active Pro license, announced once when a key is added or moved in the installer: `Cluster check-ins are on. Turn them off in License / Pro.`
- **Ping every 30 minutes. Silent after 60 minutes** (two missed pings). Both are fixed; no setting, no threshold control.
- **Toggle:** installer, License / Pro submenu (the pod sends the ping and the installer owns config). The app shows the state read-only with `Change it in the installer: License / Pro > Cluster check-ins.`
- **Clean stop:** on graceful shutdown (SIGTERM, within the pod's termination grace period) kwatch makes one best-effort check-in with `stopping: true`, with a 2-second limit so it never delays shutdown. A crash, OOM kill, node loss or lost network sends nothing, so those show Silent. Scaling a Deployment to zero, `kubectl delete`, and a node drain are clean stops.
- Turning off sends one final `{"checkins": false}` ping so the app shows `Check-ins off` instead of a false silence. If that ping fails the app shows the cluster as silent until the key is removed or moved; the installer says so.

### 1.4 Installer: License / Pro submenu

Current items: Show license status, Add or replace key, Move license to this cluster, Remove key, Back. Insert after Show license status:

```
 Cluster check-ins: on   (change)
```

Selecting it opens:

```
Cluster check-ins

  kwatch checks in with api.kwatch.dev every 30 minutes. If it goes quiet
  for 60 minutes, app.kwatch.dev shows this cluster as silent.
  Nothing is sent to you. Sent: a hashed cluster ID, the kwatch version,
  the node count and the cluster name if you set one.

  > Turn off
    Back
```

When off the first row reads `Turn on`. Success: `Cluster check-ins are on. The first check-in follows within 30 minutes.` / `Cluster check-ins are off.` Failure: `Could not change Cluster check-ins: <reason>. Nothing was changed. Run the installer again after fixing it.` The item exists only with an active key (absent otherwise, not greyed).

### 1.5 Worker behaviour (contract for kwatch-api)

- New route `POST /license/ping`, instance-authenticated like `/license/renew` (unversioned path). Body at most 256 bytes: `{kwatch_version, node_count, cluster_name?, checkins, boot_id, stopping?}`. `boot_id` is a random id made when the process starts, sent on every check-in. `204` on success. A ping within 25 minutes of the last is acknowledged without a write.
- D1 (LICENSE_DB, migration `0006`), columns on the activation: `last_ping`, `checkins` (0/1), `boot_id`, `stopped_at` (null unless stopped), `recovered_at`, `quiet_seconds`. On each ping, in the same single `UPDATE`: if `now - last_ping` exceeded 60 minutes, set `recovered_at=now` and `quiet_seconds=now-last_ping`.
- **Stopping check-in:** applies only when its `boot_id` equals the stored one (set by that process's earlier check-ins); it sets `stopped_at=now` and `last_ping=now`. Otherwise it is acknowledged and ignored. This matters in a rolling update: the new pod checks in before the old pod sends its stopping check-in, and the old pod's stop must not mark the cluster Stopped. Any normal check-in clears `stopped_at`; if the gap since `last_ping` exceeded 60 minutes and the cluster was not Stopped, it records `recovered_at` as before (a restart after a clean stop records nothing).
- **No cron and no stored state.** Silent is computed on read: `stopped` when `stopped_at` is set; else `silent` when `checkins=1 AND now - last_ping > 60 min`. The existing daily cron is untouched. Nothing else calls Resend or `fetch`.
- Free-tier budget: one cluster is 48 pings a day, so about 48 Worker requests and 48 D1 row writes. Free tier is 100k of each per day, so the ceiling is about 2,000 clusters. Revisit before reaching 1,500.
- A released, revoked or removed activation is never shown as silent (`Not attached`).
- `GET /account/clusters` (session): per cluster `{name, id_short, license, version, nodes, last_ping, checkins, state, recovered_at?, quiet_seconds?}` with `state` one of `waiting`, `ok`, `stopped`, `silent`, `off`, `detached`; plus `stopped_at` when stopped.

### 1.6 In-app copy for each state (replaces any message to users)

| State | Pill | Last seen | Detail line |
|---|---|---|---|
| Healthy | `Checking in` | `4 minutes ago` | |
| Waiting | `Waiting` | `Not yet` | `Add the key in the installer, then wait up to 30 minutes.` |
| Stopped | `Stopped since 18:30 UTC` (neutral, no red) | `Yesterday 18:30` | `kwatch was stopped cleanly, for example by scaling it down. It cannot send alerts while stopped. It shows Checking in again when it starts.` |
| Silent | `Silent since 15:02 UTC` | `1 hour ago` | `kwatch stopped talking. Your apps may be fine, but kwatch cannot alert you while it is silent. Run kubectl -n kwatch get pods.` |
| Back (24h) | `Back at 15:25 UTC` | `Just now` | `Silent for 1 hour 23 minutes. Anything that broke in that time may not have been reported.` |
| Check-ins off | `Check-ins off` | `Not tracked` | `Turn them on in the installer: License / Pro > Cluster check-ins.` |
| Released or revoked | `Not attached` | | |

`Stopped since` is the time of the stopping check-in. `Silent since` is the last ping time plus 60 minutes. Stopped is never red and never counts as a problem. If it stays stopped for more than 7 days the detail line adds ` If this is not planned, check the cluster.` Pills pair a word with colour: silent uses failing #E5484D, back uses resolved #2F80ED, the rest neutral. `kwatch` is the installer's default namespace; if the ping later carries the namespace, use it.

### 1.7 App screen (new page `/clusters`, nav item "Clusters")

Table on desktop, stacked cards under 640px. Columns: Cluster (name, short id in mono below), License, Last seen, Status, Version, Nodes. Last seen is shown relative with the UTC time in the title attribute and in the pill text for silent and back. The page refreshes when focused and has a `Refresh` text button; no polling.

Under the table, one quiet panel:

- Heading `How this works`; body `kwatch checks in every 30 minutes. After 60 minutes without a check-in we mark the cluster silent here. We do not send messages. Want one? kwatch can ping a monitor you own.` (link to the docs page for `heartbeatMonitor`).
- Empty state (no cluster attached): `No clusters yet. Add a key in the installer (License / Pro > Add or replace key) and it appears here within 30 minutes.`
- Loading: skeleton rows with `aria-busy`. Error: `Could not load your clusters. Reload the page; if it keeps failing, use Get help.`

Dark mode: dark status colours with the same words; focus ring Ink in light, #F2F3F0 in dark.

### 1.8 Acceptance checks

1. A pod pinging every 30 minutes is never shown silent; stopping it shows `silent` at 60 minutes plus, with the correct "Silent since" time, computed with no cron running.
2. A restart that pings again within 60 minutes is never silent.
3. A ping after a gap over 60 minutes sets `Back at` and the quiet duration, shown for 24 hours.
4. Turning off in the installer sends the final ping; the cluster shows `Check-ins off` and never `silent`.
5. Revoked license or released cluster shows `Not attached`.
6. A second ping within 25 minutes causes no D1 write.
7. No code path in this feature sends email, calls a webhook, or reads or stores a notification URL; the Worker config has no new cron.
8. `GET /account/clusters` returns only the account's own clusters.
9. The installer and `/pro` list exactly what is sent: hashed cluster id, version, node count, optional cluster name. Core confirms against the payload.
10. The existing `heartbeatMonitor` tests pass untouched.
11. A graceful stop (SIGTERM) sends one `stopping` check-in within 2 seconds and never delays shutdown by more than that; the app then shows `Stopped since {time}` with the neutral pill and the exact text, never `Silent`, even after hours.
12. The next normal check-in after a stop shows `Checking in` and records no `Back at` or quiet duration.
13. `kill -9`, OOM kill, node loss or blocked egress send no `stopping` check-in and show `Silent` after 60 minutes.
14. Rolling update: a new pod checks in, then the old pod sends `stopping` with the old `boot_id`; the cluster stays `Checking in` (the stopping check-in is ignored).
15. A cluster stopped for over 7 days shows the extra sentence.
16. Every state in 1.6 renders with its exact text, at 320px and in dark mode, and passes axe with no serious issues.

---

## 2. Test alert

### 2.1 Command

`kwatch test-alert [--provider <name>]`. Runs inside the pod, through the real delivery path with the live configuration, so a pass proves the same channel that real alerts use. Available in Community and Pro. Not stored as an incident, not counted in budgets or outbox, no root-cause run, no effect on deduplication.

`--provider` accepts a configured provider name; an unknown name lists the configured ones.

### 2.2 Message text

Title: `kwatch test alert`

Body:

```
This is a test from kwatch. Nothing is wrong.
If you can read this, alerts from {cluster} reach this channel.
Sent {YYYY-MM-DD HH:MM UTC} by {installer | kwatch test-alert}. Version {version}.
```

Severity: notify (existing orange dot, no red, so nobody gets paged). It carries no "what to do next" command because there is nothing to fix. For paging providers (PagerDuty, Opsgenie and similar) core uses the lowest non-paging severity and resolves it at once if the provider supports resolution (Q4: confirm each paging provider can do this; otherwise exclude from "all" and require `--provider` with a warning).

### 2.3 Output

Each provider gets one line: name, outcome, detail. "Sent" means the provider accepted it, not that a person read it; the footer says so.

All sent:

```
Sending a test alert to 2 providers.

  slack       sent    accepted in 0.4s
  email       sent    accepted in 1.2s

Both providers accepted the message. Check the channels to confirm it arrived.
```

One failed (exit 1):

```
  slack       sent    accepted in 0.4s
  discord     failed  the webhook returned 404 (not found)
                      Fix: the webhook was deleted or mistyped. Create a new
                      one in Discord, then Edit notification providers.

1 of 2 providers failed.
```

Failure details by class (exact `detail` and `Fix:` lines):

| Cause | Detail | Fix |
|---|---|---|
| HTTP 401/403 | `rejected the credentials (401)` | `Fix: the token or key is wrong or expired. Update it in Edit notification providers.` |
| HTTP 404 | `the webhook returned 404 (not found)` | `Fix: the webhook was deleted or mistyped. Create a new one, then Edit notification providers.` |
| HTTP 429 | `rate limited (429)` | `Fix: wait a minute and run the test again.` |
| HTTP 5xx | `the provider returned 503` | `Fix: this is on their side. Try again later.` |
| DNS/connect | `could not reach hooks.slack.com` | `Fix: the pod cannot reach the internet. Check egress rules (network policy) and DNS.` |
| TLS | `certificate not trusted` | `Fix: a proxy or custom certificate is in the way. See docs.kwatch.dev.` |
| SMTP auth | `the mail server refused the login (535)` | `Fix: check username and password under Edit notification providers.` |
| Timeout | `no answer after 10s` | `Fix: check egress rules; the provider may be slow.` |

Details never print URLs, tokens, usernames or addresses (apply `internal/redact`; host names of public SaaS endpoints are allowed, customer hosts are not).

No provider configured (exit 2):

```
No notification provider is set up, so there is nowhere to send a test.
Fix: run the installer and choose Edit notification providers.
```

Exit codes: 0 all sent, 1 at least one failed, 2 nothing to send to, 64 usage error (existing convention in `subcommands.go`; core to match).

Timeout per provider 10s; providers run in parallel; total at most 15s.

### 2.4 Installer

File `apps/web/public/kwatch.sh`, `show_supported_menu` (about lines 6694 to 6712). New item right after `Edit notification providers`, because the natural sequence is set up, then check:

```
📊 View status
📜 View recent logs
⬆️  Upgrade kwatch
🔌 Edit notification providers
🔔 Send test alert            <- new
⚙️  Edit settings
🧮 Edit Deployment resources and placement
🧩 View capabilities
🔑 License / Pro
♻️  Restore a previous configuration   (only with backups)
🧰 Save diagnostics to file   <- spec 3
🧹 Uninstall kwatch
🚪 Exit
```

Add the action `testalert` to `actions` and `labels`; it is read-only (`MENU_READ_ONLY=true`). Also offer it at the end of the provider editing flow: `Send a test alert now? [Y/n]`.

Flow: screen title `test alert`. Find the pod (reuse `select_workload_pod`). If more than one provider is configured, `ui_select`: `All providers` plus each name. Show busy `Sending the test alert`. Run `kubectl -n "$NAMESPACE" exec "$pod" -- kwatch test-alert [--provider X]`, pipe through `redact_stream`, print as is. Then `ui_pause`.

Installer-specific messages:

- No pod: `No kwatch Pod was found in namespace {ns}. Install or repair kwatch first.`
- Old image without the command (`unknown command`): `This kwatch version does not have test-alert yet. Choose Upgrade kwatch, then try again.`
- Pod not ready: `The kwatch Pod is not ready yet. Wait a minute, or choose View status.`

### 2.5 Acceptance checks

1. Command with one working provider exits 0 and prints one `sent` row.
2. A deleted Discord webhook exits 1 with the 404 text and the Fix line.
3. No providers exits 2 with the exact text above.
4. No test alert appears in `/status`, incidents, replay, or alert counters.
5. Output contains no URL, token, address or username (fuzz with known secrets).
6. Menu shows `Send test alert` directly after `Edit notification providers`; selecting it from an older image shows the upgrade text.
7. Works for Community (no key).
8. `--provider nope` lists configured names and exits 64.

---

## 3. Save diagnostics to file

### 3.1 Menu, flow and file

Installer item `🧰 Save diagnostics to file` (placement in 2.4), for everyone (Community and Pro). Nothing is uploaded: not to api.kwatch.dev, not anywhere. There is no "send" action in the installer, no Worker route, no storage. The file stays on the user's machine; the user attaches it to their reply to the support email.

The installer collects and redacts on the user's machine with their `kubectl`, shows what is included, asks to confirm, and writes one file.

File name: `kwatch-diagnostics-<cluster>-<YYYYMMDD>.tar.gz` (UTC date). `<cluster>` is `app.clusterName` if set, else the namespace; lower-case, only `a-z 0-9 -`, at most 30 characters, `cluster` if empty. Never the kubeconfig context or API server address (they can name companies or hosts). Written to the current directory, else `$HOME`. Never overwrites: if the name exists, `-2`, `-3`.

Size: logs default to the last 2000 lines. If the file would exceed 10 MB (a comfortable e-mail attachment), logs are cut in steps 1000, 500, 200 lines and the confirm screen says so.

### 3.2 Included

| File in archive | Source | Notes |
|---|---|---|
| `README.txt` | installer | What this is and what to do with it (3.4 text) |
| `manifest.json` | installer | Bundle format 1, creation time, installer and kwatch versions, edition, Kubernetes server version, node count, OS of the machine running the installer. No context name, no API server address |
| `status.txt` | `/status` via the Pod proxy (`status_text` path in the installer), or `kwatch license status` fallback | Redacted |
| `logs.txt` | last 2000 lines of the kwatch Pod | Redacted |
| `logs-previous.txt` | previous container, if the Pod restarted | Redacted |
| `events.txt` | `kubectl get events` in the kwatch namespace | Redacted |
| `pods.txt` | `kubectl describe pod` of the kwatch Pod | Redacted; env values removed |
| `config.yaml` | KwatchConfig or ConfigMap | Shaped by an allowlist, see 3.3 |
| `deployment.yaml` | the kwatch Deployment | No `managedFields`, no env values |

### 3.3 Excluded and redaction

Never collected: Secrets (the installer never reads them), the license key and its instance secret, other namespaces' objects and logs, workload specs, node names and addresses, kubeconfig and context names, files from the user's machine, shell history.

Redaction is an allowlist for config, a pattern pass for text:

- `config.yaml`: keep keys; keep booleans, numbers, and strings from a small enum list (log level, provider type names). Every other string becomes `<set>` or `<empty>`. Each provider shows its type and `configured: yes`, never a URL, token, channel, e-mail address or chat id. Namespace and label filters become `<set>` (they often name teams).
- Text files: `internal/redact` rules (credentials, bearer tokens, JWT, AWS keys, private keys, `user:pass@`), plus URLs, e-mail addresses and IPv4/IPv6 addresses replaced with `<url>`, `<email>`, `<ip>`. The installer's existing `redact_stream` is the floor, not the ceiling (Q5: core owns the single list so shell and Go cannot drift; the shell calls `kwatch redact` in the pod if available, otherwise a ported subset).
- Final scan before writing the archive: grep every file for `https?://`, `@`, long base64-looking runs, `token`/`secret`/`password`/`key` followed by a value. A hit aborts, deletes the work folder and says `A line that may hold a secret was left in {file}. Nothing was saved. Please tell us in Get help.` (never silently passing).

Pod names and namespace names stay in (needed to debug); the README says so.

### 3.4 Screens and copy

**Collecting** (screen title `diagnostics`): steps tick: `Status`, `Logs`, `Events`, `Configuration (secrets removed)`, `Checking nothing private is left`.

**Confirm screen** (always shown; nothing is written before it):

```
Save diagnostics to a file

  kwatch status                    2 KB
  Last 2000 log lines             312 KB
  Events from the kwatch namespace  6 KB
  Settings, secrets removed         3 KB
  kwatch and Kubernetes versions    1 KB
                                  ------
  Total                           324 KB

Removed: Secrets, your license key, webhook URLs, tokens, e-mail
addresses and IP addresses.
The file stays on this computer. kwatch does not upload it.

  > Save the file
    Review the files first
    Cancel
```

- `Review the files first` unpacks into a temporary folder, prints `Opened at {path}. Look through it, then come back here.`, and returns to this screen. The folder is deleted when the installer exits.
- `Cancel` removes the working files and returns to the menu.
- When logs were cut: extra line `Logs were cut to the last {n} lines to keep the file small.`

**Saved**:

```
Diagnostics saved

  ./kwatch-diagnostics-prod-20261019.tar.gz   (324 KB)

Attach this file when you reply to our support email.
No support email yet? Pro users: open app.kwatch.dev, choose Get help
and describe what happened. We reply by e-mail.
Community: open an issue at github.com/abahmed/kwatch/issues. Attach the
file only after you have read it; issues are public.
```

Remote shell hint, shown only when `SSH_CONNECTION` is set or no display is available (the file is on a machine the user may not be sitting at):

```
This file is on {hostname}. To copy it to your computer, run this on your
computer:
  scp {user}@{hostname}:{full path} .
```

Hostname and user come from the local shell. If the installer runs in a container or CI runner, the hint is `Copy it out of the container before it stops, for example with kubectl cp or docker cp.` (no command is guessed).

**Errors** (texts exact):

| Case | Text |
|---|---|
| kubectl or context missing | `kubectl is needed to collect the diagnostics and could not reach a cluster. Select a cluster first (View status shows which one).` |
| No kwatch Pod | `No kwatch Pod was found, so the diagnostics have no logs. Everything else was saved.` The file is still created; it states why in `manifest.json` |
| Part could not be read | `Could not read events (forbidden). The diagnostics were saved without them.` (also in `manifest.json` under `missing`) |
| Disk | `Could not write {path}. Free some space or run the installer from a folder you can write to.` |
| Redaction scan hit | `A line that may hold a secret was left in {file}. Nothing was saved. Please tell us in Get help.` |

### 3.5 Acceptance checks

1. Menu item is `Save diagnostics to file`, sits before Uninstall, and is read-only (`MENU_READ_ONLY=true`). There is no "send" item or flow.
2. The confirm screen appears every time; nothing is written before `Save the file`; `Cancel` leaves no files behind.
3. A cluster seeded with a fake webhook, token, license key, e-mail and IP yields a file where `grep -rE` finds none of them in status, logs, events, config and describe output.
4. `config.yaml` has no string value outside the allowlist or `<set>`/`<empty>`.
5. The final scan aborts when a planted `token: abc123` is injected after redaction.
6. No Secret is fetched in this path (audit the script for `get secret`).
7. The path makes no network request except `kubectl`; no code or Worker route accepts a bundle.
8. File name matches `kwatch-diagnostics-[a-z0-9-]{1,30}-\d{8}(-\d+)?\.tar\.gz`; it never contains the context name or API address; a second run on the same day does not overwrite.
9. Without a kwatch Pod the file is still created and the message above is shown.
10. A bundle over 10 MB is cut to fewer log lines and the confirm screen says so.
11. Over SSH the scp hint is shown with the real host and full path; locally it is not.
12. Works the same on a Community cluster (no key).

---

## 4. Web support

### 4.1 Public page: kwatch.dev/support

Astro page `apps/web/src/pages/support.astro`; link in the site footer and on `/pro`. No form, no chat. Three equal-weight routes in an uneven grid (wide column left, two narrow right), one Ink button each.

Heading: `Get help`
Lead: `Most questions are answered in the docs. If yours is not, here is where to go.`

1. `Read the docs` (wide). `Install steps, what each alert means, and how to fix the usual causes.` Button `Open the docs` to docs.kwatch.dev. Secondary link `New to Kubernetes? Start with the glossary` to /glossary.
2. `Community: open an issue`. `Community is free and supported in public on GitHub.` Button `Open an issue` to github.com/abahmed/kwatch/issues/new. Note `Issues are public. Remove anything private first.`
3. `Pro: get help in the app`. `Signed-in Pro users send a request from app.kwatch.dev and see replies there.` Button `Open Get help` to app.kwatch.dev/help. Note `Pro is free during early access.`

Before you write, a block `Help us help you`: three steps in mono-numbered list: `1 Run the installer and choose Save diagnostics to file.` `2 Read the list on screen. Secrets are removed and nothing is uploaded.` `3 Attach the file when you reply to our support email.` Link `What is in a bundle` to docs.

Honest line, no promises: `We read every request. We cannot promise a reply time during early access.`

States: static; dark and light via tokens; one column under 640px; mono for the command. SEO title `Get help with kwatch`; `noindex` is not needed.

### 4.2 App: "Get help" (route `/help`, nav item "Get help")

Requires sign-in (existing session). The form is for users with an active Pro license. Others (no license, or only an expired one, which counts as Community) see: `Get help is for Pro. Community support is on GitHub.` with the button `Open an issue`.

### 4.3 The form

Single column, labels above, no uploads, no live chat.

- `Your email` read-only, prefilled from the session; hint `We reply to this address.`
- `License` select, defaulting to the one with a cluster attached; options show the id used on the Licenses page.
- `Cluster` select of attached clusters (name, version, last seen) plus `Not sure or not installed yet`.
- `What do you need help with?` select: `Installing kwatch`, `Alerts not arriving`, `An alert I do not understand`, `Cluster check-ins`, `My license`, `Something else`.
- `Tell us what happened` textarea, 20 to 4000 characters, counter `1200 / 4000`. Placeholder `What you expected, what you saw, and what you tried.`
- Hint: `No file goes in this form. After we reply by e-mail, attach your diagnostics file to that reply. Installer: Save diagnostics to file.`
- Button `Send request` (Ink); disabled while invalid or sending.

Server adds, not editable, shown in a read-only summary row under the form (`Sent with your request: license, plan and expiry, cluster names, versions and last seen`): license id, plan, expiry, each cluster's name, version, node count, last seen and check-in state, edition.

Validation: `Please write at least 20 characters so we can help.`; `That is over the 4000 character limit.`
Rate limit (429): `You have sent 3 requests today. Please wait for our reply, or try again tomorrow. For something urgent, open an issue on GitHub.`
Server error: `We could not send your request. Nothing was sent. Try again, and if it keeps failing, open an issue on GitHub.`

### 4.4 Success screen (replaces the form, no e-mail to the user)

Heading `Request sent`
Body: `We will reply by e-mail to {email}. Replies come from our support address, so check your spam folder if you do not see one.`
Reference: `Reference KW-4F7A2C` (mono, selectable, Copy button; 6 characters from a confusion-free alphabet).
Line `When we do, reply with your diagnostics file attached.` Block `Make the diagnostics file now`: `1 Run the installer: /bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"` `2 Choose Save diagnostics to file.` `3 Keep the file ready. Secrets are removed and nothing is uploaded.` Buttons: `Back to clusters` (secondary). We do not promise a reply time.

The page keeps the reference only in memory; refreshing returns to the empty form (no thread storage).

### 4.5 API and email (kwatch-api)

- `POST /support` (session, CSRF like other account routes): JSON `{license, cluster_uuid?, topic, message}` (body at most 8 KB) → `202 {ref}`. The route accepts no file or other content type (`415`). The Worker verifies the license belongs to the account and is active Pro; the cluster must belong to that license.
- Sends **one** Resend email: `to` the support inbox (Worker var `SUPPORT_INBOX` = `support@kwatch.dev`), `reply_to` the user's account e-mail, `from` the existing `kwatch <noreply@mail.kwatch.dev>`. Subject `[Support] {topic} - {ref} - {email}`; no attachment. Body: message, then a plain list of the attached facts (license id, plan, expiry, clusters with version, nodes, last seen, check-in state). Plain text, no tracking. Footer line for the person answering: `Ask them to attach their kwatch diagnostics file to the reply.`
- Quota protection: per-account limit of 3 requests per UTC day (`rate_counters` key `support:{accountId}`), plus a global daily support budget of 10 sends carved out of the existing 95 (Q1: for example auth 55, tx 30, support 10). If the global budget is exhausted: `Support is busy right now. Please try again tomorrow or open an issue on GitHub.` (503); the counter is refunded. A failed Resend call refunds both counters and shows the server error copy.
- No message body is stored in D1; store only `ref`, account id, time (for the rate limit and so the owner can search the inbox by reference). Privacy page says: `Requests are sent to our support inbox. We do not keep a copy in the app.` (kwatch-web updates `privacy.md`.)
- No confirmation email, no other new email anywhere.

### 4.6 Accessibility and responsive notes

Real `<label>`s, errors in `aria-live="polite"` beside the field plus a summary at the top on submit with focus moved to it. On success, focus moves to the `Request sent` heading. Counter announces at 90 percent. Reference is selectable mono text with a Copy button. 44px targets, visible focus ring. One column under 640px; 16px textarea font so iOS does not zoom. Same tokens in dark mode; status is never colour alone.

### 4.7 Acceptance checks

1. `/support` has the three routes with the exact headings and links; passes axe with no serious issues; no form.
2. Signed-out `/help` redirects to sign-in and returns afterward.
3. A user with only an expired license sees the GitHub message, not the form.
4. A 19-character message shows the validation text and sends nothing.
5. A valid submit makes exactly one Resend call: `to` is the support inbox, `reply_to` is the user, subject contains the reference; no second call to the user.
6. The body contains the license and clusters of that account only; a license or cluster id from another account returns `403` and sends nothing.
7. The fourth request in a UTC day returns `429` with the text above and no Resend call.
8. Global support budget exhausted: `503` with the busy text, counters refunded.
9. A Resend failure refunds counters and shows the server error text.
10. The success screen shows the reference, the address, and the three bundle steps; refresh returns to the empty form.
11. Existing sign-in, expiry and other emails behave as before (tests unchanged).
12. The route rejects `multipart/*` and any non-JSON body with `415`; the mail has no attachment and the form has no file input.
13. The request makes no other network call than the single Resend send.
14. A message containing `<script>` is sent as plain text and never rendered.

---

## Open questions

1. **Resend budget split:** support gets 10 of the 95 daily sends and 3 per account per day. Taken from which budget (auth 60, tx 35)?
2. **Check-ins free-tier ceiling:** 30-minute pings cap about 2,000 clusters on Workers and D1 free limits. Fine for early access; who revisits it and at what number?
3. **Namespace in messages:** the next step in the app uses `kwatch`. Should the ping carry the installed namespace so the command is exact?
4. **Test alert and paging providers:** can each resolve a test event? Otherwise exclude them from "all providers".
5. **Redaction source of truth:** one Go list in `internal/redact` called through the pod (`kwatch redact`), or a shell subset?
6. **Support inbox replies:** `support@kwatch.dev` must accept mail from users (Reply-To replies go there and back); confirm the mailbox exists and who reads it.
