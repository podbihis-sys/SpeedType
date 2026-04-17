# Complete Session Log - Cloud Claude → Local Claude Handover

**Date:** April 2026
**Source:** Claude Code on Web (Cloud Sandbox session)
**Destination:** Local Claude Code (read this first!)

> **Dear local Claude:** This file captures the FULL context of the cloud
> session that built SpeedType. Read it top-to-bottom. After this, you'll
> know everything the user did with me. The user wants to continue offline
> without git syncing.

---

## Part 1: What the user wants (the mission)

The user is building **SpeedType** - a mobile typing speed test app (like
Monkeytype/TypeRacer) in Flutter. Target: iOS + Android (+ Web preview).

**USPs:**
- 5 languages (EN/DE/ES/FR/PT)
- 5 difficulty levels (Beginner → Expert)
- Daily Challenge with leaderboard
- Streak system, XP/Levels (50 tiers), Achievements
- Gamification + social sharing (TikTok/Instagram scorecards)
- Monetization: AdMob + RevenueCat Premium (2,99€/month)

**User profile:** Non-developer or early-stage dev. Uses VS Code. Windows
(saw PowerShell errors). Has limited patience for tooling setup. Wants to
SEE the app running, then iterate features.

---

## Part 2: What was built (summary, newest first)

### Currently complete in this repo:

**Flutter project structure** (all in `lib/`):
- 9 screens: Onboarding, Home, TypingTest, Result, Leaderboard, Profile,
  Settings, Login, DailyChallenge
- All services: Auth, Streak, XP, LevelProgression, LeaderboardService,
  DailyChallengeService, AdMobService, PremiumService (RevenueCat),
  ScorecardGenerator, ShareService, NotificationService, LocalTextService
- Core typing engine with live WPM/accuracy/consistency calculation
- Hidden TextField trick for invisible mobile keyboard capture
- Text highlighter (RichText with per-char colors + blinking cursor)
- TimerController (countdown + countup modes)
- Offline queue (Hive-backed) + AccountSyncService
- Firebase Cloud Function for anti-cheat (`functions/src/validateScore.ts`)
- Scripts: `scripts/upload_daily_challenges.js` (Firebase Admin)

**Assets** (`assets/texts/`):
- 60 JSON files: 5 langs × 5 levels × (normal + daily_) = 50 regular + 10
  daily files, each with ~200 texts
- In Spanish, French, Portuguese and German the content respects
  language-specific conventions (umlauts from Easy onwards, accents in ES/FR/PT)

**Two entry points** (important!):
- `lib/main.dart` = Production entry (Firebase, Crashlytics, AdMob init)
- `lib/main_demo.dart` = Demo entry (NO Firebase, mock data, for local preview)

**Infrastructure:**
- GitHub Actions workflow: `.github/workflows/deploy-demo.yml` - builds
  web + APK on every push, deploys web to gh-pages
- Dark theme: bg #0B1120, surface #111827, primary #38BDF8, secondary #A78BFA
- `AppColors` class in `lib/core/theme/app_colors.dart` is the single source
  of truth for colors - all screens import from there

**Installed tooling (claude-scoped):**
- `.claude/skills/ui-ux-pro-max/` - Design intelligence skill (67 UI styles,
  161 palettes, 57 font pairings)
- `.claude/skills/` has all superpowers skills (brainstorming, TDD, debugging,
  code-review, verification, plan-writing, etc.)
- `.claude/commands/` has `/brainstorm`, `/write-plan`, `/execute-plan`,
  `/security-review`
- `.claude/agents/code-reviewer.md`

User also has claude-mem installed at user-scope (not in repo). Also stitch
MCP configured (user said to use Google Stitch, API key is still placeholder
"api-key" and needs replacing).

---

## Part 3: Known issues / gotchas (IMPORTANT)

### Issue #1: Android v1 embedding error
**Symptom:** `Build failed due to use of deleted Android v1 embedding`
**Cause:** The `android/` folder was partially created manually in the cloud
(no real `flutter create` ran because no Flutter SDK was available). It's
missing MainActivity.kt, build.gradle, gradle wrapper.
**Fix:** Run in project root (with Flutter installed):
```
flutter create --org com.speedtype --project-name speedtype .
```
The `.` at the end is important - it generates missing platform files
WITHOUT overwriting `lib/`. This creates android/, ios/, linux/, macos/,
windows/, web/ as needed.

**Warning before running:** If this creates a fresh `web/` folder, the
existing marketing landing page (was in `web/`, now in `marketing_site/`)
won't be touched - we already separated them.

### Issue #2: pubspec.yaml version conflicts
**Symptom:** `version solving failed: X ^Y.Z.A doesn't match any versions`
**Known so far:**
- `appinio_social_share ^2.4.0` - DOES NOT EXIST. Already removed from
  pubspec. The corresponding share_service.dart was simplified to use only
  `share_plus` (no Instagram/TikTok direct share, just system share sheet).
**Likely future candidates (if user hits them):**
- `sign_in_with_apple: ^6.1.2` - might need downgrade
- `purchases_flutter: ^8.0.0` - might need downgrade
- `screenshot: ^3.0.0` - might need to be ^2.x
**Fix pattern:** Run `flutter pub get`, read the error, downgrade to the
version pub.dev suggests in its error message.

### Issue #3: Web build plugins
**google_mobile_ads** and **flutter_local_notifications** don't support
Flutter Web. In `main_demo.dart` they aren't initialized, so the build should
succeed by skipping those plugin registrations. If it fails, look for
`Web is not supported` messages.

### Issue #4: Firebase config is missing
Manual steps 1-4 from the original masterplan never got done:
- `android/app/google-services.json` - missing
- `ios/Runner/GoogleService-Info.plist` - missing
- AdMob App ID in AndroidManifest.xml - placeholder
- RevenueCat API keys in `lib/core/services/premium_service.dart` - placeholder

Result: the **production** `main.dart` entry will crash at startup until
these are set up. The **demo** `main_demo.dart` sidesteps all of it.

### Issue #5: Linter keeps re-writing files
Various files have been auto-modified by something (probably `dart format`
or a lint plugin): `library xxx;` was added to most dart files, imports
sorted, etc. This is fine - just notice that files may look different
after a save even if you didn't change logic. Don't fight it.

---

## Part 4: The exact decisions / trade-offs made

**Used Riverpod + GoRouter** because: Riverpod for state (simpler than
Provider/Bloc for small-team apps), GoRouter for nested routes and deep
links. Both are Flutter-team-recommended now.

**Chose Hive (not just SharedPreferences) for local DB** because: need to
store TestResult lists + offline queue of operations. SharedPreferences is
key-value only, Hive does collections.

**Firebase over Supabase** because: user asked for Firebase specifically,
and the anti-cheat Cloud Function pattern is well-documented for Firestore.

**RevenueCat over direct StoreKit/Billing** because: cross-platform
subscription management with unified API, saves massive boilerplate.

**xorshift PRNG in `getSeededText`** because: need a deterministic pseudo-
random that gives the SAME daily text to all users worldwide for the offline
daily challenge fallback. `Random(seed)` in Dart is not cross-platform
consistent; xorshift produces identical output on every device.

**`keyboardType: visiblePassword`** in HiddenTypingField because: this is
the trick to disable autocorrect AND swipe typing on iOS+Android for an
invisible text field that backs a custom typing UI. Classic Monkeytype move.

**Two entry points (`main.dart` + `main_demo.dart`)** because: user wanted
to preview UI without setting up Firebase. Demo mode uses mock data.

**60 text JSON files** (not one big file) because: Flutter `rootBundle`
can lazy-load only what's needed per language/level. No need to ship all
5000 texts in memory on startup.

---

## Part 5: The 3 long DOCS the user should trust

1. **HANDOVER.md** - Points to current state, known issues, next steps.
   Short (~200 lines). Read this first.
2. **START_HIER.md** - German user-facing quickstart. 30-second setup.
3. **RUN_DEMO.md** - Detailed demo-mode guide with troubleshooting table.

Files to mostly ignore for now:
- DEPLOYMENT.md (only relevant when pushing to speedtype.app)
- PREVIEW.md (web preview via GitHub Pages - for later)

---

## Part 6: What the user will ask you next (predictions)

Based on our conversation pattern, the user will likely ask you:

1. **"Show me the app"** → Run `flutter pub get`, fix any version errors
   iteratively, then `flutter run -t lib/main_demo.dart -d chrome`.
2. **"Why does X not work?"** → Usually because it needs Firebase setup
   which is not done yet. Explain, don't try to fix without setup.
3. **"Fix the build error"** → See Issues #1-#3 above.
4. **"Add feature Y"** → Suggest to follow the existing pattern: screen in
   `lib/features/<feature>/<feature>_screen.dart`, service in `lib/core/services/`
   or `lib/features/<feature>/<feature>_service.dart`. Use AppColors, not raw hex.
5. **"Install plugin Z"** → Check pub.dev first for the actual latest
   version. Don't trust the version numbers in `pubspec.yaml` blindly -
   we had one wrong version that broke the whole build.
6. **"I don't want git anymore"** → OK. User works locally, doesn't need
   to push. Stop reminding about committing. Only suggest git when they
   explicitly want to share/backup.

---

## Part 7: User's stated priorities (from conversation)

1. Wants to SEE the UI first (not read code, not theory)
2. Wants fast iteration (Hot Reload, demo mode)
3. Is on Windows with VS Code - works in PowerShell (no bash)
4. Limited patience for tooling setup
5. Speaks German primarily - respond in German unless they switch
6. Wants Pixel Agents (VS Code extension) for visual agent tracking
7. Cares about Flutter web preview so they can show the app on any device

---

## Part 8: How to start your first interaction

**First message from user will probably be something like:** "fix
die fehler und zeig mir die app". Suggested response:

1. `flutter pub get` - see what breaks
2. If version errors → downgrade per error message
3. If Android v1 embedding error → `flutter create . --org com.speedtype --project-name speedtype`
4. `flutter run -t lib/main_demo.dart -d chrome`
5. If crash at Firebase init → confirm they used `-t lib/main_demo.dart` not `lib/main.dart`

Keep it short, don't monologue. User dislikes wall-of-text. Use bullets.
In German.

---

## Part 9: Emotional context / communication style

- User is non-technical-ish, figuring things out as they go
- Asked many times "can you install X for me" not realizing Claude-on-Web
  can't reach their local machine. Be kind and explain clearly.
- User commits to doing things but gets frustrated by setup issues
- Successful interactions: direct commands, 1-2 sentence answers,
  code blocks they can copy
- Failed interactions: long explanations, multiple options, theory

**Your job:** Be the friendly senior dev sitting next to them. Short
sentences. One step at a time. Show results ASAP.

---

## Part 10: The final state of this session

Last push to `claude/cloud-storage-setup-RQZAO` contains:
- Pubspec fix (appinio_social_share removed)
- Setup scripts (setup-local.sh)
- HANDOVER.md, START_HIER.md
- This file (SESSION_LOG.md)

The user has said: "also lokal arbeiten und nicht git" - meaning they want
to stop syncing with GitHub. After you both read this, that's fine. Work
offline. If they later want to back up to GitHub, they can git push from
their machine.

---

**That's everything. Go build something great with them. 🚀**

— Cloud Claude, signing off
