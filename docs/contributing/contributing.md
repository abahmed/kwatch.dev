---
sidebar_position: 1
title: Contributing
description: how to contribute code, documentation, tests, and ideas to kwatch
keywords: [kwatch, contribute, open source, github, pull request]
pagination_next: contributing/cloning-and-building
pagination_prev: null
---

# 🤝 Contributing to kwatch

Thank you for helping make Kubernetes easier to operate. You do not need to be
a Kubernetes expert to contribute. Documentation, bug reports, tests, ideas,
and small fixes are all useful.

## 🌱 Choose a way to help

- 🐛 [Report a bug](https://github.com/abahmed/kwatch/issues/new)
- 💡 [Suggest an improvement](https://github.com/abahmed/kwatch/issues)
- 📚 Improve a guide or example
- 🧪 Add or improve tests
- 💻 Fix an issue or build a feature
- 💬 Ask questions in [Discord](https://discord.gg/kzJszdKmJ7)

Before starting a large change, open an issue or discuss it in Discord. This
helps us agree on the approach and avoids duplicated work.

## 🛠️ A normal code contribution

1. Find an issue or open one describing the problem.
2. Fork the repository and create a focused branch.
3. Make the smallest change that solves the problem.
4. Add or update tests and documentation.
5. Run the verification command locally.
6. Open a pull request against `main` and explain what changed.

Read [Cloning and building](/docs/contributing/cloning-and-building) for local
setup and the [GitHub workflow](/docs/contributing/github-workflow) for the Git
commands.

## ✅ Before opening a pull request

```bash
go build ./...
go vet ./...
go test ./...
golangci-lint run
make verify
```

Keep changes focused, use clear names, and add comments only when they explain
a non-obvious decision. If a change affects configuration, alerts, persistence,
or release behavior, update the matching docs too.

## 📝 Documentation changes

Write for the person who is seeing the problem for the first time:

- Start with the goal and the result.
- Show a copy-pasteable example.
- Explain Kubernetes terms the first time you use them.
- Say whether a setting is on by default or opt-in.
- Never include real credentials in examples.
- Keep version pins inside the release-managed README blocks only.

## 📜 Community rules

Please follow the [Code of Conduct](https://github.com/abahmed/kwatch/blob/main/CODE_OF_CONDUCT.md).
Security issues should be reported privately using the process in
[SECURITY.md](https://github.com/abahmed/kwatch/blob/main/SECURITY.md).
