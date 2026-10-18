---
sidebar_position: 9
title: "kwatch Pro license key: get, install, move, troubleshoot"
sidebar_label: License
description: Get, install, move and troubleshoot a kwatch Pro license key.
keywords: [kwatch license, kwatch Pro, license key, installer, activation, grace period]
---

# 🔑 License

Community needs no license. Pro features need a license key, one per cluster.

## Get a key

[Sign up](https://app.kwatch.dev) with your email, open the sign-in link and choose
**Get 3 months of Pro free** on your [account page](https://app.kwatch.dev). Your key is
shown there.

During early access Pro is free and covers up to 2 clusters (one license key
per cluster, each valid for 3 months from the day you start it, and we may
renew it). With a work email the limit is 2
clusters per company domain, shared by everyone using that domain, for
example alice@acme.com and bob@acme.com together get 2. With a free mailbox
provider such as Gmail or Outlook the limit is per account. Deleting an
account does not reset it. Need more? [Contact us](mailto:hello@kwatch.dev).

## Install the key

The [kwatch.sh installer](/kwatch-sh) is the way to set up a license.
Run it:

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

Then open **License / Pro** and choose **Add or replace key**, and paste your
key. The installer stores it in a Kubernetes Secret and applies it to kwatch.
During a fresh install it also asks for a key at the end.

For a non-interactive run, set `KWATCH_LICENSE_KEY` in the environment of the
same command, and the installer stores and applies the key without prompting:

```bash
KWATCH_LICENSE_KEY=YOUR_KEY \
  /bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

## How activation works

On start, kwatch sends the license service a hashed cluster id, its version and
the node count, then renews daily. The first successful check binds the
key to that cluster. Nothing else about your cluster is sent.

## Offline use

If the license service is unreachable, kwatch keeps its Pro features for up
to 7 days from the last successful renewal: each renewal is valid for 3 days,
followed by a 4-day grace period.

## Moving to another cluster

A key is bound to one cluster at a time. There are two ways to move it, and
both count toward the same limit of 3 moves per 30 days.

**From the new cluster.** Point `kubectl` at the new cluster and run the
[kwatch.sh installer](/kwatch-sh):

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

Choose **License / Pro**, then **Move license to this cluster**. The installer
takes the license over and shows the outcome: moved, already on this cluster,
transfer limit reached (with the days until a slot frees), or invalid key.
Install the key on the new cluster first with **Add or replace key** if it is
not there yet.

**From the website.** Use **Transfer to another cluster** on your
[account page](https://app.kwatch.dev). This releases the license; the new cluster picks it
up on its own within about 5 minutes. A cluster that finds its license bound
elsewhere asks again every 5 minutes for the first hour, then hourly.

**The old cluster.** It learns about the move at its next daily check and
drops to Community; detection and alerting keep running. You also get an email
when a license is moved from the installer, so you can regenerate the key if it
was not you.

The number of moves left is shown on the account page. A move made with
the installer, a transfer on the website and releasing the license during
uninstall all use the same 3 per 30 days.
If the old cluster has not renewed for 7 days, for example because it was
deleted, the key moves to the new cluster automatically, without using one of
the 3 moves. **Regenerate key** issues a new key and invalidates
the old one.

## Expiry

When a license expires, kwatch falls back to Community. Detection and alerting
continue; Pro-only features turn off.

## Troubleshooting `/status`

The license state appears in the `/status` output:

| State | Meaning | What to do |
| --- | --- | --- |
| `community` | No key configured. | Install a key for Pro features. |
| `invalid` | The key is malformed or unrecognised. | Re-copy the key from your account page. |
| `pending` | A key is present but not yet verified. | Wait for the first check; verify outbound access to `api.kwatch.dev`. |
| `active` | License valid and renewed. | Nothing. |
| `grace` | Renewal failing, within the grace period (up to 7 days offline). | Restore network access to `api.kwatch.dev`. |
| `expired` | The license has expired. | Start or renew a license on your account page. |
| `revoked` | The license was revoked. | Contact hello@kwatch.dev. |
| `conflict` | The key is active on another cluster. | Run the installer here and choose **License / Pro**, then **Move license to this cluster**; or transfer it on your account page, or use a separate key. |

## What is sent

A hashed cluster id, kwatch version, node count and the instance public key. See the
[privacy policy](https://kwatch.dev/privacy).
