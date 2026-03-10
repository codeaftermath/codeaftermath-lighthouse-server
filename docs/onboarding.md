# Project Onboarding Guide

This guide walks through everything needed to connect a new project to the
CodeAftermath Lighthouse CI server — from installing the CLI to uploading
reports and viewing results.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install the LHCI CLI](#2-install-the-lhci-cli)
3. [Register a New Project](#3-register-a-new-project)
4. [Configure Your Project](#4-configure-your-project)
5. [Run Lighthouse Locally](#5-run-lighthouse-locally)
6. [Collect, Assert, and Upload](#6-collect-assert-and-upload)
7. [Automate with GitHub Actions](#7-automate-with-github-actions)
8. [View Results on the Server](#8-view-results-on-the-server)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

| Tool | Minimum version | Notes |
|---|---|---|
| Node.js | 18 LTS | Required to run `lhci` CLI |
| npm | 9+ | Bundled with Node 18+ |
| Chrome / Chromium | latest stable | Required for local `collect` runs |
| Git | any | For CI integration |

You will also need the following values from whoever manages the server:

- **Server URL** — e.g. `http://codeaftermath-lighthouse-alb-xxxx.us-east-1.elb.amazonaws.com`
- **Admin API key** — used only to create projects (one-time, keep secret)
- **Build token** — per-project token obtained during registration

---

## 2. Install the LHCI CLI

Install globally (recommended for local development):

```bash
npm install -g @lhci/cli
```

Or as a project dev-dependency (recommended for CI reproducibility):

```bash
npm install --save-dev @lhci/cli
```

Verify the installation:

```bash
lhci --version
# 0.13.x
```

---

## 3. Register a New Project

Projects are registered once via the admin API. This produces a **build token**
that is used in every subsequent upload.

### Option A — Interactive wizard (easiest)

```bash
lhci wizard
```

The wizard will prompt you for:

- LHCI server URL
- Project name
- Project external URL (your site's production URL)

It prints the build token at the end. **Save it — you cannot retrieve it
again.**

### Option B — `curl` / REST API

```bash
SERVER_URL="http://<alb-dns-name>"
ADMIN_KEY="<lhci_admin_api_key>"

curl -s -X POST "$SERVER_URL/v1/projects" \
  -H "Authorization: Bearer $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name":        "my-project",
    "externalUrl": "https://www.example.com",
    "slug":        "my-project"
  }' | jq .
```

The response contains `token` — this is your **build token**:

```json
{
  "id":          "abc123",
  "name":        "my-project",
  "externalUrl": "https://www.example.com",
  "slug":        "my-project",
  "token":       "BUILD_TOKEN_HERE",
  "adminToken":  "PROJECT_ADMIN_TOKEN_HERE"
}
```

Store `token` as a repository secret named `LHCI_BUILD_TOKEN`.

### Verify the project was created

```bash
curl -s "$SERVER_URL/v1/projects" | jq '.[].name'
```

---

## 4. Configure Your Project

Create a `lighthouserc.js` (or `.lighthouserc.json`) at the root of your
repository.

### Minimal configuration

```js
// lighthouserc.js
module.exports = {
  ci: {
    collect: {
      // URL(s) to audit — use 'startServerCommand' for server-side apps
      url: ['https://www.example.com'],
      numberOfRuns: 3,
    },
    assert: {
      preset: 'lighthouse:recommended',
    },
    upload: {
      target:        'lhci',
      serverBaseUrl: 'http://<alb-dns-name>',
      token:         process.env.LHCI_BUILD_TOKEN,
    },
  },
};
```

### Auditing a local dev server

If your app needs to be built and served first, use `startServerCommand`:

```js
module.exports = {
  ci: {
    collect: {
      startServerCommand: 'npm run serve',
      url:                ['http://localhost:3000', 'http://localhost:3000/about'],
      numberOfRuns:       3,
    },
    assert: {
      preset: 'lighthouse:no-pwa',
      assertions: {
        // Fail the build if performance drops below 90
        'categories:performance': ['error', { minScore: 0.9 }],
        // Warn (but do not fail) if accessibility drops below 95
        'categories:accessibility': ['warn', { minScore: 0.95 }],
      },
    },
    upload: {
      target:        'lhci',
      serverBaseUrl: 'http://<alb-dns-name>',
      token:         process.env.LHCI_BUILD_TOKEN,
    },
  },
};
```

### Auditing a static build directory

```js
module.exports = {
  ci: {
    collect: {
      staticDistDir: './dist',   // serve this directory automatically
      url:           ['/'],
      numberOfRuns:  3,
    },
    upload: {
      target:        'lhci',
      serverBaseUrl: 'http://<alb-dns-name>',
      token:         process.env.LHCI_BUILD_TOKEN,
    },
  },
};
```

---

## 5. Run Lighthouse Locally

### Health-check the server

Before running any audits, confirm that the server is reachable:

```bash
lhci healthcheck \
  --fatal \
  --config=lighthouserc.js
```

A passing output looks like:

```
✅  .lighthouserc.js file found
✅  Configuration valid
✅  LHCI server reachable (200)
✅  Build token valid
```

### One-off audit against a live URL

```bash
lhci collect \
  --url=https://www.example.com \
  --numberOfRuns=1
```

Reports are saved to `.lighthouseci/` by default.

### View a collected report in the browser

```bash
# Open the most recent HTML report
lhci open
```

---

## 6. Collect, Assert, and Upload

These three commands form the core LHCI workflow and can be run individually
or together with `autorun`.

### Step-by-step

```bash
# 1. Collect — run Lighthouse and save reports locally
lhci collect --config=lighthouserc.js

# 2. Assert — compare results against budget thresholds
lhci assert --config=lighthouserc.js

# 3. Upload — send reports to the private LHCI server
lhci upload --config=lighthouserc.js
```

### All-in-one with `autorun`

`autorun` executes collect → assert → upload in sequence and exits with a
non-zero code if any assertion fails:

```bash
LHCI_BUILD_TOKEN=<token> lhci autorun --config=lighthouserc.js
```

### Upload options reference

| Flag | Description |
|---|---|
| `--target=lhci` | Upload to an LHCI server (required) |
| `--serverBaseUrl` | Base URL of your Lighthouse server |
| `--token` | Project build token |
| `--extraHeaders` | Additional HTTP headers sent with each upload |
| `--ignoreDuplicateBuildFailure` | Don't fail if a duplicate build already exists |
| `--basicAuth.username` | Basic-auth username (if ALB has HTTP basic auth) |
| `--basicAuth.password` | Basic-auth password |

### Useful `collect` flags

| Flag | Description |
|---|---|
| `--url` | One or more URLs to audit (comma-separated) |
| `--numberOfRuns` | Audits per URL (median is uploaded; default 3) |
| `--startServerCommand` | Shell command to start your dev server |
| `--staticDistDir` | Serve a local directory automatically |
| `--puppeteerScript` | Path to a Puppeteer script for authenticated flows |
| `--settings.onlyCategories` | Comma-separated categories: `performance,accessibility,best-practices,seo,pwa` |
| `--settings.formFactor` | `desktop` or `mobile` (default) |
| `--settings.throttling.cpuSlowdownMultiplier` | CPU throttle multiplier (default 4) |

### Useful `assert` flags

| Flag | Description |
|---|---|
| `--preset` | `lighthouse:all`, `lighthouse:recommended`, `lighthouse:no-pwa` |
| `--assertions.*` | Override individual assertion thresholds |
| `--budgetsFile` | Path to a `budget.json` file |

---

## 7. Automate with GitHub Actions

Add the following workflow to your project repository. Replace the placeholder
values with your actual server URL.

```yaml
# .github/workflows/lighthouse-ci.yml
name: Lighthouse CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lighthouse:
    name: Lighthouse Audit
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      # If your app needs to be built first, add the build steps here.
      # - name: Install dependencies
      #   run: npm ci
      # - name: Build
      #   run: npm run build

      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v11
        with:
          configPath: ./lighthouserc.js
          serverBaseUrl: ${{ vars.LHCI_SERVER_URL }}
          serverToken: ${{ secrets.LHCI_BUILD_TOKEN }}
          uploadArtifacts: true
          temporaryPublicStorage: false
```

### Required repository configuration

| Type | Name | Value |
|---|---|---|
| Variable | `LHCI_SERVER_URL` | `http://<alb-dns-name>` |
| Secret | `LHCI_BUILD_TOKEN` | Token from [Step 3](#3-register-a-new-project) |

Set these under **Settings → Secrets and variables → Actions** in your repository.

### Using `lhci` CLI directly (no Action)

```yaml
      - name: Install LHCI CLI
        run: npm install -g @lhci/cli

      - name: Run Lighthouse CI
        run: lhci autorun --config=lighthouserc.js
        env:
          LHCI_BUILD_TOKEN: ${{ secrets.LHCI_BUILD_TOKEN }}
```

---

## 8. View Results on the Server

Open the server URL in a browser:

```
http://<alb-dns-name>
```

The dashboard shows:

- All registered projects
- Historical report trend graphs (performance, accessibility, best-practices, SEO, PWA)
- Side-by-side comparison between any two builds
- Detailed Lighthouse reports for every run

### Useful API endpoints

```bash
SERVER="http://<alb-dns-name>"

# Server version
curl "$SERVER/v1/version"

# List all projects
curl "$SERVER/v1/projects"

# List builds for a project
curl "$SERVER/v1/projects/<project-id>/builds"

# Get a specific build's runs
curl "$SERVER/v1/projects/<project-id>/builds/<build-id>/runs"
```

---

## 9. Troubleshooting

### `LHCI server reachable` fails

- Confirm the ALB DNS name is correct and the ECS task is running.
- Check that port 80 is open in the ALB security group.
- Verify with: `curl -v http://<alb-dns-name>/v1/version`

### Build token rejected (401)

- Re-run the wizard or API call from [Step 3](#3-register-a-new-project).
- Ensure `LHCI_BUILD_TOKEN` secret is set correctly in GitHub.

### Duplicate build error

Add `--ignoreDuplicateBuildFailure` to `lhci upload` or set it in `lighthouserc.js`:

```js
upload: {
  ignoreDuplicateBuildFailure: true,
  // ...
},
```

### No Chrome found during `lhci collect`

Install Chrome on the runner:

```yaml
      - name: Install Chrome
        uses: browser-actions/setup-chrome@v1
```

Or set `CHROME_PATH` explicitly:

```bash
CHROME_PATH=$(which google-chrome-stable) lhci collect ...
```

### Reports are collected but scores seem inconsistent

Increase `numberOfRuns` to 5 (the CLI uploads the median run):

```js
collect: {
  numberOfRuns: 5,
},
```

Network and CPU throttling is applied by default. To disable throttling
for a faster local test:

```bash
lhci collect \
  --url=http://localhost:3000 \
  --settings.throttling.cpuSlowdownMultiplier=1 \
  --settings.throttling.downloadThroughputKbps=0 \
  --settings.throttling.uploadThroughputKbps=0
```
