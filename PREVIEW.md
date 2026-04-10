# SpeedType - Online Preview

Siehe die App **ohne jegliche lokale Installation**. Du brauchst nur einen Browser.

## 🌐 Web-Version (funktioniert auf jedem Gerät)

Nach dem ersten erfolgreichen GitHub Actions Lauf ist die Demo hier erreichbar:

**https://podbihis-sys.github.io/SpeedType/**

### So aktivierst du GitHub Pages (einmalig, 30 Sekunden):

1. Gehe zu https://github.com/podbihis-sys/SpeedType/settings/pages
2. Unter **Source**: "Deploy from a branch" auswählen
3. Unter **Branch**: `gh-pages` und `/ (root)` auswählen
4. **Save** klicken

Nach ~2 Minuten ist die URL live. Bei jedem Push auf `claude/cloud-storage-setup-RQZAO`
wird die Demo automatisch neu deployed.

### Was funktioniert in der Web-Version?

✅ Alle Screens (Home, Typing Test, Results, Leaderboard, Profile, Settings)
✅ Echter Tippen-Modus mit Live-WPM, Farb-Highlighting, Cursor
✅ Alle Animationen (WPM Count-up, Onboarding Slide-in, etc.)
✅ 5 Sprachen, alle Texte aus `assets/texts/`
✅ Dark Theme, Streak-Kalender, Achievements
✅ PWA-installierbar (siehe unten)

❌ Firebase (Login, Leaderboard-Upload, Firestore) - Demo-Modus
❌ Echte AdMob Ads - nur Platzhalter
❌ Push Notifications (Web-Einschränkung)

## 📱 Als PWA auf dem Handy installieren

Nachdem GitHub Pages aktiv ist:

**Android (Chrome):**
1. URL in Chrome öffnen: `https://podbihis-sys.github.io/SpeedType/`
2. Menü (⋮) → "Zum Startbildschirm hinzufügen"
3. Icon erscheint wie eine native App

**iOS (Safari):**
1. URL in Safari öffnen
2. Teilen-Button → "Zum Home-Bildschirm"
3. Verhält sich wie eine native App

## 📲 Native Android APK

Der GitHub Actions Workflow baut auch eine **debug APK** die du direkt auf einem
echten Android-Handy oder in einem Emulator installieren kannst.

### Wo finde ich die APK?

1. Gehe zu https://github.com/podbihis-sys/SpeedType/actions
2. Klick auf den neuesten erfolgreichen "Build & Deploy Demo" Run
3. Scroll runter zu **Artifacts**
4. Lade `speedtype-debug-apk` herunter (ZIP)
5. Entpacke → `app-debug.apk`

### Auf einem echten Handy installieren

**Android:**
1. APK auf dein Handy übertragen (Email, USB, Google Drive, etc.)
2. Datei antippen
3. "Installation aus unbekannten Quellen erlauben" bestätigen
4. Installieren → öffnen

**In einem Android Emulator (falls du Android Studio hast):**
```bash
# Emulator starten
emulator -list-avds
emulator -avd <name>

# APK per adb installieren
adb install app-debug.apk
```

## 🖥️ Desktop-Version

Die Desktop-Version (macOS/Windows/Linux) wird aktuell **nicht** automatisch
gebaut. Falls du sie willst, sag Bescheid - ich ergänze den Workflow.

## 🎯 Was ist "Demo-Modus"?

Die Online-Preview nutzt `lib/main_demo.dart` statt `lib/main.dart`:
- Keine Firebase-Initialisierung → keine Crashs ohne Setup
- Hardcoded Mock-Daten (Streak 4, WPM 62, Sample Leaderboard, etc.)
- Echte Services sind vorhanden aber inaktiv

Sobald du Firebase lokal einrichtest (Schritte 1-4 im Masterplan) und
`lib/main.dart` verwendest, bekommst du die Produktions-App mit allem
drum und dran.

## 🔄 Workflow-Status checken

Aktuelle Build-Status:
https://github.com/podbihis-sys/SpeedType/actions/workflows/deploy-demo.yml

Der erste Run dauert ca. **5-8 Minuten** (Flutter Download + Build).
Danach nur noch ~3 Minuten pro Push.

## 🐛 Wenn der Build fehlschlägt

Schau in den Actions-Log:
1. https://github.com/podbihis-sys/SpeedType/actions
2. Klick auf den fehlgeschlagenen Run
3. Klick auf `web` oder `android` Job
4. Scroll zum roten ❌ Schritt

Häufige Probleme & Fixes:

| Fehler | Ursache | Fix |
|---|---|---|
| `google_mobile_ads` web-Build schlägt fehl | Kein Web-Support | Siehe Troubleshooting unten |
| APK Build dauert >30min | Gradle Download | Einfach abwarten, CI-Cache ist beim 2. Run schneller |
| GitHub Pages 404 | Pages noch nicht aktiviert | Siehe "So aktivierst du GitHub Pages" oben |

### Troubleshooting: google_mobile_ads verhindert Web-Build

Falls der Web-Build wegen `google_mobile_ads` fehlschlägt, gibt es zwei Optionen:

**Option 1:** Conditional import in admob_service.dart (komplexer)
**Option 2:** pubspec.yaml Plugin temporär auskommentieren (schneller)

Sag mir welche du willst, dann baue ich das ein.
