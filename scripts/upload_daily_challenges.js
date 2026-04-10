#!/usr/bin/env node
/**
 * upload_daily_challenges.js
 *
 * Uploads daily challenge texts from local JSON files to Firestore.
 *
 * Expected input files (relative to repo root):
 *   ../assets/texts/daily_<lang>_<level>.json
 *
 * Each file is either:
 *   - an array of strings, or
 *   - an array of objects like { "text": "...", "source": "...", "author": "..." }
 *
 * Firestore layout:
 *   dailyChallenges/{lang}_{level}/days/{YYYY-MM-DD}
 *     { text, lang, level, date, index, source?, author?, createdAt }
 *
 * Run:
 *   npm install
 *   node upload_daily_challenges.js
 *
 * Optional flags:
 *   --dry-run      Print what would happen, don't write to Firestore
 *   --overwrite    Overwrite existing documents (default: skip if exists)
 *   --start=YYYY-MM-DD  Override start date (default 2026-01-01)
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// ---------- Configuration ----------

const LANGS = ['en', 'es', 'fr', 'de', 'it'];
const LEVELS = ['beginner', 'easy', 'medium', 'hard', 'expert'];
const DEFAULT_START_DATE = '2026-01-01';
const BATCH_LIMIT = 500; // Firestore hard limit per batch

const ASSETS_DIR = path.resolve(__dirname, '..', 'assets', 'texts');
const SERVICE_ACCOUNT_PATH = path.resolve(__dirname, 'serviceAccountKey.json');

// ---------- CLI arg parsing ----------

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const OVERWRITE = args.includes('--overwrite');
const startArg = args.find((a) => a.startsWith('--start='));
const START_DATE = startArg ? startArg.split('=')[1] : DEFAULT_START_DATE;

// ---------- Helpers ----------

function log(...m) {
  console.log('[upload]', ...m);
}
function warn(...m) {
  console.warn('[upload:warn]', ...m);
}
function err(...m) {
  console.error('[upload:error]', ...m);
}

function formatDate(d) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function addDays(date, days) {
  const d = new Date(date.getTime());
  d.setUTCDate(d.getUTCDate() + days);
  return d;
}

function loadJsonFile(filePath) {
  if (!fs.existsSync(filePath)) return null;
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      warn(`File ${filePath} is not an array. Skipping.`);
      return null;
    }
    return parsed;
  } catch (e) {
    err(`Failed to parse ${filePath}:`, e.message);
    return null;
  }
}

function normalizeItem(item, index, lang, level, dateStr) {
  if (typeof item === 'string') {
    return {
      text: item,
      lang,
      level,
      date: dateStr,
      index,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  }
  if (item && typeof item === 'object' && typeof item.text === 'string') {
    const base = {
      text: item.text,
      lang,
      level,
      date: dateStr,
      index,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (item.source) base.source = item.source;
    if (item.author) base.author = item.author;
    if (item.title) base.title = item.title;
    return base;
  }
  return null;
}

// ---------- Firebase init ----------

function initFirebase() {
  if (DRY_RUN) {
    log('DRY RUN mode - Firestore will not be contacted.');
    return null;
  }
  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    err(
      `Missing service account key at ${SERVICE_ACCOUNT_PATH}.\n` +
        'Download it from Firebase Console > Project Settings > Service Accounts > Generate new private key, ' +
        'and save it as scripts/serviceAccountKey.json.'
    );
    process.exit(1);
  }
  const serviceAccount = require(SERVICE_ACCOUNT_PATH);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return admin.firestore();
}

// ---------- Batch uploader ----------

class BatchedWriter {
  constructor(db) {
    this.db = db;
    this.batch = db ? db.batch() : null;
    this.ops = 0;
    this.totalWritten = 0;
    this.totalSkipped = 0;
  }

  async set(ref, data) {
    if (!this.db) {
      this.totalWritten += 1;
      return;
    }
    this.batch.set(ref, data, { merge: false });
    this.ops += 1;
    if (this.ops >= BATCH_LIMIT) {
      await this.flush();
    }
  }

  async flush() {
    if (!this.db || this.ops === 0) return;
    try {
      await this.batch.commit();
      this.totalWritten += this.ops;
      log(`Committed batch of ${this.ops} writes (total: ${this.totalWritten}).`);
    } catch (e) {
      err('Batch commit failed:', e.message);
      throw e;
    } finally {
      this.batch = this.db.batch();
      this.ops = 0;
    }
  }
}

// ---------- Existence check (idempotent) ----------

async function docExists(db, ref) {
  if (!db) return false;
  try {
    const snap = await ref.get();
    return snap.exists;
  } catch (e) {
    warn(`Existence check failed for ${ref.path}:`, e.message);
    return false;
  }
}

// ---------- Main per-file processing ----------

async function processFile(db, writer, lang, level, startDate) {
  const fileName = `daily_${lang}_${level}.json`;
  const filePath = path.join(ASSETS_DIR, fileName);
  const items = loadJsonFile(filePath);

  if (!items) {
    warn(`Skipping ${fileName} (missing or invalid).`);
    return { written: 0, skipped: 0, missing: true };
  }
  if (items.length === 0) {
    warn(`Skipping ${fileName} (empty array).`);
    return { written: 0, skipped: 0, missing: false };
  }

  const collectionId = `${lang}_${level}`;
  const parentDoc = db ? db.collection('dailyChallenges').doc(collectionId) : null;
  const daysCol = parentDoc ? parentDoc.collection('days') : null;

  let written = 0;
  let skipped = 0;

  for (let i = 0; i < items.length; i++) {
    const date = addDays(startDate, i);
    const dateStr = formatDate(date);
    const normalized = normalizeItem(items[i], i, lang, level, dateStr);
    if (!normalized) {
      warn(`  [${fileName}] Item at index ${i} is invalid. Skipping.`);
      continue;
    }

    if (db) {
      const ref = daysCol.doc(dateStr);
      if (!OVERWRITE) {
        const exists = await docExists(db, ref);
        if (exists) {
          skipped += 1;
          writer.totalSkipped += 1;
          continue;
        }
      }
      await writer.set(ref, normalized);
      written += 1;
    } else {
      log(
        `  [DRY] ${collectionId}/days/${dateStr} idx=${i} text="${normalized.text.slice(0, 40)}..."`
      );
      written += 1;
    }
  }

  // Also upsert a parent metadata doc (not counted in batch because of frequency)
  if (db) {
    try {
      await parentDoc.set(
        {
          lang,
          level,
          startDate: formatDate(startDate),
          count: items.length,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (e) {
      warn(`Failed to update parent metadata for ${collectionId}:`, e.message);
    }
  }

  log(
    `Processed ${fileName}: ${items.length} items -> written=${written}, skipped=${skipped}`
  );
  return { written, skipped, missing: false };
}

// ---------- Entrypoint ----------

async function main() {
  log(`Start date: ${START_DATE}`);
  log(`Dry run: ${DRY_RUN}`);
  log(`Overwrite: ${OVERWRITE}`);
  log(`Assets dir: ${ASSETS_DIR}`);

  const startDate = new Date(`${START_DATE}T00:00:00Z`);
  if (Number.isNaN(startDate.getTime())) {
    err(`Invalid start date: ${START_DATE}`);
    process.exit(1);
  }

  const db = initFirebase();
  const writer = new BatchedWriter(db);

  const summary = [];
  let hadError = false;

  for (const lang of LANGS) {
    for (const level of LEVELS) {
      try {
        const res = await processFile(db, writer, lang, level, startDate);
        summary.push({ lang, level, ...res });
      } catch (e) {
        hadError = true;
        err(`Failed processing ${lang}/${level}:`, e.stack || e.message);
      }
    }
  }

  try {
    await writer.flush();
  } catch (e) {
    hadError = true;
    err('Final flush failed:', e.message);
  }

  // Summary
  log('---------- SUMMARY ----------');
  let totalWritten = 0;
  let totalSkipped = 0;
  let missingFiles = 0;
  for (const row of summary) {
    totalWritten += row.written;
    totalSkipped += row.skipped;
    if (row.missing) missingFiles += 1;
    log(
      ` ${row.lang}_${row.level}: written=${row.written}, skipped=${row.skipped}${
        row.missing ? ' (file missing)' : ''
      }`
    );
  }
  log(`Total written: ${totalWritten}`);
  log(`Total skipped (already existed): ${totalSkipped}`);
  log(`Missing files: ${missingFiles}`);
  log(`Errors: ${hadError ? 'YES' : 'none'}`);

  if (hadError) {
    process.exitCode = 1;
  }
}

main().catch((e) => {
  err('Fatal error:', e.stack || e.message);
  process.exit(1);
});
