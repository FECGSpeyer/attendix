# Changelog-Fragmente

Jeder PR legt hier **eine** Datei an statt die Version selbst zu erhöhen:

```json
// changelog/unreleased/<kurzer-name>.json
{"bump": "minor", "changes": ["✨ Neue Feature-Beschreibung"]}
```

- `bump`: `minor` (Feature) oder `patch` (Fix, Standard).
- `changes`: Zeilen für `assets/version_history.json`.

Nach dem Merge auf master fasst der Deploy-Workflow alle Fragmente zu einer
Version zusammen (`tool/release/release_version.py`), erhöht `pubspec.yaml`
und `AppConstants.appVersion`, schreibt den Eintrag in
`assets/version_history.json` und löscht die Fragmente.
