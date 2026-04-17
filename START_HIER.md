# 🚀 Start hier

**Für dich, der User - 30 Sekunden zum Loslegen.**

## Der 1-Zeilen-Setup (Mac / Linux / WSL)

Terminal öffnen, diese eine Zeile kopieren und Enter drücken:

```bash
curl -fsSL https://raw.githubusercontent.com/podbihis-sys/SpeedType/claude/cloud-storage-setup-RQZAO/scripts/setup-local.sh | bash
```

Das macht automatisch:
- ✅ Node.js checken
- ✅ Claude Code CLI installieren (falls nicht da)
- ✅ Flutter checken (optional)
- ✅ Repo klonen
- ✅ Branch wechseln
- ✅ `flutter pub get` laufen lassen (falls Flutter da)
- ✅ Sagt dir am Ende: "Tippe `claude`"

---

## Windows PowerShell Variante

PowerShell hat kein `curl | bash`, stattdessen **manuell in 4 Zeilen**:

```powershell
# 1. Claude Code CLI installieren (einmalig)
npm install -g @anthropic-ai/claude-code

# 2. Repo klonen
git clone https://github.com/podbihis-sys/SpeedType.git
cd SpeedType
git checkout claude/cloud-storage-setup-RQZAO

# 3. Flutter deps holen (optional, braucht Flutter SDK)
flutter pub get

# 4. Claude starten
claude
```

---

## Nach dem Start: Was du Claude sagen kannst

Sobald `claude` läuft und die Prompt `>` erscheint, sag einfach:

```
Bitte lies HANDOVER.md und starte dann die App im Demo-Modus.
```

Claude wird dann:
1. HANDOVER.md lesen → weiß sofort was Sache ist
2. Eventuelle Flutter-Version-Fehler beheben
3. `flutter run -t lib/main_demo.dart -d chrome` starten
4. Chrome öffnet sich → du siehst die App

Wenn Fehler kommen, einfach sagen "fix das" - Claude macht den Rest.

---

## Was wenn ich Flutter nicht installiert habe?

Dann sag Claude:

```
Bitte hilf mir Flutter für mein Betriebssystem zu installieren.
```

Claude guidet dich durch den Installer (ist eigentlich nur ein Download + PATH setzen).

---

## Die 3 Dinge die du wissen musst

### 1. Demo-Modus vs. Produktions-Modus
- `flutter run -t lib/main_demo.dart -d chrome` → **Demo** (ohne Firebase, funktioniert sofort)
- `flutter run` → **Produktion** (braucht Firebase Config, siehe HANDOVER.md)

Fang mit Demo an.

### 2. Hot Reload
Während die App läuft: Code ändern, `r` im Terminal drücken → UI aktualisiert sich sofort.
Für kompletten Restart: `R` drücken.

### 3. Branch
Du arbeitest auf `claude/cloud-storage-setup-RQZAO`.
Commits gehen dorthin. Nicht auf `main` pushen ohne Nachfrage.

---

## Troubleshooting Quick-Referenz

| Problem | Fix (sag es einfach Claude) |
|---|---|
| `Build failed: Android v1 embedding` | "Führe `flutter create .` aus" |
| `pub get: version solving failed` | "Fix die pubspec Versionen" |
| `MissingPluginException` beim Start | "Ich nutze main_demo.dart, nicht main.dart" |
| Chrome öffnet sich nicht | "Nutze web-server statt chrome" |
| `flutter: command not found` | "Hilf mir Flutter zu installieren" |

---

## Was ist alles schon fertig im Repo?

- ✅ Komplette Flutter-App-Struktur mit 9 Screens
- ✅ Echte Typing-Engine mit Live-WPM, Highlighting, Consistency
- ✅ 60 JSON-Dateien mit Typing-Texten (5 Sprachen × 5 Level)
- ✅ Firebase Services (Auth, Firestore, Cloud Function für Anti-Cheat)
- ✅ AdMob + RevenueCat Integration
- ✅ Scorecard-Generator, Share, Push Notifications
- ✅ GitHub Actions CI/CD für Web + APK Builds
- ✅ ASO Store Listings in 5 Sprachen
- ✅ Marketing Plan (TikTok + Reddit)
- ✅ Privacy Policy + Terms (GDPR + CCPA konform)

Details in `HANDOVER.md`.

## Viel Erfolg! 🔥

Bei Problemen: Einfach Claude fragen, der weiß Bescheid.
