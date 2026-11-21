---
title: Verify the kwatch.sh installer before you run it
sidebar_label: Verify the installer
description: Read kwatch.sh before running it, see what the installer checks by itself, and verify release checksums and signatures manually.
keywords: [kwatch.sh, verify installer, SHA256SUMS, cosign, supply chain, security]
---

# 🔐 Verify the installer

kwatch is source available under ELv2. You can read the installer and check
what it installs before it touches your cluster.

## Read it, then run it

```bash
curl -fsSLo kwatch.sh https://kwatch.dev/kwatch.sh
less kwatch.sh
bash kwatch.sh
```

The script is plain Bash. Its source is
`apps/web/public/kwatch.sh` in the
[kwatch.dev repository](https://github.com/abahmed/kwatch.dev), so you can
compare what you downloaded with the repository.

## What the installer checks itself

For each manifest it applies from a release (`deploy/deploy.yaml` and
`deploy/crd.yaml`), the installer:

1. Downloads `SHA256SUMS` from that release on GitHub.
2. Compares the SHA-256 of the downloaded manifest with its entry in
   `SHA256SUMS`. A mismatch, a missing entry or a failed download stops the
   install.
3. If `cosign` is installed and the release publishes
   `SHA256SUMS.sigstore.json`, verifies the signature on `SHA256SUMS`. It must
   come from the kwatch `publish.yml` GitHub Actions workflow. A failed
   signature stops the install.

Without `cosign`, only the SHA-256 check runs and the installer says so. A
release that publishes no `SHA256SUMS` asks you to confirm; non-interactive
runs stop unless you set `KWATCH_ALLOW_UNVERIFIED=1`.

## Verify a release by hand

Releases publish `SHA256SUMS` and `SHA256SUMS.sigstore.json` next to the chart,
image digests, SBOMs and source archive.

```bash
V=v1.2.0
BASE=https://github.com/abahmed/kwatch/releases/download/$V
curl -fsSLO $BASE/SHA256SUMS
curl -fsSLO $BASE/SHA256SUMS.sigstore.json

cosign verify-blob --bundle SHA256SUMS.sigstore.json \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/abahmed/kwatch/.github/workflows/publish.yml@' \
  SHA256SUMS

sha256sum -c --ignore-missing SHA256SUMS
```

On macOS use `shasum -a 256 -c` instead of `sha256sum -c`.

## Report a security issue

See [security.txt](https://kwatch.dev/.well-known/security.txt).
