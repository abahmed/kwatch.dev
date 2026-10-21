---
layout: ../layouts/Legal.astro
page: privacy
title: Privacy policy
description: What data kwatch collects for accounts and Pro licenses, how telemetry works, how long data is kept and how to delete it.
updated: Oct 21, 2026
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
| License usage: license ID, hashed cluster ID, cluster proof hash, instance public key, kwatch version, node count, last renewal time | A licensed kwatch activates, or checks its license once a day | To bind one license to one cluster, prevent key sharing and show the cluster on your account page |
| License event log: activations, moves, renewals that failed, emails sent | License changes | To enforce transfer and free-license limits and investigate abuse |
| Free-license records: a one-way hash of your email and, for work email domains, the domain name (for example `acme.com`) | You get a free Pro license | To limit free Pro licenses to 2 clusters per account or per company domain |
| IP address | Any request to `api.kwatch.dev` | Abuse prevention only. Never stored with your account or licenses. |

We never receive workload names, logs, secrets, alerts or any other content
from your cluster. The cluster ID is a one-way hash of the `kube-system`
namespace UID, and the raw UID never leaves your cluster.

### IP addresses

We use your IP address only to prevent abuse. It is never stored with your
account or licenses.

The website does not use analytics or advertising cookies.

## Telemetry

Telemetry is on by default. kwatch sends an anonymous adoption ping, at most
once every 7 days, containing an anonymous ID derived from your cluster (a one-way hash that
can't be traced back to the cluster or linked to your license) and the kwatch
version, so we can see which versions are in use. It is separate from licensing, works in the
Community edition too, and contains no personal data. Turn it off with
`telemetry.enabled: false` or `KWATCH_TELEMETRY=false`.

## How long we keep data

| Data | Kept |
| --- | --- |
| Account, licenses and activation records | Until you delete your account |
| Sign-in links | 15 minutes, single use |
| Sessions | 30 days, or until you sign out |
| License event log | 180 days, keyed by license ID only |
| Telemetry ping (anonymous ID, kwatch version, last seen) | One row per anonymous ID, overwritten on each ping. There is no automatic deletion yet, so it is kept until removed on request |
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
