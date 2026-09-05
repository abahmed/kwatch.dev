---
sidebar_position: 2
title: Run the website locally
description: clone, edit, and verify the kwatch documentation website
keywords: [kwatch, website, docusaurus, contribute, node, yarn, build]
pagination_next: contributing/github-workflow
pagination_prev: contributing/contributing
---

# 🧑‍💻 Run the website locally

This guide is for changes to `kwatch.dev`: documentation, landing-page copy,
styles, and components. For changes to the Kubernetes monitor itself, use the
[kwatch repository contribution guide](https://github.com/abahmed/kwatch/blob/main/CONTRIBUTING.md).

## ✅ Install the tools

You need:

- [Git](https://git-scm.com/downloads)
- [Node.js 18 or newer](https://nodejs.org/)
- [Yarn](https://classic.yarnpkg.com/lang/en/docs/install/)

Check your versions:

```bash
git --version
node --version
yarn --version
```

## 📥 Clone the site

```bash
git clone https://github.com/abahmed/kwatch.dev.git
cd kwatch.dev
yarn install
```

## 👀 Preview your changes

```bash
yarn start
```

Open the local URL printed by Docusaurus, usually
`http://localhost:3000/`. Documentation pages live in `docs/`; the homepage
components live in `src/`.

## 🧪 Verify before opening a pull request

Run the type checker and production build:

```bash
yarn typecheck
yarn build
```

The build creates static files in `build/`. Do not commit that generated
directory.

## ✍️ Add a documentation page

1. Create a Markdown file under `docs/`.
2. Add frontmatter with a clear `title` and `description`.
3. Start with the task the reader wants to complete.
4. Use a copy-pasteable example and explain required values.
5. Add the page to `sidebars.ts` when it belongs in the public navigation.
6. Run `yarn typecheck` and `yarn build`.

Use short sections, simple English, and emojis when they clarify the topic.
Do not put real tokens, passwords, or webhook URLs in examples.
