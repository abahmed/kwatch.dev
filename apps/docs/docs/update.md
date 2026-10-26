---
sidebar_position: 2
title: Update kwatch
description: Update a running kwatch to the latest release with the kwatch.sh installer, and check which version is running.
keywords: [update kwatch, upgrade kwatch, kwatch version, kwatch.sh, update available]
---

# ⬆️ Update kwatch

Update kwatch with the same [`kwatch.sh` installer](/kwatch-sh) you used to install it. Your settings and data are kept.

## Update to the latest release

1. Run the installer against the cluster kwatch runs in:

   ```bash
   bash <(curl -fsSL https://kwatch.dev/kwatch.sh)
   ```

2. Choose **Upgrade kwatch**.
3. Pick a release from the list. The latest stable release is offered first; a release candidate appears only when one is available.
4. Confirm. The installer updates the Deployment and rolls back if the rollout fails.

If you already run the newest release, the installer says so and changes nothing.

## Check the running version

Choose **View status** in the installer menu. It shows the version kwatch is running.

Signed in at [app.kwatch.dev](https://app.kwatch.dev), the license page shows each cluster's version. It updates shortly after kwatch restarts on the new version, and the "Update available" badge goes away.

## Updating from v0.10.x

Moving from `v0.10.x` to `v1.0.0` is a one-time migration. Follow [Upgrading to v1.0.0](/upgrading).
