# SpeedType Demo - Schnellstart

Diese Anleitung zeigt dir, wie du die App **in unter 5 Minuten** lokal siehst -
ohne Firebase, AdMob, RevenueCat oder sonstige externen Dienste einrichten zu müssen.

---

## Voraussetzungen

- **Flutter SDK 3.0+** installiert
  → https://docs.flutter.dev/get-started/install
- **Chrome** (kommt mit fast allen Systemen)
- Das Repo geklont und in VS Code offen

## Flutter Doctor Check

```bash
flutter doctor
```

Du brauchst mindestens:
- ✅ Flutter
- ✅ Chrome (für Web-Preview) ODER
- ✅ Android Studio + Emulator ODER
- ✅ Xcode (Mac only, für iOS)

---

## Schritt 1: Dependencies installieren

```bash
cd SpeedType
flutter pub get
```

Das lädt alle Packages aus `pubspec.yaml` (ca. 60 Sekunden).

## Schritt 2: Demo im Browser starten (einfachster Weg)

```bash
flutter run -t lib/main_demo.dart -d chrome
```

- `-t lib/main_demo.dart` → startet den Demo-Einstiegspunkt (ohne Firebase)
- `-d chrome` → rendert in Chrome als Web-App

Nach 10-30 Sekunden öffnet sich Chrome und zeigt die App.
Du siehst zuerst den **Onboarding-Screen** mit der Sprachauswahl.

### Alternative: Android Emulator

```bash
flutter emulators --launch <emulator_id>
flutter run -t lib/main_demo.dart
```

### Alternative: Desktop (Mac/Linux/Windows)

```bash
flutter config --enable-macos-desktop  # oder linux/windows
flutter run -t lib/main_demo.dart -d macos
```

---

## Was funktioniert im Demo-Mode

✅ **Onboarding Screen** - Sprache wählen, animierte Cards
✅ **Home Screen** - Daily Challenge Card, Quick Race Chips, Practice Grid
✅ **Typing Test Screen** - Voll funktional! Echtes Tippen, Live-WPM, Highlighting
✅ **Result Screen** - Animierte WPM-Zahl, Stats, Rank Card
✅ **Leaderboard Screen** - Sample Daten (Podium + Liste)
✅ **Profile Screen** - Mock Stats, Streak-Kalender, Achievements
✅ **Settings Screen** - Alle Toggles und Optionen
✅ **Login Screen** - UI only (Buttons tun nichts ohne Firebase)
✅ **5 Sprachen** - Texte werden aus `assets/texts/` geladen
✅ **Dark Theme**, alle Animationen, Navigation

## Was NICHT funktioniert im Demo-Mode

❌ **Leaderboard Upload** - Keine Firestore-Verbindung
❌ **Google / Apple Sign-In** - Kein Firebase Auth
❌ **Daily Challenge aus der Cloud** - Fällt auf lokale seeded-random zurück
❌ **AdMob Ads** - Werden als Platzhalter angezeigt
❌ **Premium / RevenueCat** - Immer "Free"
❌ **Push Notifications** - Nicht initialisiert
❌ **Crashlytics** - Keine Error-Reports

---

## Häufige Probleme

### Problem: `MissingPluginException` beim Start

**Ursache:** Firebase-Plugins können nicht initialisiert werden, obwohl main_demo.dart sie überspringt.

**Fix:** Manche Service-Singletons (z.B. `AuthService.instance`) versuchen Firebase zu initialisieren, sobald du sie anfasst. In `main_demo.dart` werden die Services nicht automatisch initialisiert - sie werden nur "lazy" geladen wenn ein Screen sie benutzt.

Falls doch ein Screen crasht, kommentiere die entsprechenden Service-Aufrufe temporär aus.

### Problem: `pub get` schlägt fehl

**Lösung:**
```bash
flutter clean
flutter pub get
```

### Problem: Web-Build dauert ewig

Das erste Mal kompiliert Flutter alle Assets und Dependencies - **das dauert 1-3 Minuten**. Danach ist es schnell.

### Problem: Chrome öffnet sich nicht

Versuche:
```bash
flutter run -t lib/main_demo.dart -d web-server --web-port 8080
```

Dann manuell http://localhost:8080 im Browser öffnen.

### Problem: Hot Reload funktioniert nicht

Drücke `r` im Terminal wo `flutter run` läuft.
Oder `R` für Hot Restart.
Oder `q` zum Beenden.

---

## Der richtige "Full-App" Start (wenn Firebase eingerichtet ist)

Sobald du Schritt 1-4 aus dem Entwicklungsplan erledigt hast (Firebase Projekt,
google-services.json, GoogleService-Info.plist):

```bash
flutter run  # nutzt automatisch lib/main.dart
```

Das ist der Produktions-Einstiegspunkt mit allem drum und dran.

---

## Debug Tipps

**Bottom Navigation ausprobieren:**
- Im Home Screen unten die 4 Tabs antippen
- Home / Daily / Leaderboard / Profile

**Typing Test testen:**
- Home Screen → "30s" Quick Race antippen
- Text erscheint, einfach losschreiben
- Live WPM + Accuracy ändern sich in Echtzeit
- Nach 30 Sekunden → Result Screen mit Animation

**Route manuell aufrufen:**
Wenn du in Chrome bist, kannst du auch direkt URLs eingeben:
- http://localhost:XXXXX/#/home
- http://localhost:XXXXX/#/test
- http://localhost:XXXXX/#/leaderboard
- http://localhost:XXXXX/#/profile
- http://localhost:XXXXX/#/settings

---

## Feedback-Loop

Da du VS Code + Pixel Agents hast, kannst du parallel:
1. VS Code Editor zum Code ändern
2. `flutter run` mit Hot Reload (drück `r` nach jeder Änderung)
3. Claude Code im VS Code Terminal für neue Features
4. Pixel Agents visualisiert was Claude gerade macht

🎮 Viel Spaß mit SpeedType!
