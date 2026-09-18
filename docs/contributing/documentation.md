---
title: Documentation contribution guide
description: How to write, review, test, and maintain kwatch documentation.
sidebar_position: 3
---

# Documentation contribution guide

The website repository is the canonical source for published documentation.
The Go repository owns code-derived generators and source-tree agent rules.
Do not manually maintain two copies of the same technical fact.

## Choose the right document type

- **Tutorial:** teaches a complete first success.
- **How-to:** solves one task or operational problem.
- **Reference:** states exact fields, defaults, commands, or contracts.
- **Explanation:** describes architecture, concepts, and trade-offs.
- **Operations:** documents production diagnosis, recovery, and capacity.

## Writing rules

- Use a task-oriented title.
- State prerequisites before commands.
- Use present tense and active voice.
- Address the reader as “you”.
- Explain Kubernetes terms when they first appear.
- Keep commands complete and copy-pasteable.
- Show expected output when it helps verify progress.
- Never use real credentials in examples.
- Mark destructive actions clearly.
- Avoid undocumented promises about future behavior.

## Generated pages

Configuration, CLI, feature, provider, RBAC, metrics, health, and schema
references should be generated from the main repository whenever possible.
Generated pages must identify their source and must not be edited manually.

## Review checklist

- Is the intended audience clear?
- Is the task or concept clear from the title?
- Are prerequisites explicit?
- Do commands match the current code and manifests?
- Are failure paths and recovery steps documented?
- Are security and secret-handling concerns covered?
- Are links valid?
- Does the page belong in the correct documentation category?
- Is an existing page duplicated instead of linked?
