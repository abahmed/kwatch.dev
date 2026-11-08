# Launch post outlines

Outlines only. Voice and titles follow `MESSAGING.md` section 9. Each ends with
the standard CTA. Check every claim with kwatch-core before writing.

## 1. Pro is free during early access

- Slug: `pro-free-during-early-access`. Tags: Pro, Releases. About 4 min.
- Description: Every Pro license is free during early access. See what Pro
  adds and get a key from the installer.
- Outline:
  1. What Community gives today: names what broke, the cause and the next
     command, free forever, no account, no key.
  2. What Pro adds: the full chain of cause, who made the change, what else is
     hit, the logs that prove it, dedicated support (copy from `specs/pro-page.md`).
  3. Get it: sign in at app.kwatch.dev for a key, then installer, License /
     Pro, Add or replace key. Each license is free for 3 months and may be
     renewed; one license runs one cluster.
  4. Your data: Pro license check once a day sends license ID, hashed cluster
     ID, kwatch version, node count; nothing else (table in `MESSAGING.md` 2).
  5. If a license ends, kwatch falls back to Community and alerts keep coming.
- No prices, no "trial", no future plans.

## 2. Root-causing CrashLoopBackOff: read the last crash first

- Slug: `root-causing-crashloopbackoff`. Tags: CrashLoopBackOff, Root cause.
  About 7 min.
- Description: A restarting pod hides its cause behind the next restart. Read
  the previous container's logs and follow the link upstream to the change.
- Outline:
  1. What CrashLoopBackOff is (glossary definition) and why the cause is hard
     to see: each restart replaces the evidence.
  2. Read the last crash: `kubectl logs <pod> -n <ns> --previous`, exit code
     and the last lines.
  3. Read the pod's events and exit code with `kubectl describe pod`.
  4. Follow the link upstream: config, secret, image or rollout changed just
     before the first crash (the trace example from the README).
  5. What kwatch sends: one message with the cause and the command, closed
     once when resolved (real output).
  6. Fix and confirm.
- Callouts: `--previous`; difference between a bad start command and a
  missing config.

## 3. OOMKilled explained: what stopped the pod and how to fix it

- Slug: `oomkilled-explained`. Tags: OOMKilled, Root cause. About 6 min.
- Description: A pod that used more memory than allowed is stopped. Read the
  limit, the usage and the exit code, then set a limit that fits.
- Outline:
  1. What OOMKilled means (glossary) and the signs: last state reason
     `OOMKilled`, exit code 137.
  2. Read the limit and the last state: `kubectl describe pod`, then
     `kubectl top pod` for current use.
  3. Container limit vs node memory: which one stopped the pod.
  4. Fix: raise the limit to fit observed use, or fix the allocation the logs
     point to; confirm the restart count stops rising.
  5. What kwatch sends for an OOM kill (real output) and the command it ends with.
- Callouts: requests vs limits in one sentence each.
