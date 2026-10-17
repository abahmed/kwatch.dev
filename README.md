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
yarn start:docs
```

Open the local URL printed by Docusaurus, usually `http://localhost:3000/`.

## ✍️ Where to edit

| Location | Contains |
| --- | --- |
| `apps/docs/docs/` | Public documentation pages |
| `apps/docs/src/theme/` | Docs UI overrides (search bar, 404) |
| `apps/docs/src/css/` | Site-wide styles |
| `apps/web/public/kwatch.sh` | Interactive installer and manager |
| `apps/docs/src/data/releases.json` | Stable and preview versions written by the release workflow |
| `apps/docs/sidebars.ts` | Documentation navigation |

Write for someone who may be seeing Kubernetes for the first time: start with
the goal, explain unfamiliar terms, show a complete command, and use fake
credentials in examples. Emojis are welcome when they improve scanning. 🙌

## 🧪 Check your changes

```bash
yarn docs:verify
yarn test:manager
yarn typecheck
yarn build:docs
yarn seo:verify
bash -n apps/web/public/kwatch.sh apps/docs/tests/*.sh
```

`yarn docs:verify` reads the catalogs from a checkout of the Kwatch repository
and refreshes the generated configuration, provider, and feature references.
Do not commit the generated `build/` directory.

`yarn seo:verify` checks the production build for non-empty page titles and
descriptions, canonical URLs, sitemap coverage, and the production robots
directive. It intentionally excludes the 404 page
from indexing.

## 📦 Release updates

The kwatch release workflow updates `apps/docs/src/data/releases.json` automatically:

- an RC updates the preview install link;
- a stable release updates the stable install link and clears the preview; and
- the website is built and deployed after the metadata commit.

The release workflow keeps manifest, chart, and catalog versions current. The
main kwatch README is intentionally version-free; install and RC selection are
handled by the interactive `kwatch.sh` manager.

### 🌐 Deployment

`.github/workflows/deploy.yml` deploys three Cloudflare Pages projects on push
to `main`. A job runs only when its app or `packages/brand` changed. Run the
workflow manually (`workflow_dispatch`) and pick `web`, `docs`, `app` or `all`
to force a deploy.

| Job | Builds | Pages project | Host |
| --- | --- | --- | --- |
| `web` | `apps/web` (`dist`) | `kwatch-site` | kwatch.dev |
| `docs` | `apps/docs` (`build`) | `kwatch-docs` | docs.kwatch.dev |
| `app` | `apps/app` (`dist`) | `kwatch-app` | app.kwatch.dev |

Secrets: `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.

#### Switching kwatch.dev to the new landing site

`kwatch-site` still serves the old site. Until you switch, nothing deploys to
it: the `web` job is skipped, `docs` deploys only to `kwatch-docs` and `app`
only to `kwatch-app`.

1. Create the `kwatch-docs` Pages project, attach `docs.kwatch.dev`, and run
   the `docs` job (push to `main` or run the workflow with `docs`). Check
   `https://docs.kwatch.dev/`.
2. Set the repository variable `DEPLOY_WEB_TO_KWATCH_SITE` to `true`
   (Settings, Secrets and variables, Actions, Variables).
3. Run the workflow with `web`. `kwatch-site` now serves `apps/web`, and later
   pushes that touch `apps/web` or `packages/brand` redeploy it.
4. Check `https://kwatch.dev/kwatch.sh`, `https://kwatch.dev/charts/index.yaml`
   and a sample `https://kwatch.dev/docs/installation` (301 to docs).

To stop web deploys, delete the variable (or set it to anything else). That
does not restore the old site; redeploy the previous `kwatch-site` build from
the Cloudflare dashboard if you need to roll back.

`kwatch.sh` and `charts/` live only in `apps/web/public`; the kwatch release
workflow writes the chart index and packages there.

## 🤝 Contribute

Read [Contributing](./docs/contributing/contributing.md) and
[Run the website locally](./docs/contributing/cloning-and-building.md), then
open a pull request against `main`.
