---
layout: ../layouts/Legal.astro
page: privacy
title: Privacy policy
description: What data kwatch collects for accounts and Pro licenses, how telemetry works, how long data is kept and how to delete it.
updated: Oct 16, 2026
lead: kwatch runs in your cluster. The free Community edition needs no account and never contacts us about licensing.
---

This policy covers the kwatch website (`kwatch.dev`), the account portal and
the license service at `api.kwatch.dev`. kwatch is operated by Abdelrahman
Ahmed ("we"). Contact: [hello@kwatch.dev](mailto:hello@kwatch.dev).

kwatch runs in your own cluster. The free Community edition needs no account,
and without a license key it never contacts the license service. The one
exception is the anonymous telemetry ping described below.

## What we collect

| Data | When | Why |
| --- | --- | --- |
| Email address | You sign up or sign in | To create your account, send sign-in links and send license notices (for example, a license about to expire) |
| Session cookie (`kw_session`) | You sign in | To keep you signed in. It is strictly necessary; we store only a hash of it |
| License usage: license ID, hashed cluster ID, cluster proof hash, instance public key, kwatch version, node count, last renewal time | A licensed kwatch activates or renews | To bind one license to one cluster, prevent key sharing and show the cluster on your account page |
| License event log: activations, moves, renewals that failed, emails sent | License changes | To enforce transfer and free-license limits and investigate abuse |
| Free-license records: a one-way hash of your email and, for work email domains, the domain name (for example `acme.com`) | You get a free Pro license | To limit free Pro licenses to 2 clusters per account or per company domain |
| IP address | Any request to `api.kwatch.dev` | Rate limiting and abuse prevention. Stored in two places, see below |

We never receive workload names, logs, secrets, alerts or any other content
from your cluster. The cluster ID is a one-way hash of the `kube-system`
namespace UID, and the raw UID never leaves your cluster.

### IP addresses we store

- **License activations:** we keep the last IP address that activated, moved
  or renewed a license. Each new action overwrites it. It is deleted when the
  activation is deactivated, transferred or regenerated, or when you delete
  your account.
- **Account sessions:** we keep the IP address you signed in from. It is
  deleted when you sign out or the session expires, after 30 days at most.

We use these only for manual abuse investigation. They are never shown to
anyone, including you, and never shared.

The website does not use analytics or advertising cookies.

## Telemetry

Telemetry is on by default. kwatch sends an anonymous adoption ping, at most
once every 7 days, containing a random installation ID (a UUID) and the kwatch version, so we
can see which versions are in use. It is separate from licensing, works in the
Community edition too, and contains no personal data. Turn it off with
`telemetry.enabled: false` or `KWATCH_TELEMETRY=false`.

## Cluster check-ins (Pro only)

With an active Pro license, kwatch pings `api.kwatch.dev` every 30 minutes so
app.kwatch.dev can show when a cluster last checked in and mark it silent after
60 minutes. The ping sends the hashed cluster ID, the license ID, the kwatch version and the node
count. It never includes a cluster name, namespace, pod name, log or event. Nothing is sent to you. The Community edition
sends none. Turn it off in the installer: License / Pro, then Cluster check-ins.

## How long we keep data

| Data | Kept |
| --- | --- |
| Account, licenses and activation records | Until you delete your account |
| Sign-in links | 15 minutes, single use |
| Sessions | 30 days, or until you sign out |
| Rate-limit counters | A few hours to a day |
| License event log | 180 days, keyed by license ID only |
| Telemetry ping (installation ID, kwatch version, last seen; no IP address) | One row per installation, overwritten on each ping. There is no automatic deletion yet, so it is kept until removed on request |
| Free-license records (email hash, company domain) | Kept after account deletion so deleting an account cannot reset the free-license limit |

## How we use data and legal bases

We use data only to provide the account and license service, send the emails
described above, prevent fraud and abuse, and keep the service secure. For
people in the EU, UK and similar jurisdictions, our legal bases are performing
our contract with you (accounts and licenses) and our legitimate interests in
preventing abuse and securing the service (rate limiting, free-license limits, event
log).

We do not sell your data and do not share it for advertising.

## Processors

| Processor | Role |
| --- | --- |
| Cloudflare | DNS, the API at `api.kwatch.dev`, its database, and the Turnstile bot check on the sign-up form |
| Resend | Delivers sign-in and license emails |
| Cloudflare Pages | Hosts the website |

These providers may process data outside your country, including in the
United States, under their own data protection terms.

## Your rights

You can access, correct, export or delete your data. To delete your account,
sign in and use **Delete account** on the [account page](https://app.kwatch.dev/account). This
removes your account, sessions, licenses and activation records. For other
requests, email [hello@kwatch.dev](mailto:hello@kwatch.dev). If you are in
the EU or UK, you may also complain to your data protection authority.

## Children

kwatch is a tool for operating Kubernetes clusters and is not directed at
children under 16.

## Changes

We will post changes on this page and update the date above. Material changes
will be announced on this site.
