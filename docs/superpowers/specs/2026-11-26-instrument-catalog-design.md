# Instrumentensammlung und Ensemble-Vorlagen

Stand: 26.11.2026. Fachliche Richtung und Einbindung in Attendix wurden im Gespräch bestätigt; Umsetzung mit „ja auf gehts“ beauftragt. Nachtrag: Volksinstrumentenorchester ersetzt Big Band als Vorlage.

## Ziel

Leitende Personen können beim Einrichten eines Ensembles eine bearbeitbare Instrumentauswahl übernehmen und bestehende Ensembles später aus derselben Sammlung ergänzen. Seltene Instrumente wie Bassflöte sowie eigene Einträge bleiben erreichbar.

## Ansätze und Entscheidung

1. Nur ein Katalog: hilft beim einzelnen Ergänzen, lässt die Ersteinrichtung aufwendig.
2. Katalog plus bearbeitbare Vorlagen: im Gespräch gewählte Lösung für Einrichtung und laufende Pflege.
3. Zusätzlich werkbezogene Sollbesetzung und strukturierte Wechselinstrumente: spätere Erweiterung; gehört nicht in diesen Auftrag.

## Verbindlicher Umfang

- Lokal mitgelieferter, versionierter Instrumentkatalog mit deutschen und englischen Namen, echten Synonymen und Instrumentenfamilien. Kein KI- oder Netzwerkaufruf zum Durchsuchen.
- Suche nach Namen und Synonymen (Geige → Violine, Bratsche → Viola, Bassflöte als eigener Instrumenttyp), Familienfilter, Mehrfachauswahl.
- Vorlagen: Sinfonieorchester, Streichorchester, Blasorchester, Volksinstrumentenorchester, gemischter Chor SATB; „Ohne Vorlage“ möglich. Keine Big-Band-Vorlage.
- Vorschläge sind einzeln abwählbar. Optionale Ergänzungen sind nicht automatisch ausgewählt. Keine Personenzahlen oder Anwesenheitseinträge erzeugen.
- Vorlagen und Sammlung auch beim Ergänzen bestehender Ensembles anbieten. Eigener Name bleibt möglich; bestehender Editor bleibt erhalten.
- Lokale Instrumentgruppen, ihre IDs, Personen- und Notenzuordnungen bleiben die Autorität im Ensemble. Bestehende Einträge werden nicht überschrieben, umbenannt oder mit neuen Kategorien versehen.
- Violine I und Violine II sind verschiedene Ensemble-Einträge desselben Katalogtyps. Eine absichtliche weitere Stimme ist über einen eigenen Namen möglich.
- Keine weiteren Änderungen an Werkbesetzungen, Teilnehmerkreis oder Anwesenheitsberechnung.

## Fachliche Vorlage

Sinfonieorchester: 1. Violinen, 2. Violinen, Bratschen, Violoncelli, Kontrabässe; Querflöte, Oboe, Klarinette, Fagott; Horn, Trompete, Posaune; Pauken, Schlagwerk. Optional Piccolo, Englischhorn, Bassklarinette, Kontrafagott, Tuba, Harfe, Klavier und Celesta. Dies ist eine praktische Startauswahl, keine universelle Orchesterdefinition.

Streichorchester verwendet die fünf Streichergruppen; SATB verwendet vier Stimmen ohne zusätzliche Kategorien. Blasorchester erhält die einschlägigen Holz-, Blech- und Schlaginstrumente. Die konkrete volksmusikalische Tradition der Volksinstrumentenvorlage wird im laufenden Gespräch präzisiert; der Katalog enthält osteuropäische und alpenländische Instrumente unabhängig von dieser Vorauswahl.

## Darstellung

Material 3 als bestehende Grundlage, darauf Attendix `RdPalette`, `RdType`, `RdFormTopBar`, `RdFormBody`, `RdGroupedList`, `RdSheetHead` und die vorhandenen Auswahlbausteine. Alle Farbwelten, Hell/Dunkel, schmale Mobilansicht und vergrößerte Schrift berücksichtigen. Keine neue Markenleiste, kein neuer Navigationsbereich und keine eigenständige Designsprache.

- Neues Ensemble: zusätzlicher Abschnitt für Vorlage/Auswahl im bestehenden Formular. Über dieselbe Auswahlansicht kann man die Vorlage bearbeiten. Auswahl ist zunächst nur ein Entwurf.
- Instrument hinzufügen: das bestehende Plus öffnet die Sammlung. Suche oben, Familienfilter, flache Auswahlzeilen; ausgewählte Einträge auch beim Filtern erhalten. Eine klare Übernahmeaktion.
- Bereits vorhandene Einträge: erkennbar markieren und nicht erneut übernehmen; alternative Benennung erlaubt bewusste weitere Stimmen.
- Eigener Eintrag: erreichbar neben der Sammlung, weiterhin freier Name und anschließender bestehender Editor.
- Orchestertexte heißen Instrument/Instrumente und Register; Chortexte Stimme/Stimmen, wie bisher. Allgemeine Gruppen behalten ihren manuellen Ablauf.
- Alle neuen Bedientexte über `lib/l10n/fragments`, ARB und Dart-Dateien generieren. Katalogbezeichnungen selbst sind Daten und bieten DE/EN mit DE-Fallback.

## Technische Entscheidungen

Dies sind Umsetzungsentscheidungen zur vereinbarten Funktion:

- Der mitgelieferte Katalog ist unveränderliche Dart-Daten; nach der Auswahl werden bestehende Instrumentspalten als lokale Kopie geschrieben. Kein Datenbankschemawechsel und keine automatische spätere Synchronisation des Katalogs in lokale Namen. Stabile Katalog-IDs bleiben in den Entwürfen und Vorlagen; lokale Daten behalten ihre bisherigen Datenbank-IDs.
- Dublettenprüfung ist konservativ: normalisierter vollständiger Name und kuratierte exakte Synonyme. Keine Teilwort- oder grobe Dateinamenerkennung, die Bassflöte/Flöte oder Marimba/Glockenspiel zusammenfasst. Nummerierte Stimmen verwenden nur nummerierte Synonyme.
- Neue Instrumente in einem Bulk-Insert schreiben; Kategorien vorher frisch lesen und bei Bedarf erzeugen. Bei Fehlern dürfen höchstens leere neu angelegte Kategorien zurückbleiben; keine halbe Instrumentauswahl. Wiederholung liest den tatsächlichen Stand neu und überspringt bereits angelegte Namen. Kein automatisches Löschen bei unklarem Netzwerkergebnis.
- Bestehende Kategorien und Reihenfolgen beibehalten. Neue Instrumente ans Ende anhängen; neu angelegte Familien folgen musikalischer Reihenfolge. Chor erhält keine neuen Kategorien.
- Den Account und das Ensemble beim Öffnen/Bestätigen binden; nach Account-/Ensemblewechsel kein Schreiben in den neuen Kontext und keine veraltete Erfolgsmeldung. Demo-Sperre und vorhandene Rollen gelten auch für Bulk-Import. Sammlung ist offline sichtbar; Schreiben erfordert Verbindung, ohne neue Offline-Warteschlange.
- Ensemble-Erstellung und optionale Katalogübernahme getrennt behandeln: nach erfolgreicher Ensemble-Erstellung den neuen Tenant binden, dann Auswahl übernehmen. Scheitert nur die Auswahl, bleibt das Ensemble erfolgreich angelegt; verständlicher Hinweis und Möglichkeit zum Nachholen über Instrumente. Niemals wegen eines Katalogfehlers einen zweiten Tenant erstellen.
- Stimmung und Notenschlüssel nur bei verlässlichen Vorgaben befüllen; keine geratenen Tonumfänge. Unterschiedliche Schlaginstrumente bleiben getrennt. Katalogwerte müssen vom vorhandenen Editor verlustfrei dargestellt werden können.

## Grenzen

Keine zentrale Katalogverwaltung, Instrumentfotos, Remote-Inhaltsverwaltung, Sollzahlen, Besetzungsalarme oder personenbezogene Mehrfachinstrumentzuordnung. Der bestehende Notenmatcher wird nicht umfassend umgebaut; kopierte präzise Synonyme stehen ihm wie bei manuellen Gruppen zur Verfügung. Gleichzeitige unabhängige Anlage durch zwei Geräte erhält ohne neue DB-Unique-Regel keine globale Namenseindeutigkeitsgarantie.

## Abnahmekriterien

1. Geige findet Violine; Bassflöte, Piccolo, Altflöte bleiben unterscheidbar.
2. Vorlage Sinfonieorchester liefert 14 standardmäßig ausgewählte Ensemble-Einträge und optionale Ergänzungen. Big Band erscheint nicht als Vorlage.
3. Abwahl, Familienfilter und Suche erhalten den expliziten Auswahlzustand. Abbrechen schreibt nichts.
4. Eine Übernahme erzeugt nur gewählte neue Instrumente; erneute Übernahme dupliziert diese nicht. Violine I/II bleiben getrennt; bestehende Namen/Kategorien/IDs unverändert.
5. Fehler, Demo, fehlende Berechtigung und Kontextwechsel erzeugen keine fremden/unerwarteten Einträge.
6. Instrumentlisten, Erstellungsformular und Editor verwenden die bestehenden Komponenten und Texte für Orchester/Chor. Eigener Eintrag bleibt erreichbar.
7. Ensemble-Erfolg plus Katalogfehler wird separat gemeldet; kein erneuter Tenant bei Wiederholung.
8. Tests für Katalog, Suche, Entwurf/Dubletten, Batch-Schreiben und wesentliche UI-Interaktionen; betroffene bestehende Tests, Analyse und Dokumentationschecks.
