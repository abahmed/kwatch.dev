# Documentation and website maintainers

This repository is the canonical source for published kwatch documentation,
the public website, and documentation navigation.

## Responsibilities

Maintainers review:

- Documentation information architecture.
- User, operator, contributor, and release content.
- Generated reference synchronization.
- Docusaurus configuration and navigation.
- Accessibility, mobile behavior, search, and broken links.
- Release and migration documentation.

## Review expectations

Documentation changes should explain their audience and document type. Changes
to generated pages must update the source catalogs or generator instead of
editing generated output directly.

Behavior changes in the main Kwatch repository should update the corresponding
website documentation before release. Website-only changes must not redefine
runtime behavior or configuration contracts.

## Local verification

```sh
yarn test:manager
yarn docs:verify
yarn typecheck
yarn build
```
