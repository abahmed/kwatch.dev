# kwatch.dev

The public website and documentation for [kwatch](https://github.com/abahmed/kwatch):

> **See what broke. Understand why. Know what to do next. 👀🧠⚡**

This repository contains the landing page, user guides, provider guides, and
contributor docs. The Kubernetes monitor itself lives in the
[`abahmed/kwatch`](https://github.com/abahmed/kwatch) repository.

## 🚀 Run it locally

Requirements: Node.js 18+, Yarn, and Git.

```bash
git clone https://github.com/abahmed/kwatch.dev.git
cd kwatch.dev
yarn install
yarn start
```

Open the local URL printed by Docusaurus, usually `http://localhost:3000/`.

## ✍️ Where to edit

| Location | Contains |
| --- | --- |
| `docs/` | Public documentation pages |
| `src/pages/index.tsx` | Landing page layout |
| `src/theme/` | Homepage components and shared docs UI |
| `src/css/` | Site-wide styles |
| `static/kwatch.sh` | Interactive installer and manager |
| `src/data/releases.json` | Stable and preview versions shown on the site |
| `sidebars.ts` | Documentation navigation |

Write for someone who may be seeing Kubernetes for the first time: start with
the goal, explain unfamiliar terms, show a complete command, and use fake
credentials in examples. Emojis are welcome when they improve scanning. 🙌

## 🧪 Check your changes

```bash
yarn test:manager
yarn typecheck
yarn build
```

Do not commit the generated `build/` directory.

## 📦 Release updates

The kwatch release workflow updates `src/data/releases.json` automatically:

- an RC updates the preview install link;
- a stable release updates the stable install link and clears the preview; and
- the website is built and deployed after the metadata commit.

The release workflow keeps manifest, chart, and catalog versions current. The
main kwatch README is intentionally version-free; install and RC selection are
handled by the interactive `kwatch.sh` manager.

### 🌐 Deployment

The website is hosted on Render. Pushes to `main` trigger the repository
workflow, which calls the `RENDER_DEPLOY_HOOK_URL` secret when it is configured.
If the secret is not present, enable Render's native auto-deploy for the `main`
branch or add the deploy-hook secret in the repository settings.

## 🤝 Contribute

Read [Contributing](./docs/contributing/contributing.md) and
[Run the website locally](./docs/contributing/cloning-and-building.md), then
open a pull request against `main`.
