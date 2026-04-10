# SpeedType Deployment Guide

This document explains how to deploy the SpeedType marketing website and the `app-ads.txt` file required for AdMob. The site is a static bundle under `/web` and can be hosted on GitHub Pages, Firebase Hosting, Cloudflare Pages, Netlify, or any static host.

## Table of Contents

1. [Directory Layout](#1-directory-layout)
2. [Option A: GitHub Pages](#2-option-a-github-pages)
3. [Option B: Firebase Hosting](#3-option-b-firebase-hosting)
4. [AdMob Publisher ID and app-ads.txt](#4-admob-publisher-id-and-app-adstxt)
5. [DNS Configuration (speedtype.app)](#5-dns-configuration-speedtypeapp)
6. [HTTPS Setup](#6-https-setup)
7. [Post-Deployment Verification](#7-post-deployment-verification)

---

## 1. Directory Layout

```
web/
├── index.html       Marketing landing page
├── privacy.html     Privacy policy
├── terms.html       Terms of service
└── app-ads.txt      AdMob publisher declaration
```

All files are self-contained: no build step, no bundler, no assets to upload separately. Everything must be served over HTTPS from the root of `speedtype.app` so that AdMob, Google, and the App Store crawlers can locate them at:

- `https://speedtype.app/`
- `https://speedtype.app/privacy.html`
- `https://speedtype.app/terms.html`
- `https://speedtype.app/app-ads.txt`

---

## 2. Option A: GitHub Pages

GitHub Pages is the recommended host because it is free, supports custom domains, auto-provisions HTTPS, and is triggered by a simple `git push`.

### 2.1 Enable Pages from the `web/` folder

GitHub Pages can serve either from the repository root or from `/docs`. The cleanest approach is to publish `web/` via a GitHub Actions workflow so the repo structure stays intact.

Create `.github/workflows/pages.yml`:

```yaml
name: Deploy website to GitHub Pages

on:
  push:
    branches: [main]
    paths: ['web/**', '.github/workflows/pages.yml']
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: ./web
      - id: deployment
        uses: actions/deploy-pages@v4
```

### 2.2 Configure Pages in the repo

1. Go to **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to **GitHub Actions**.
3. Push to `main`. The workflow will deploy `web/` to Pages.
4. Verify at the `github.io` URL shown under **Settings → Pages**.

### 2.3 Attach the custom domain

1. Under **Settings → Pages**, enter `speedtype.app` in the **Custom domain** field and save.
2. GitHub will add a `CNAME` file to the deployed artifact automatically.
3. Wait for DNS verification (see section 5) and enable **Enforce HTTPS**.

---

## 3. Option B: Firebase Hosting

If you already use Firebase for SpeedType (Auth, Firestore, Analytics), hosting the site from the same project keeps everything in one place.

### 3.1 Initialize hosting

```bash
npm install -g firebase-tools
firebase login
firebase init hosting
```

When prompted, configure:

- Public directory: `web`
- Single-page app: **No**
- Overwrite `index.html`: **No**

This creates `firebase.json`:

```json
{
  "hosting": {
    "public": "web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "headers": [
      {
        "source": "app-ads.txt",
        "headers": [
          { "key": "Content-Type", "value": "text/plain; charset=utf-8" },
          { "key": "Cache-Control", "value": "public, max-age=3600" }
        ]
      }
    ],
    "cleanUrls": true
  }
}
```

### 3.2 Deploy

```bash
firebase deploy --only hosting
```

### 3.3 Add the custom domain

1. Firebase Console → **Hosting → Add custom domain**.
2. Enter `speedtype.app` and follow the ownership verification (TXT record) and the A-record instructions.
3. Firebase provisions a free Let's Encrypt certificate automatically.

---

## 4. AdMob Publisher ID and app-ads.txt

`app-ads.txt` is the mobile equivalent of `ads.txt` for the web. Google requires it to verify that the accounts declared in your app store listings are authorized to sell your app's inventory.

### 4.1 Find your AdMob Publisher ID

1. Log in to [apps.admob.com](https://apps.admob.com).
2. Click **Account** (top-right) → **Account Information**.
3. Copy the **Publisher ID** (format: `pub-1234567890123456`).

### 4.2 Update `web/app-ads.txt`

Replace the placeholder in `web/app-ads.txt`:

```
google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0
```

If you use additional ad networks (Meta Audience Network, AppLovin, Unity Ads), add one line per network. Each network provides its own entry; ask their support or consult their docs. Example:

```
google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0
applovin.com, 9a1b2c3d4e5f, DIRECT
facebook.com, 1122334455667788, DIRECT, c3e20eee3f780d68
```

### 4.3 Declare the developer website in the App Store listings

`app-ads.txt` only works if Google can find it at the URL declared on each store:

- **Google Play Console** → your app → **Main store listing** → **Website**: `https://speedtype.app`
- **App Store Connect** → your app → **App Information** → **Marketing URL**: `https://speedtype.app`

Both fields must match the domain that hosts `app-ads.txt`. Use the apex domain (`speedtype.app`), not a subdomain.

### 4.4 Verification in AdMob

1. AdMob Console → **Apps → app-ads.txt**.
2. Click **Check for updates**. Google's crawler typically verifies within 24 hours.
3. Status should change from **Not found** to **Authorized**.

If verification fails:

- Confirm `https://speedtype.app/app-ads.txt` returns HTTP 200 with `Content-Type: text/plain`.
- Confirm the Publisher ID matches your AdMob account exactly.
- Confirm both store listings point to the same `speedtype.app` URL.
- Clear any CDN cache that might be serving a stale file.

---

## 5. DNS Configuration (speedtype.app)

At your domain registrar (Namecheap, Cloudflare, GoDaddy, etc.), configure the following records.

### 5.1 GitHub Pages

```
Type    Host    Value
A       @       185.199.108.153
A       @       185.199.109.153
A       @       185.199.110.153
A       @       185.199.111.153
AAAA    @       2606:50c0:8000::153
AAAA    @       2606:50c0:8001::153
AAAA    @       2606:50c0:8002::153
AAAA    @       2606:50c0:8003::153
CNAME   www     <your-gh-username>.github.io
```

### 5.2 Firebase Hosting

Firebase displays the exact records to add during the custom domain setup (two A records or an `AAAA` pair). Follow the console instructions exactly.

### 5.3 TTL

Use a TTL of 300 seconds (5 min) during setup. Raise to 3600 once everything verifies.

### 5.4 CAA records (optional but recommended)

```
Type    Host    Value
CAA     @       0 issue "letsencrypt.org"
CAA     @       0 issue "pki.goog"
```

These allow only Let's Encrypt and Google Trust Services to issue certificates for your domain, reducing the risk of mis-issuance.

---

## 6. HTTPS Setup

Both GitHub Pages and Firebase Hosting provision HTTPS certificates automatically via Let's Encrypt. You do not need to install a certificate manually.

Checklist:

- GitHub Pages: tick **Enforce HTTPS** under **Settings → Pages**.
- Firebase: HTTPS is on by default; no action needed.
- Verify redirects: `http://speedtype.app` → `https://speedtype.app` (both hosts do this automatically).
- Do not host `app-ads.txt` over HTTP only. Google now requires HTTPS for `app-ads.txt`.

If you sit behind Cloudflare, set SSL/TLS mode to **Full (strict)** so Cloudflare validates the origin certificate. Do NOT use **Flexible** mode: it serves HTTPS to visitors but talks HTTP to the origin, which can break `app-ads.txt` verification.

---

## 7. Post-Deployment Verification

After deployment, verify the following:

```bash
# 1. Landing page loads
curl -I https://speedtype.app/ | head -1
# → HTTP/2 200

# 2. Privacy and terms load
curl -I https://speedtype.app/privacy.html | head -1
curl -I https://speedtype.app/terms.html | head -1

# 3. app-ads.txt returns correct content-type
curl -I https://speedtype.app/app-ads.txt
# → content-type: text/plain

# 4. app-ads.txt content
curl https://speedtype.app/app-ads.txt

# 5. SSL is valid
curl -vI https://speedtype.app/ 2>&1 | grep -i "ssl\|tls\|subject"
```

Tools:

- [SSL Labs](https://www.ssllabs.com/ssltest/) — check TLS configuration
- [Google Search Console](https://search.google.com/search-console) — submit the sitemap (optional)
- [AdMob Console](https://apps.admob.com/v2/home) → app-ads.txt status
- [Rich Results Test](https://search.google.com/test/rich-results) — validate structured data on `index.html`

Once verified, the site is production-ready and AdMob will begin crawling `app-ads.txt` on its regular schedule.
