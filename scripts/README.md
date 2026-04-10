# SpeedType Scripts

Utility Node.js scripts for administrative tasks on the SpeedType backend.

## Prerequisites

- Node.js 18+ and npm
- Firebase project with Firestore enabled
- Service account credentials with Firestore write access

## Setup

### 1. Download your Firebase service account key

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Open your SpeedType project.
3. Navigate to **Project Settings** (gear icon in the sidebar).
4. Click the **Service Accounts** tab.
5. Click **Generate new private key**.
6. Confirm in the dialog and download the JSON file.
7. Rename it to `serviceAccountKey.json`.
8. Place it inside this `scripts/` folder:

   ```
   SpeedType/
   └── scripts/
       ├── serviceAccountKey.json   <-- HERE
       ├── upload_daily_challenges.js
       ├── package.json
       └── README.md
   ```

> **IMPORTANT:** Never commit `serviceAccountKey.json` to git. It grants admin
> access to your Firebase project. Make sure it is listed in `.gitignore`.

### 2. Install dependencies

From the `scripts/` directory:

```bash
cd scripts
npm install
```

## Scripts

### upload_daily_challenges.js

Uploads daily challenge texts from `assets/texts/daily_<lang>_<level>.json` into
Firestore. Iterates all 5 languages (`en`, `es`, `fr`, `de`, `it`) and all 5
levels (`beginner`, `easy`, `medium`, `hard`, `expert`).

- Uses batched writes (max 500 operations per batch).
- Idempotent: skips documents that already exist unless `--overwrite` is passed.
- Default start date: **2026-01-01** (UTC). Item `i` in each file becomes the
  text for `startDate + i days`.

**Firestore layout:**

```
dailyChallenges/{lang}_{level}
  └── days/{YYYY-MM-DD}
        { text, lang, level, date, index, source?, author?, createdAt }
```

**Run:**

```bash
node upload_daily_challenges.js
```

Or in one shot from the `scripts/` directory:

```bash
npm install && node upload_daily_challenges.js
```

**Optional flags:**

| Flag                  | Description                                               |
| --------------------- | --------------------------------------------------------- |
| `--dry-run`           | Print what would be written without contacting Firestore. |
| `--overwrite`         | Overwrite existing documents instead of skipping.         |
| `--start=YYYY-MM-DD`  | Override the start date (default `2026-01-01`).           |

Examples:

```bash
# Preview first without writing anything
node upload_daily_challenges.js --dry-run

# Re-upload and overwrite all existing days
node upload_daily_challenges.js --overwrite

# Start on a different date
node upload_daily_challenges.js --start=2026-06-01
```

## Troubleshooting

- **`Missing service account key`** — Ensure `serviceAccountKey.json` is placed
  inside the `scripts/` directory (not the repo root).
- **`PERMISSION_DENIED`** — The service account needs Firestore write access.
  In the Firebase Console, grant the `Cloud Datastore User` or
  `Firebase Admin` role.
- **Empty/missing JSON files** — The script logs a warning for any missing or
  malformed `daily_<lang>_<level>.json` file and continues with the rest.
