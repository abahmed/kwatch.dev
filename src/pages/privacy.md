---
title: Privacy policy
description: What data kwatch collects for accounts and Pro licenses, how telemetry works, and how to delete your data.
---

# Privacy policy

> Draft — review before launch

This policy covers the kwatch website, the account portal and the license
service at `api.kwatch.dev`. The open-source Community edition runs entirely in
your cluster and needs no account.

## What we collect

- **Email address**, to create your account and send sign-in links.
- **License usage**, when a Pro or trial license is active: a hashed cluster
  id, the kwatch version, the node count and the time of the last renewal.
  We never receive workload names, logs, secrets or cluster contents.
- **IP address**, used only for rate limiting and abuse prevention.

## Telemetry

kwatch can send an anonymous weekly ping so we can see which versions are in
use. It contains no personal data and can be disabled in the configuration.

## How we use data

To run the license service, send sign-in emails, prevent abuse and improve
kwatch. We do not sell your data and do not share it for advertising.

## Processors

- **Cloudflare** provides DNS, hosting of the API edge and the Turnstile
  bot check on the sign-up form.
- **Resend** delivers sign-in emails.

## Deleting your data

Sign in and use **Delete account** on the [account page](/account). This
removes your account, licenses and activation records. Questions:
hello@kwatch.dev.
