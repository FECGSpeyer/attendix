# Store-Wechsel 5.0.0: Ionic → Flutter (Runbook)

App-ID `io.stephanus.attendix` (iOS Team `MXM3YWAKPL`, Android-Paket gleich).
Flutter-Web läuft auf Cloudflare (`attendix-5eg.pages.dev`); `attendix.de`
bleibt bis zum DNS-Wechsel auf Vercel mit der Ionic-App.

Prüfskript für die Universal-Link-Dateien (AASA + assetlinks.json):

```bash
bash tool/release/check_well_known.sh build/web                       # lokal (läuft auch in CI)
bash tool/release/check_well_known.sh https://attendix-5eg.pages.dev  # remote
bash tool/release/check_well_known.sh --apple-cdn https://attendix.de https://www.attendix.de
```

## 1. Vor dem Release, nach dem TestFlight-Test (ohne Wirkung auf Ionic)

- [ ] Supabase-Mailvorlagen auf token_hash-Links umstellen:
  - „Reset Password“: `{{ .SiteURL }}/resetPassword?token_hash={{ .TokenHash }}&type=recovery`
  - „Confirm signup“: `{{ .SiteURL }}/resetPassword?token_hash={{ .TokenHash }}&type=signup`
  - Ionic 4.19.6 (`app.component.ts#handleAuthUrl`, seit 15.7.2026) und Flutter (`AuthLink`) verarbeiten beide.
  - Quertest: am Laptop anfordern, auf dem iPhone öffnen (und umgekehrt).
- [ ] Upload-Key-Reset in der Play Console beantragen (dauert 1–2 Tage).
- [ ] Ionic-Web auf Vercel zusätzlich unter einer Zweitadresse erreichbar machen (z. B. `ionic.attendix.de`).
- [ ] Ionic-Notfallbuild 5.0.1 fertig bauen (Xcode-Archive Team MXM3YWAKPL + AAB), **nicht hochladen**.
- [ ] `bash tool/release/check_well_known.sh https://attendix-5eg.pages.dev` ist grün.

## 2. Beim Release

- [ ] Store-Builds mit `shorebird release` bauen (siehe `docs/release/shorebird.md`).
- [ ] Versionsnummern: Android `versionCode` > 227, iOS-Build > 236.
- [ ] iOS: „Phasenweise Veröffentlichung“ einschalten.
- [ ] Android: gestaffelter Rollout 5 % → 20 % → 50 % → 100 %; vor jeder Stufe Absturzrate und Rückmeldungen prüfen.

## 3. DNS-Wechsel attendix.de → Cloudflare

- [ ] Alte DNS-Einträge (Vercel) notieren, damit ein Rückweg möglich ist.
- [ ] Vorher: `check_well_known.sh https://attendix-5eg.pages.dev` grün.
- [ ] DNS umstellen.
- [ ] Danach: `check_well_known.sh --apple-cdn https://attendix.de https://www.attendix.de`.
  Der Apple-CDN-Teil kann bis zu 24 h hinterherhinken; bis dahin ist ein Fehler dort normal.

## 4. Rollback

- [ ] Rollout anhalten: iOS phasenweise Veröffentlichung pausieren, Play-Rollout anhalten.
- [ ] Im Store gibt es kein Downgrade → Ionic-Notfallbuild 5.0.1 hochladen und beschleunigte Prüfung beantragen.
- [ ] Achtung: nach der Login-Übernahme ist die alte Ionic-Sitzung ungültig (Refresh-Token rotiert). Rollback heißt für Nutzer: neu anmelden.
- [ ] DNS zurück: attendix.de wieder auf Vercel (notierte Einträge). Die Ionic-AASA liegt dort in `src/.well-known/`.
- [ ] Danach `check_well_known.sh --apple-cdn https://attendix.de` erneut ausführen.

## 5. Nach dem Wechsel

- [ ] Ionic-Repo einfrieren (nur noch Notfall-Fixes).
- [ ] Backend einige Monate rückwärtskompatibel zu Ionic 4.19.x halten: nur Spalten hinzufügen, nichts umbenennen oder löschen.
- [ ] Letztes Ionic-OTA mit Hinweis „Bitte im Store aktualisieren“ ausrollen (braucht `ota-private.pem`).
