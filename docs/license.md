---
sidebar_position: 9
title: License
description: Get, install, transfer and troubleshoot a kwatch Pro license key.
keywords: [kwatch license, kwatch Pro, license key, helm, activation, grace period]
---

# License

Community needs no license. Pro features need a license key, one per cluster.

## Get a key

[Sign up](/signup) with your email, open the sign-in link and choose
**Start 90-day Pro trial** on your [account page](/account). Your key is
shown there.

## Install the key

With Helm:

```bash
kubectl create secret generic kwatch-license -n kwatch \
  --from-literal=license-key=YOUR_KEY
helm upgrade --install kwatch kwatch/kwatch \
  --set license.existingSecret=kwatch-license
```

With the [kwatch.sh manager](/docs/kwatch-sh): run it and open the **License**
menu.

## How activation works

On start, kwatch sends the license service a hashed cluster id, its version and
the node count, then renews periodically. The first successful check binds the
key to that cluster. Nothing else about your cluster is sent.

## Offline use

If the license service is unreachable, kwatch keeps its Pro features for up
to 7 days from the last successful renewal: each renewal is valid for 3 days,
followed by a 4-day grace period.

## Transfer

A key is bound to one cluster. To move it, use **Transfer to another cluster**
on the account page, then install the key on the new cluster. The number of
transfers left is shown there. You get 3 transfers per 30 days. Releasing the
license during uninstall (`kwatch license deactivate`) counts as a transfer.
If the old cluster has not renewed for 7 days, for example because it was
deleted, the key moves to the new cluster automatically. **Regenerate key**
issues a new key and invalidates the old one.

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
| `conflict` | The key is active on another cluster. | Transfer it to this cluster, or use a separate key. |

## What is sent

A hashed cluster id, kwatch version and node count. See the
[privacy policy](/privacy).
