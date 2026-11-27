# Geführte Ensemble-Erstellung

Am 27.11.2026 mit „passt“ angenommen: ein kurzer Assistent mit drei Fragen statt des bisherigen Formulars. Bestehende Gestaltung und Instrumentensammlung bleiben Grundlage.

## Ablauf
1. „Welche Art von Gruppe möchtest du erstellen?“ Große auswählbare Karten für Orchester, Chor und „Andere Gruppe“. Eine bewusste Auswahl ist nötig, bevor Weiter aktiv wird.
2. Typabhängig „Wie heißt dein Orchester?“, „Wie heißt dein Chor?“ bzw. „Wie heißt deine Gruppe?“ Name und vorgeschlagenes, editierbares Kürzel.
3. Für Orchester/Chor: „Mit welcher Besetzung möchtest du starten?“ Passende bestehende Vorlagen, Sammlung zum eigenen Zusammenstellen/Anpassen und „Später einrichten“. Auswahlvorschau mit Anzahl. Kurze Zusammenfassung im letzten Schritt, mit Abschluss „Orchester erstellen“, „Chor erstellen“ oder „Gruppe erstellen“.

Bei allgemeinen Gruppen entfällt Schritt 3; Zusammenfassung und Abschluss stehen in Schritt 2. Fortschritt „Schritt {current} von {total}“ folgt dem tatsächlichen Ablauf. Unten Zurück/Weiter bzw. Erstellen, scrollbarer Inhalt, bestehende Rd-Farben, Schriften und gerundete Flächen. Keine zusätzliche Prüfseite.

Die Leitungsgruppe wird als „Leitung“ (EN: Leadership) vorbereitet. In der Zusammenfassung ist sie über „Ändern“ editierbar. Kein Pflichtscreen für den technischen Begriff Hauptgruppe.

## Zustand und Verhalten
Zurück (auch System-Zurück innerhalb des Assistenten) erhält Eingaben. Namensdaten und Leitungsname bleiben beim Gruppenartwechsel bestehen. Orchester- und Chorauswahl werden je Typ im lokalen Entwurf aufgehoben und bei Rückkehr wiederhergestellt; nur die aktive, kompatible Auswahl wird beim Erstellen importiert. Allgemeine Gruppen importieren keine versteckte Instrumentenauswahl.

Kürzel wird solange aus dem Namen vorgeschlagen, bis es manuell bearbeitet wurde. Implementierungsentscheidung: mehrere Wörter -> erste Buchstaben (maximal sechs), einzelnes Wort -> erste drei Zeichen, Großschreibung. Beispiele Stadtorchester Musterstadt -> SM und Orchester -> ORC. Manueller Wert bleibt bei späterer Namensänderung unverändert. Pflichtangaben validieren, bevor der jeweilige Schritt verlassen wird.

Erst die letzte explizite Bestätigung erstellt das Ensemble. Doppelklickschutz, Account-/Tenant-Prüfungen, Importfehlerbehandlung und bestehende Katalogregeln bleiben erhalten. Gleiche Vorlage ist weiterhin wirkungslos; Ergänzen/Ersetzen/Abbrechen und sichere eigene Namen bleiben erhalten. Kein Reset allein durch Navigation.

## Ansätze und Umfang
Gewählt: drei eigene Frage-Screens mit kompakter Zusammenfassung im letzten Screen. Ein aufklappendes Formular bietet weniger klare Führung; ein vierter Prüfschritt verlängert diesen kurzen Ablauf. Dies ist eine Erweiterung der vorhandenen Erstellungsseite, keine neue Navigation oder Backend-Funktion.

Keine Änderung an Repository, Schema, Importer oder Berechtigungen. Alle neuen Texte DE/EN über bestehende Fragmente generieren. Volksinstrumentenorchester mit Mandoline bleibt erhalten; keine Big-Band-Vorlage. Keine Veröffentlichung in diesem Auftrag; vorhandenen Branch/Worktree weiterverwenden.
