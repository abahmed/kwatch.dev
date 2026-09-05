---
sidebar_position: 3
title: GitHub workflow
description: the simple GitHub workflow for contributing to kwatch.dev
keywords: [kwatch, github, git, contribute, pull request, fork]
pagination_next: null
pagination_prev: contributing/cloning-and-building
---

# 🔁 GitHub workflow

If GitHub is new to you, read GitHub's [Hello World guide](https://docs.github.com/en/get-started/start-your-journey/hello-world) first. The flow below is the same for documentation and code changes.

## 1. 🍴 Fork and clone

Click **Fork** on the repository, then clone your fork:

```bash
git clone https://github.com/YOUR-USERNAME/kwatch.dev.git
cd kwatch.dev
git remote add upstream https://github.com/abahmed/kwatch.dev.git
```

Here, `origin` is your fork and `upstream` is the main project.

## 2. 🌿 Create a branch

```bash
git fetch upstream
git switch -c improve-alert-docs upstream/main
```

Choose a short branch name that describes the change.

## 3. ✍️ Make and check your changes

Edit the docs or site, then run:

```bash
yarn typecheck
yarn build
```

Read the page once as a new user. Check that commands are complete, examples use fake credentials, and links work.

## 4. 📤 Push and open a pull request

```bash
git add docs/ src/ sidebars.ts
git commit -m "docs: clarify alert setup"
git push -u origin improve-alert-docs
```

Open a pull request from your branch to `abahmed/kwatch.dev:main`. Explain:

- what changed;
- who the change helps; and
- how you checked it.

## 5. 🔄 Keep the branch current

If `main` changes while your pull request is open:

```bash
git fetch upstream
git rebase upstream/main
git push --force-with-lease
```

Only use `--force-with-lease` on your own feature branch. Never force-push `main`.

## 💬 Need help?

Ask in [Discord](https://discord.gg/kzJszdKmJ7) or comment on the issue before starting a large change. Small improvements are welcome too. 🙌
