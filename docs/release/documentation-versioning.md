---
title: Documentation versioning
description: How kwatch keeps documentation aligned with releases.
sidebar_position: 1
---

# Documentation versioning

Kwatch is not yet at a stable release, so the current documentation describes
the active development line. Breaking changes are allowed, but they must be
intentional and documented.

## Before the first stable release

- Keep one current documentation line.
- Mark unreleased behavior clearly.
- Add migration notes for configuration and persistence changes.
- Do not preserve obsolete architecture terminology merely for historical
  compatibility.
- Keep release notes for every user-visible behavior change.

## After stable releases

Introduce versioned documentation when users need to operate more than one
supported release line. Each supported version should identify:

- Kwatch version.
- Supported Kubernetes versions.
- Configuration compatibility.
- Persistence migration behavior.
- Provider or feature changes.
- Upgrade and rollback guidance.

The current development documentation may continue to describe `main`, but it
must not silently present unreleased behavior as stable.
