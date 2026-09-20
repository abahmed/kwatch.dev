---
sidebar_position: 8
title: Release integrity
description: Verify kwatch images, checksums, release manifests, and Cosign signatures.
keywords: [kwatch release integrity, Cosign, Kubernetes image verification, SBOM]
---

# 🔐 Release integrity

Use this guide when you need to verify that an image or binary came from the
published kwatch release and was not changed on the way to your cluster.

Every published container release includes a source commit, image digest, release
SBOMs, checksums, a signed checksum manifest, and a release manifest. The image
and checksum manifest are signed with Cosign using GitHub Actions OIDC. Kwatch
does not connect to Sigstore at runtime.

## Installer trust boundary

`kwatch.sh` downloads release-tagged manifests and catalogs over HTTPS from the
Kwatch GitHub repository. Before applying them, it validates the release
version, catalog format, required manifest objects, named persistence
resources, rollout, RBAC, and workload security settings. It does not perform
local Cosign verification of the downloaded YAML. Environments that require
artifact verification before the installer runs should verify the release
checksum/signature and image digest first, then use the pinned release
artifacts according to their change-control process.

## Use the release image

Use the published version tag for normal installation, or pin the digest in a
deployment policy:

```shell
docker pull ghcr.io/abahmed/kwatch:vX.Y.Z
```

The release manifest records the relationship between the version tag, source commit,
image digest, and (for stable releases) Helm package checksum. The digest is
the verification identity; do not use a mutable tag as a security identity.

## Verify an image

Install Cosign, then verify the exact digest recorded in the release evidence:

```shell
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/abahmed/kwatch/.github/workflows/publish.yml@' \
  ghcr.io/abahmed/kwatch@sha256:<digest>
```

The command should be run against the exact digest, not `latest` or another mutable tag.

## Verify checksums

Download `SHA256SUMS` and the release files from the matching GitHub Release, then run:

```shell
sha256sum -c kwatch-vX.Y.Z-SHA256SUMS
```

The release manifest's `source.commit` must match the commit shown by the GitHub tag,
and its `image.digest` must match the digest used for the Cosign verification.

## Verify release assets

The signed checksum manifest authenticates the checksums for the source archive,
Helm chart, SBOMs, and other release evidence:

```shell
cosign verify-blob \
  --bundle kwatch-vX.Y.Z-SHA256SUMS.sigstore.json \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/abahmed/kwatch/.github/workflows/publish.yml@' \
  kwatch-vX.Y.Z-SHA256SUMS

sha256sum -c kwatch-vX.Y.Z-SHA256SUMS
```

The release contains CycloneDX SBOMs for the source tree and the exact image
digest. Confirm that the files named by the release manifest exist and contain
`bomFormat: CycloneDX` before using them for inventory or policy decisions.

## Verify image provenance

Verify the SLSA provenance attestation against the repository and image digest:

```shell
gh attestation verify \
  oci://ghcr.io/abahmed/kwatch@sha256:<digest> \
  --repo abahmed/kwatch \
  --signer-workflow abahmed/kwatch/.github/workflows/publish.yml \
  --predicate-type https://slsa.dev/provenance/v1
```

## Verify the running binary

The image embeds its version and source commit:

```shell
docker run --rm ghcr.io/abahmed/kwatch:vX.Y.Z version --json
```

The returned `version` and `commit` should match the release tag and manifest.
