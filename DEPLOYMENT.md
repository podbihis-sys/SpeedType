# SpeedType Web Deployment Guide

This document explains how to deploy the SpeedType marketing site, legal pages, and `app-ads.txt` file to `https://speedtype.app`.

The `/web` directory in this repo is the publishable root. It contains:

```
web/
├── app-ads.txt       # AdMob / Google authorized sellers file
├── index.html        # Marketing landing page
├── privacy.html      # Privacy Policy (GDPR + CCPA)
└── terms.html        # Terms of Service
```

---

## 1. Goals

1. Serve `https://speedtype.app/` (landing page)
2. Serve `https://speedtype.app/app-ads.txt` (required for AdMob verification)
3. Serve `https://speedtype.app/privacy.html` and `https://speedtype.app/terms.html` (required for App Store & Play Store submission)
4. Enforce HTTPS with a valid TLS certificate
5. Ensure the site is crawlable and has good caching headers

---

## 2. Option A: GitHub Pages (Recommended for MVP)

GitHub Pages is free, fast, and fully static — perfect for this project.

### 2.1 Create the Pages branch

```bash
git checkout --orphan gh-pages
git rm -rf .
cp -r web/* .
git add .
git commit -m "Initial gh-pages deploy"
git push origin gh-pages
```

Alternatively, publish from a subfolder of `main`:

1. Go to **Settings → Pages** on GitHub.
2. Source: `Deploy from a branch`.
3. Branch: `main`, folder: `/web`.
4. Click **Save**.

### 2.2 Custom domain

1. In **Settings → Pages**, set the custom domain to `speedtype.app`.
2. Enable **Enforce HTTPS**.
3. GitHub auto-generates a `CNAME` file inside `/web` — commit it.

### 2.3 DNS configuration at your registrar

Add the following records at your DNS provider (e.g. Cloudflare, Namecheap, Porkbun):

| Type  | Name  | Value                   | TTL  |
| ----- | ----- | ----------------------- | ---- |
| A     | @     | 185.199.108.153         | auto |
| A     | @     | 185.199.109.153         | auto |
| A     | @     | 185.199.110.153         | auto |
| A     | @     | 185.199.111.153         | auto |
| CNAME | www   | `<your-org>.github.io`  | auto |

DNS propagation usually takes 5–30 minutes. Verify with:

```bash
dig speedtype.app +short
curl -I https://speedtype.app/app-ads.txt
```

### 2.4 HTTPS certificate

GitHub Pages automatically issues a Let's Encrypt certificate once DNS resolves correctly. If the certificate does not appear after 24 hours, toggle **Enforce HTTPS** off and on again, or remove and re-add the custom domain.

---

## 3. Option B: Firebase Hosting

Firebase Hosting is ideal if you already use Firebase for the rest of the backend (Auth, Firestore, etc.).

### 3.1 Install the CLI

```bash
npm install -g firebase-tools
firebase login
```

### 3.2 Initialize hosting

```bash
cd /path/to/SpeedType
firebase init hosting
# Public directory: web
# Single-page app: No
# Set up GitHub Action: optional
```

### 3.3 `firebase.json`

```json
{
  "hosting": {
    "public": "web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "cleanUrls": true,
    "headers": [
      {
        "source": "/app-ads.txt",
        "headers": [
          { "key": "Content-Type", "value": "text/plain; charset=UTF-8" },
          { "key": "Cache-Control", "value": "public, max-age=3600" }
        ]
      },
      {
        "source": "**/*.@(html)",
        "headers": [
          { "key": "Cache-Control", "value": "public, max-age=300" }
        ]
      }
    ]
  }
}
```

### 3.4 Deploy

```bash
firebase deploy --only hosting
```

### 3.5 Custom domain

1. Firebase Console → Hosting → **Add custom domain**.
2. Enter `speedtype.app`.
3. Add the TXT verification record and the two A records Firebase provides.
4. Wait for Firebase to provision the TLS certificate (up to 24h).

---

## 4. AdMob Publisher ID Verification

Before ads can serve, Google must verify that `speedtype.app` is an authorized seller for your AdMob account.

### 4.1 Find your publisher ID

1. Log in to <https://apps.admob.com>.
2. Go to **Settings → Account information**.
3. Copy your **Publisher ID** (format: `pub-1234567890123456`).

### 4.2 Update `app-ads.txt`

Replace `REPLACE_WITH_PUBLISHER_ID` in `/web/app-ads.txt` with your real publisher ID:

```
google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0
```

Commit and redeploy.

### 4.3 Declare the developer website in AdMob

1. AdMob → **Apps** → select your app → **App settings**.
2. Set **Developer website URL** to `https://speedtype.app`.
3. Ensure the same URL is set in your App Store Connect and Google Play Console listings.

### 4.4 Verify

Google crawls `app-ads.txt` within 24 hours. Check status:

- AdMob → **Apps → app-ads.txt**
- Direct URL: `https://speedtype.app/app-ads.txt`
- Third-party validator: <https://adstxt.guru/app-ads/>

The file must be served with `Content-Type: text/plain` and an HTTP 200 status.

---

## 5. DNS and HTTPS Checklist

Before promoting the URL anywhere, verify:

- [ ] `https://speedtype.app/` loads the landing page
- [ ] `https://www.speedtype.app/` redirects to the apex domain
- [ ] `https://speedtype.app/app-ads.txt` returns 200 + `text/plain`
- [ ] `https://speedtype.app/privacy.html` loads
- [ ] `https://speedtype.app/terms.html` loads
- [ ] Certificate is valid (check lock icon + <https://www.ssllabs.com/ssltest/>)
- [ ] HTTP redirects to HTTPS (`curl -I http://speedtype.app`)
- [ ] `robots.txt` (optional) allows crawling
- [ ] Google Search Console: property added and sitemap submitted

---

## 6. Cache-busting and Updates

Static HTML is cached briefly (300 seconds by default on Firebase, longer on GitHub Pages CDN). If you push an urgent update:

- **GitHub Pages**: changes take 1–5 minutes to propagate after push.
- **Firebase Hosting**: `firebase deploy` invalidates the CDN automatically.
- **CloudFlare (if used)**: run **Purge Everything** under *Caching*.

---

## 7. Monitoring

- Set up **UptimeRobot** or **BetterStack** to ping `https://speedtype.app/app-ads.txt` every 5 minutes. If this file ever 404s, AdMob revenue stops.
- Add the domain to **Google Search Console** to monitor indexing.
- Configure **Google Analytics 4** (optional) by adding the gtag snippet inside `index.html`.

---

## 8. Contacts

- Privacy issues: privacy@speedtype.app
- Legal / terms: terms@speedtype.app
- Technical / hosting: hello@speedtype.app
