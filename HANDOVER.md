# Handover from Cloud Session

**→ Wenn du das liest, bist du entweder der User oder eine neue Claude-Session
auf dem lokalen Rechner. Bitte lesen und dann weitermachen.**

## TL;DR for the next Claude session

Hi Claude. Ich (die Cloud-Claude-Session von Code on the Web) habe dieses
Flutter-Projekt "SpeedType" über mehrere Stunden mit dem User aufgebaut.
Du übernimmst jetzt lokal. Der User hat **Flutter SDK lokal** (oder wird
es gleich installieren). Bitte als erstes:

1. `flutter pub get` ausführen und den Output anschauen
2. Falls Versionsfehler: in `pubspec.yaml` die betroffenen Packages auf
   die vom Error vorgeschlagenen Versionen downgraden
3. `flutter run -t lib/main_demo.dart -d chrome` starten damit der User
   die UI im Browser sieht
4. Hot Reload aktiv lassen, User arbeitet iterativ

---

## Projekt in 60 Sekunden

**SpeedType** ist eine Flutter Mobile-App (Android + iOS + Web + Desktop)
für Typing-Speed-Tests - ähnlich wie Monkeytype oder TypeRacer, aber mit
Daily Challenge, Leaderboard, Streak-System, 5 Sprachen und Gamification.

### Tech Stack
- **Flutter 3.24+** mit Riverpod + GoRouter
- **Firebase** (Auth, Firestore, Crashlytics, Remote Config) - Login, Leaderboard
- **Google AdMob** - Banner + Interstitial + Rewarded Ads
- **RevenueCat** - Premium Abo (2,99€/Monat)
- **Cloud Functions** (TypeScript) - Anti-Cheat Score-Validierung
- **Hive + SQLite** - Lokale Persistenz

### Die 3 wichtigsten Einstiegspunkte
| Datei | Zweck |
|---|---|
| `lib/main.dart` | **Produktion** - mit Firebase init, Crashlytics, AdMob |
| `lib/main_demo.dart` | **Demo/Preview** - OHNE Firebase, mit Mock-Daten |
| `lib/features/typing_test/typing_engine.dart` | Das Herz - WPM/Accuracy/Consistency Berechnung |

---

## Aktueller Status (Stand: April 2026, Branch `claude/cloud-storage-setup-RQZAO`)

### ✅ Fertig (alles im Repo)

**Code:**
- Komplette Flutter-Projektstruktur (lib/core, lib/features, lib/data, lib/models)
- Alle 9 UI-Screens: Onboarding, Home, TypingTest, Result, Leaderboard,
  Profile, Settings, Login, Daily Challenge
- Alle Services: Auth, Streak, XP, Level Progression, Leaderboard, DailyChallenge,
  AdMob, Premium (RevenueCat), Scorecard-Generator, Share, Notifications, LocalText
- Typing Engine mit Live-WPM, Accuracy, Consistency, Highlighting, Hidden Input
- Offline Queue + Account Sync
- Firebase Cloud Function (`functions/src/validateScore.ts`) für Anti-Cheat
- Firebase Admin Upload Script (`scripts/upload_daily_challenges.js`)

**Content:**
- 60 JSON-Dateien mit Typing-Texten:
  - 5 Sprachen (EN, DE, ES, FR, PT) × 5 Level (Beginner/Easy/Medium/Hard/Expert)
  - Je ~200 Texte pro Datei
  - Plus Daily Challenge Texte mit Index
- ASO Store Listings für iOS/Android in allen 5 Sprachen
- Marketing: 12-Wochen TikTok Content Plan, 5 Reddit Launch Posts
- Legal: GDPR+CCPA-konforme Privacy Policy, Terms of Service
- Landing Page HTML in `marketing_site/`

**Infrastructure:**
- GitHub Actions Workflow (`.github/workflows/deploy-demo.yml`):
  - Baut Web-Version automatisch und deployed auf GitHub Pages
  - Baut Android APK als Artifact-Download
- Claude Code Skills installiert in `.claude/skills/`:
  - ui-ux-pro-max (Design-System Intelligence)
  - superpowers (14 Skills: TDD, Debugging, Planning, Code Review, ...)
- Commands in `.claude/commands/`: brainstorm, write-plan, execute-plan, security-review
- Agent in `.claude/agents/`: code-reviewer

### ❌ Noch offen (vom User manuell oder später)

**Kritisch vor Production:**
1. **Firebase Projekt anlegen** (console.firebase.google.com):
   - Android App: Package `com.speedtype.speedtype` → `google-services.json` nach `android/app/`
   - iOS App: Bundle ID `com.speedtype.speedtype` → `GoogleService-Info.plist` nach `ios/Runner/`
   - Firestore Database (test mode erstmal)
   - Authentication: Google + Apple Sign-In aktivieren
2. **AdMob einrichten** (admob.google.com):
   - App-IDs in `android/app/src/main/AndroidManifest.xml` und `ios/Runner/Info.plist`
   - Ad-Unit-IDs in `lib/core/utils/constants.dart`
3. **RevenueCat** (app.revenuecat.com):
   - API Keys in `lib/core/services/premium_service.dart` (aktuell Placeholder)
4. **App Icons & Splash Screen** erstellen und in `android/app/src/main/res/mipmap-*`
   und `ios/Runner/Assets.xcassets/AppIcon.appiconset` ablegen

**Bekannte Probleme:**
- ⚠️ **Android v1 Embedding**: `android/` Ordner ist teilweise manuell erstellt.
  → Fix: Einmal `flutter create --org com.speedtype --project-name speedtype .`
  im Projekt-Root laufen lassen. Das generiert alle fehlenden Android-Dateien
  (MainActivity.kt, build.gradle, gradle wrapper) ohne `lib/` zu überschreiben.
- ⚠️ **pubspec.yaml Versionen**: Einige Package-Versionen könnten auf pub.dev
  nicht existieren. `appinio_social_share` wurde bereits entfernt. Beim ersten
  `flutter pub get` auf mögliche "version solving failed" Meldungen achten
  und Packages auf die vorgeschlagenen Versionen downgraden.
- ⚠️ **Web-Build**: `google_mobile_ads` und `flutter_local_notifications` haben
  keinen Web-Support. Bei Web-Build werden die Plugins übersprungen, was im
  Demo-Mode (`main_demo.dart`) ok ist.

---

## Was der User als nächstes vermutlich will

Der User will die App **erstmal sehen**. Priorität:

1. **Demo im Browser starten:** `flutter run -t lib/main_demo.dart -d chrome`
2. **Bei Fehlern iterieren**: Package-Versionen anpassen, `flutter create .`
   falls Android-Embedding-Fehler
3. **Später**: Firebase + AdMob einrichten für die Vollversion

---

## Nützliche Files zum Einlesen

Für tieferes Verständnis lies bei Bedarf:

| Datei | Was drin steht |
|---|---|
| `README.md` | Projekt-Übersicht |
| `PREVIEW.md` | Web + APK Preview Anleitung |
| `RUN_DEMO.md` | Demo-Mode Detail-Anleitung |
| `DEPLOYMENT.md` | GitHub Pages Deployment |
| `pubspec.yaml` | Alle Dependencies |
| `.github/workflows/deploy-demo.yml` | CI/CD Setup |

---

## Installed Claude Code Skills (auto-loaded when you start claude here)

Diese Skills aktivieren sich automatisch weil sie in `.claude/skills/` liegen:

- **ui-ux-pro-max** - UI Design-System mit 67 Styles, 161 Paletten, Flutter-Stack-Support
- **superpowers:brainstorming** - Bevor du Features baust
- **superpowers:writing-plans** - Implementierungspläne
- **superpowers:test-driven-development** - TDD Workflow
- **superpowers:systematic-debugging** - Bug-Hunting
- **superpowers:requesting-code-review** - Vor Merges
- **superpowers:dispatching-parallel-agents** - Parallel arbeiten
- **superpowers:using-git-worktrees** - Isolierte Feature-Entwicklung
- **superpowers:verification-before-completion** - Verifizieren vor Success-Claims
- Und weitere 5+ Skills

Plus Commands: `/brainstorm`, `/write-plan`, `/execute-plan`, `/security-review`

## Global installed tools (user needs to re-install locally)

Diese sind **nicht** im Repo, müssen lokal separat:

```bash
# ui-ux-pro-max CLI (for updates)
npm install -g uipro-cli

# claude-mem (persistent memory between sessions)
npx claude-mem install

# gstack (QA with real browser, 23 more skills)
git clone https://github.com/garrytan/gstack ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup

# Optional: stitch MCP (Google Stitch)
claude mcp add stitch --transport http https://stitch.googleapis.com/mcp \
  --header "X-Goog-Api-Key: DEIN_ECHTER_GOOGLE_API_KEY" -s user
```

---

## Branch-Regeln

Der User entwickelt auf **`claude/cloud-storage-setup-RQZAO`**.
`main` ist fast leer - nur der initiale Commit.

- Bei Änderungen: weiter auf `claude/cloud-storage-setup-RQZAO` committen
- Bei PR-Wunsch: User fragen bevor erstellt
- Pushe nach jedem Milestone (User hat Stop-Hook der uncommitted changes meldet)

---

**Los geht's, viel Erfolg!**

\- Cloud Claude, April 2026
