# Instrumentenauswahl: klarere Einstiege und sicherer Vorlagenwechsel

Der Nutzer hat die drei Empfehlungen der Szenarioprüfung am 26.11.2026 mit „passt“ angenommen. Bestehende Implementierung auf codex/instrument-catalog weiterentwickeln.

## Umfang und Entscheidung

Direkte Vorlagenauswahl nach der Ensembleart im Erstellungsformular, darunter die anpassbare Auswahl mit Vorlagenname und Anzahl. Später einrichten bleibt möglich. Sammlung und Material-3/Rd-Komponenten werden weiterverwendet; ein zusätzlicher Einrichtungswizard ist dafür unnötig. Die Verwaltung behält den kurzen Weg Plus → Sammlung.

Aktionen nennen ihren Zweck: Auswahl übernehmen im Setup; Anzahl Instrumente/Stimmen hinzufügen in der Verwaltung. Der Stift bei vorhandenen Katalogeinträgen heißt Weitere Stimme anlegen. Der widersprüchliche Hinweis zur späteren Instrumentanlage wird korrigiert.

Die gleiche Vorlage erneut wählen ist wirkungslos. Beim Wechsel mit vorhandener Auswahl werden Ergänzen, Ersetzen und Abbrechen angeboten. Ergänzen erhält eigene Einträge, Namen und Metadaten und fügt fehlende Standardentwürfe hinzu. Ersetzen darf erst nach ausdrücklicher Auswahl dieser Aktion zurücksetzen. Ohne Vorlage entfernt nur die Vorlagenzuordnung. Später einrichten im Formular verwirft eine vorhandene Auswahl erst nach Bestätigung. Diese Details sind Umsetzungsentscheidungen innerhalb der angenommenen Empfehlung.

## Schnittstellen

- CatalogPickerPurpose { setup, add }; Standard add.
- CatalogPickerResult mit List<CatalogGroupDraft> drafts und String? presetId. Die Auswahlansicht gibt diesen Wert oder null (Abbrechen) zurück.
- showInstrumentCatalogSheet erhält zusätzlich purpose und initialPresetId.
- CatalogPresetChange { merge, replace }; Future<CatalogPresetChange?> showCatalogPresetChangeDialog(BuildContext context). null bedeutet Abbrechen. In derselben Widgetdatei für Formular und Auswahlansicht wiederverwendbar.
- List<CatalogGroupDraft> mergeCatalogDrafts(List<CatalogGroupDraft> current, List<CatalogGroupDraft> additions) in catalog_selection.dart erhält gleiche Schlüssel und exakte Namens-/Synonymäquivalente; Violine I/II und verschiedene Flöten bleiben unterscheidbar. Keine destruktive Änderung vorhandener Entwürfe.

## Grenzen und Prüfung

Keine Änderung an Import, Tenant-Erstellung, Datenbankschema, Berechtigungen oder Offline-Persistenz. Scope-Prüfung auch nach neuen Dialogen. DE/EN über Fragmente generieren. Ein bestehendes Minor-Changelog ergänzen; keine Version erhöhen. Tests für Erhalt/Ersetzen/Abbrechen, gleiche Vorlage, Ohne Vorlage, direkte Auswahl, Später einrichten und stale Dialogergebnisse. Screenshots für schmale Breite, Hell/Dunkel und große Schrift prüfen.
