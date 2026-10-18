# Pro readiness before v1.0.0-rc.21: four features

Status: draft for the lead. Specs only, no production code.
Audience: paying Pro users who are new to Kubernetes. Copy follows `MESSAGING.md`: Pro is free during early access (no prices, no "trial"), install is installer-first, licenses live only in the installer's License / Pro menu, "source available". Free tiers only (Cloudflare Workers and D1, Resend; no new paid service).

**Decisions (user, final):** Resend quota is limited, so (1) silence alerts send no email: the Worker posts to a webhook the user registers, and the app shows cluster status; (2) support sends exactly one text-only email per request, to the support inbox with Reply-To set to the user, and no confirmation email; (3) no file is ever uploaded to our API: diagnostics are saved to a file on the user's machine and attached by the user to their own email reply. Existing sign-in and license emails are unchanged.

Owners: kwatch-core (Go, `kwatch test-alert`, managed ping), kwatch-web (`kwatch.sh`, `/support`), kwatch-api (Worker, D1), kwatch-app (app.kwatch.dev).

## Shared rules

- Words: say the cause, then the fix. No "oops", no "something went wrong". No emoji on kwatch.dev or app.kwatch.dev. The installer (`kwatch.sh`) keeps its existing emoji menu style.
- Signal (#C8F542, #B5DE3C dark) is never text on white and appears at most once per view. All new buttons here are Ink (primary) or outline (secondary). Status colours appear only inside alert-like blocks: failing #E5484D, degraded #F5A524, resolved #2F80ED.
- Cluster output (commands, `/status`, filenames, ids) is Geist Mono. Headings Bricolage Grotesque 800. Text Instrument Sans.
- Light and dark follow the system. Every text/background pair is at least 4.5:1, borders and focus rings at least 3:1. Hit targets 44px. Layout works from 320px; one column under 640px.
- New to Kubernetes: first use of a term per page is explained with the glossary line from `MESSAGING.md` section 4.
- Never promise a response time, delivery guarantee or uptime. "Sent" means "the channel accepted it".

---

## 1. Managed heartbeat: "tell me when my cluster goes quiet"

### 1.1 What it is, and what it cannot say

kwatch Pro pings `api.kwatch.dev` every 5 minutes. A Worker cron notices when pings stop. The page and message must be honest about what silence means: **kwatch stopped talking.** The cluster may be fine. Three usual causes: the kwatch pod stopped, the cluster or node is down, or the cluster lost outbound access to `api.kwatch.dev`.

Name in all UI: **Silence alerts**. Never "uptime monitoring", never "we monitor your cluster".

### 1.2 Relation to the existing heartbeat monitor

`kwatch/internal/heartbeat` (config `heartbeatMonitor`) GETs a URL the user owns (Healthchecks.io and similar) on a schedule, only while monitoring is ready. It stays unchanged and is the "bring your own" option.

| | Your URL (existing) | Silence alerts (new) |
|---|---|---|
| Who watches | A service you choose | kwatch Worker |
| Needs | Account elsewhere | Pro license, app.kwatch.dev sign-in |
| Where you hear | Whatever that service sends | The app, plus a webhook you register  |
| Config | `heartbeatMonitor.url` | License / Pro menu toggle |

They can run together; neither disables the other. In docs and the app, present them as two ways to answer the same question, with the cost of each: yours is more setup and fully yours; ours is one switch.

Reuse the same readiness rule: no ping is sent while kwatch is not ready, so a pod that is up but not monitoring counts as quiet. Keep the ping separate from the daily `/license/renew` (24h lease, unchanged).

### 1.3 Default, toggle, threshold

- **Default: on** for an active Pro license, announced once at the moment of adding or moving a key in the installer ("Silence alerts are on. Turn them off in License / Pro."). Rationale: a switch nobody finds protects nobody; the ping adds no data beyond the renew payload (cluster id hash, kwatch version, node count) and says so on `/pro`. Open question Q1 if the lead prefers opt-in.
- **Where to toggle:** installer, License / Pro submenu, because the ping is sent by the pod and the installer owns config. The app shows the state read-only (`On`, `Off`, `Not yet seen`) with a hint "Change it in the installer: License / Pro > Silence alerts".
- **Where to set the threshold:** the app, because it is server-side. Choices: 10 (default), 15, 30, 60 minutes. Ping is every 5 min, so 10 minutes means two missed pings; one slow ping never alerts. No free-form numbers.
- Turning off sends one final `{"silence_alerts": false}` ping so the Worker stops watching instead of reporting a false silence. If the final ping fails, the app shows the cluster as silent until the user removes the cluster or key; the installer says so.

### 1.4 Installer: License / Pro submenu

Current items: Show license status, Add or replace key, Move license to this cluster, Remove key, Back. Insert after Show license status:

```
 Silence alerts: on   (change)
```

Selecting it opens:

```
Silence alerts

  kwatch checks in with api.kwatch.dev every 5 minutes. If it goes quiet
  for 10 minutes or more, app.kwatch.dev shows this cluster as silent.
  Sent: a hashed cluster ID, the kwatch version and the node count.

  > Turn off
    Back
```

When off the first row reads `Turn on`. Success line: `Silence alerts are on. The first check-in follows within 5 minutes.` / `Silence alerts are off.` Failure (config write or rollout failed): `Could not change Silence alerts: <reason>. Nothing was changed. Run the installer again after fixing it.` Show the item only with an active key; otherwise it is absent (not greyed).

### 1.5 Worker behaviour (contract for kwatch-api)

- New route `POST /license/ping`, same instance authentication as `/license/renew` (signed by the instance key; unversioned path). Body at most 256 bytes: `{kwatch_version, node_count, cluster_name?, silence_alerts}`. `cluster_name` comes from `app.clusterName` if set. Response `204`. Ignore more than one ping per 4 minutes per license (still `204`).
- D1 (LICENSE_DB, migration `0006`): per activation `last_ping`, `alert_threshold_min` (default 10), `silence_alerts` (0/1), `alert_state` (`ok` | `silent`), `silent_since`.
- Cron `*/5 * * * *` added next to the daily one. One indexed query: activations with `silence_alerts=1`, `alert_state='ok'`, `last_ping < now - threshold`. Mark `silent`, set `silent_since`, fire notifications. On a ping from a `silent` cluster: mark `ok`, fire the recovery.
- Free-tier budget (important): one cluster costs 288 pings, so 288 Worker requests and about 288 D1 writes a day. Free tier is 100k of each per day, so the ceiling is about 340 clusters. Mitigation if needed: ping every 10 minutes (about 690 clusters) with the default threshold at 20. Q2.
- A cluster whose activation is released, whose license is revoked, or whose key was removed is never reported silent.
- Flapping guard: at most one `silent` notification per cluster per 24 hours; the app still shows every transition. Recovery notifications are sent only for a silence that was notified.

### 1.6 How you hear about it (no email)

Decided: **in-app cluster status plus a webhook** the user registers once per license in the app. The Worker `POST`s a JSON message when a cluster turns silent and when it recovers.

- Kinds: Slack, Microsoft Teams, Discord, Generic (JSON). The app picks the payload shape by kind; the user pastes only a URL.
- Security: https only; reject `localhost`, IP literals and private ranges; 5-second timeout, no redirects, one retry after 60 seconds, then give up and record `delivery: failed` on the event. The URL is a credential: stored server-side (encrypted with an existing Worker secret), shown masked after saving (`https://hooks.slack.com/...`, last 4 characters only), never returned by the API in full, replaced rather than edited.
- "Send test" posts `kwatch test: this is how a silence alert will look. Nothing is wrong.`
- Cost: one outbound `fetch` per event. Free-plan Workers allow 50 subrequests per invocation, so cap at 40 notifications per cron run and carry the rest to the next run.

**Alternative the app and docs mention:** kwatch's existing heartbeat monitor can ping a URL the user owns (Healthchecks.io and similar) instead. No new Worker cost, but a third service to set up. The app panel links to it. A user with no webhook still sees every silent cluster in the app.

### 1.7 Webhook message copy (all kinds, plain text body; markdown where the platform renders it)

Silent:

```
kwatch has gone quiet in {cluster}
Last heard from at {HH:MM UTC} ({N} minutes ago).
Likely cause: the kwatch pod stopped, the cluster is down, or it cannot reach api.kwatch.dev. Your apps may be fine; while kwatch is quiet it cannot alert you.
Next step: kubectl -n kwatch get pods
https://app.kwatch.dev/clusters
```

Recovered:

```
kwatch is back in {cluster}
It was quiet for {duration}, from {HH:MM UTC} to {HH:MM UTC}. Alerts are flowing again.
Anything that broke while kwatch was quiet may not have been reported. Check: kubectl -n kwatch logs deploy/kwatch --tail=50
```

`{cluster}` is `cluster_name`, else the first 8 characters of the hashed cluster id. Namespace `kwatch` is the installer default; if `activations` ever stores a different namespace, use it (Q3).

Status colour: silent uses failing #E5484D, recovered uses resolved #2F80ED, only where the platform supports colour bars (Slack attachment, Discord embed, Teams card accent).

### 1.8 App screens (app.kwatch.dev, new page `/clusters`, nav item "Clusters")

Table on desktop, stacked cards under 640px. Columns: Cluster (name, mono id below), License, Last seen, Status, Version, Nodes.

Status values and exact copy:

| State | Pill | Last seen cell | Detail line |
|---|---|---|---|
| Healthy | `Checking in` (neutral Ink outline) | `2 minutes ago` | |
| Not yet seen | `Waiting` (neutral) | `Not yet` | `Add the key in the installer, then wait up to 5 minutes.` |
| Silent | `Quiet since 14:02 UTC` (failing red, text plus shape, never colour alone) | `18 minutes ago` | `kwatch stopped talking. Run kubectl -n kwatch get pods.` |
| Recovered (shown 24h) | `Back at 14:41 UTC` (resolved blue) | `Just now` | `Quiet for 39 minutes.` |
| Alerts off | `Silence alerts off` (neutral) | `Not tracked` | `Turn them on in the installer: License / Pro > Silence alerts.` |
| Released / revoked | `Not attached` (neutral) | | |

Below the table, one panel "Silence alerts":

- Heading `Silence alerts`; body `If kwatch goes quiet for this long, we mark the cluster as silent and notify your webhook.`
- Field `Quiet for` (select 10 / 15 / 30 / 60 minutes), `Save` (Ink). Saved note: `Saved. Applies from the next check.`
-  Field `Webhook` with kind select, URL input, `Save`, `Send test`, `Remove`. Empty state: `No webhook yet. Silent clusters still show here. Add a webhook to hear about it in Slack, Teams or Discord.` Error: `That URL did not accept the test message (it returned 404). Check the URL and try again.`
- Link `Prefer your own monitor? kwatch can ping a URL you own.` to the docs page for `heartbeatMonitor`.
- Loading: skeleton rows with `aria-busy`. Error: `Could not load your clusters. Reload the page; if it keeps failing, use Get help.`

Dark mode: pills invert to the dark status colours with the same text; focus ring Ink in light, #F2F3F0 in dark. Time is shown in the viewer's zone with UTC in the title attribute and visible text on the status pill.

### 1.9 Acceptance checks

1. With silence alerts on, a pod that pings every 5 minutes is never marked silent; stopping it marks it `silent` between 10 and 15 minutes later (threshold 10).
2. A restart that pings again within 10 minutes produces no event.
3. Recovery produces exactly one `recovered` event and only if a `silent` event was sent.
4. Turning off in the installer sends the final ping; the cluster is then `Silence alerts off` and never alerts.
5. Revoked license or released cluster never alerts.
6.  Webhook URL: `http://`, `https://localhost`, `https://10.0.0.1` and redirecting URLs are rejected with the copy above; full URL is never in any API response.
7.  A failing webhook retries once after 60 seconds, then records `failed`; the cron run still completes.
8. More than 40 pending notifications in a run: 40 are sent, the rest next run.
9. No code path in this feature calls Resend.
10. `/pro` and the installer text list exactly what is sent: hashed cluster id, version, node count, optional cluster name. Core confirms against the payload.
11. The existing `heartbeatMonitor` tests still pass untouched.

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
- `What do you need help with?` select: `Installing kwatch`, `Alerts not arriving`, `An alert I do not understand`, `Silence alerts`, `My license`, `Something else`.
- `Tell us what happened` textarea, 20 to 4000 characters, counter `1200 / 4000`. Placeholder `What you expected, what you saw, and what you tried.`
- Hint: `No file goes in this form. After we reply by e-mail, attach your diagnostics file to that reply. Installer: Save diagnostics to file.`
- Button `Send request` (Ink); disabled while invalid or sending.

Server adds, not editable, shown in a read-only summary row under the form (`Sent with your request: license, plan and expiry, cluster names, versions and last seen`): license id, plan, expiry, each cluster's name, version, node count, last seen and silence state, edition.

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
- Sends **one** Resend email: `to` the support inbox (Worker var `SUPPORT_INBOX`, Q1), `reply_to` the user's account e-mail, `from` the existing `kwatch <noreply@mail.kwatch.dev>`. Subject `[Support] {topic} - {ref} - {email}`; no attachment. Body: message, then a plain list of the attached facts (license id, plan, expiry, clusters with version, nodes, last seen, silence state). Plain text, no tracking. Footer line for the person answering: `Ask them to attach their kwatch diagnostics file to the reply.`
- Quota protection: per-account limit of 3 requests per UTC day (`rate_counters` key `support:{accountId}`), plus a global daily support budget of 10 sends carved out of the existing 95 (Q2: for example auth 55, tx 30, support 10). If the global budget is exhausted: `Support is busy right now. Please try again tomorrow or open an issue on GitHub.` (503); the counter is refunded. A failed Resend call refunds both counters and shows the server error copy.
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

1. **Support inbox address:** which address is `SUPPORT_INBOX` and does it accept replies from users?
2. **Resend budget split:** support gets 10 of the 95 daily sends and 3 per account per day. Taken from which budget (auth 60, tx 35)?
3. **Silence alerts default:** on (recommended, announced in the installer) or opt-in?
4. **Free-tier ceiling:** 5-minute pings cap about 340 clusters on Workers and D1 free limits. Accept, or ping every 10 minutes with a 20-minute default?
5. **Namespace in messages:** the Next step uses `kwatch`. Should the ping carry the installed namespace so the command is exact?
6. **Webhook storage:** is a user webhook URL (a credential) in D1, encrypted with an existing Worker secret, acceptable?
7. **Test alert and paging providers:** can each resolve a test event? Otherwise exclude them from "all providers".
8. **Redaction source of truth:** one Go list in `internal/redact` called through the pod (`kwatch redact`), or a shell subset?
