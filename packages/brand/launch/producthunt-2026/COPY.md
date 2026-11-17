# kwatch: Product Hunt relaunch copy

**Name:** kwatch

**Tagline** (46 chars):
Kubernetes alerts that name the one root cause

**Description** (223 chars):
kwatch finds the one cause behind a Kubernetes failure and sends one message: what broke, why, who changed it, what to do next. To Slack, Teams, email and 50+ channels. Source available (ELv2); Pro free during early access.

**Topics:** DevOps, Developer Tools, Monitoring (confirm these exist on the PH topic picker; "Open Source" is not used)

**Pricing label:** Free (Pro is free during early access)

**Links:** https://kwatch.dev , https://docs.kwatch.dev/install

## Maker's first comment

Hi, I'm Abdelrahman, the maker of kwatch. We launched here five years ago as a way to hear about crashing pods. It did that, and every alert was true, but when a release broke something you still got fifty of them and had to work out why yourself.

So in v1.2.0 I rebuilt kwatch around the cause. It runs as one small pod in your cluster and keeps a live map of what depends on what. When something fails, it follows the failure upstream and sends one message: what broke, why, who changed it, and what to do next, ending with the command to run. When it is fixed you hear once, then it stays quiet.

Your events and logs are analyzed where they live. Alerts go to the channels you set up: Slack, Teams, Discord, PagerDuty, email and 50+ more.

To try it, run one command and it walks you through the rest:

`bash <(curl -fsSL https://kwatch.dev/kwatch.sh)`

kwatch is source available (ELv2). Community is free, and Pro is free during early access.

I would love to hear what your last 03:00 incident looked like, and whether the message would have helped.

## What changed since our 2021 launch

- One message per incident, not one alert per symptom.
- Every message names the cause, the change behind it, and the command to run.
- Install is one command that walks you through it.
- A read-only dashboard for active and resolved issues.
- Source available (ELv2), with Community free and Pro free during early access.

## Gallery (1270x760) and thumbnail (240x240)

1. gallery-1-hero.png: Fifty alerts. One cause.
2. gallery-2-anatomy.png: one message, four answers
3. gallery-3-channels.png: 50+ channels
4. gallery-4-install.png: one command install
5. gallery-5-dashboard.png: optional dashboard
Thumbnail: thumbnail-240.png. Sources in src/ (render with Chrome headless).

## Verification notes

- Alert text in image 2 is real kwatch output (README release-regression sample). Image 1 card is the README illustrative incident, with the CI tool name removed. Dashboard rows are illustrative, matching docs/dashboard.md fields.
- "Who changed it", next-step command and dashboard are Pro features (free during early access); Community names the failure and cause type. Images and copy do not say otherwise but the lead may want a Pro tag.
- Pro tags: images 1, 2 and 5 carry a small "Pro" tag on who-changed-it, next-step command and dashboard. Community items (failure, cause type, channels, install) are untagged.
