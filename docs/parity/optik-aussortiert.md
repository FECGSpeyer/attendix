# Aussortiert: mittel-Punkte, die nur Optik betreffen

Stand Runde 4 (Flutter-master 8004a44, Ionic 4.19.9). Nach Leons Vorgabe vom 05.11.2026 (Funktion zählt, Aussehen nicht) auf **niedrig** gesetzt und damit aus den Fix-Listen genommen. Vier Punkte (fehlende Fehler- bzw. Validierungsmeldung) hat das Sol-Review danach wieder auf mittel gesetzt. Wenn ein Punkt doch angeglichen werden soll: im Tracker „Angleichen“ wählen.

## app (4)

- `app.component#nav-3a7bceb6-2`: Recovery-Link öffnet eine eigene Seite statt eines Alerts mit gleicher Funktion; das abweichende Ziel danach ist in x-fde4d51685 erfasst.
- `register/register.page#popover-f947f492`: Gleicher Infotext, nur Dialog statt Popover.
- `register/tenant-register/tenant-register.page#actionsheet-ab6f737a`: Das Action-Sheet bot nur „Ersetzen“/„Abbrechen“; das Bild ist bis zum Absenden nur lokal und die Auswahl lässt sich abbrechen, Ergebnis gleich.
- `tabs/side-nav/side-nav.component#modal-186fad14`: Ablaufpläne öffnen als normale Seite statt als Modal, Funktion gleich.

## einstellungen (22)

- `settings/administration/administration.page#alert-8fd4640e`: Gemeinde anlegen geht gleich, Leer-Meldung mit gleichem Text und Fehler werden gemeldet; nur Dialog bleibt nicht offen, kein Overlay, anderer Fehlertext.
- `settings/files/files.page#popover-92206ccb`: Gleiche Einträge, Reihenfolge und Bedingungen, nur Action Sheet statt Popover.
- `settings/files/files.page#popover-f66de769`: Gleicher Hilfetext, nur Dialog statt Popover und ohne Fettdruck.
- `settings/general/general.page#action-50952c99`: Grund hinzufügen per Dialog statt leerer Zeile; leere Gründe verwirft auch Ionic beim Speichern.
- `settings/general/general.page#action-578da7ee`: Grund hinzufügen per Dialog statt leerer Zeile; leere Gründe verwirft auch Ionic beim Speichern.
- `settings/general/shifts/shift/shift.page#alert-0ef2eadc`: Gleiche Wahl (nur Schichtplan oder mit Zuweisungen) und gleiche Kopierlogik, nur Schalter im Sheet statt zweitem Alert.
- `settings/general/type/type.page#action-2be774f4`: Abbrechen der Neuanlage ist möglich, nur „Abbrechen“ im Namensdialog statt X im Modal.
- `settings/general/type/type.page#action-bab9d008`: Gleiche Aktion, nur Outline-Button mit Dialog statt Inline-Eingabe.
- `settings/general/type/type.page#action-d5d47659`: Erinnerungen sind gleich konfigurierbar, nur inline statt über Eintrag mit Sheet.
- `settings/general/type/type.page#field-4366c1dd`: To-Do anlegen geht gleich, nur per Dialog statt Inline-Eingabe.
- `settings/general/type/type.page#field-557c3624`: Gleiche Deadline-Werte speicherbar, nur freies Stundenfeld statt Vorgaben-Auswahl.
- `settings/general/type/type.page#field-ba7f8aa7`: Minuten bleiben änderbar, nur über den Bearbeiten-Dialog statt inline.
- `settings/general/type/type.page#field-d34df4b8`: Checkliste ist ohne Schalter gleich nutzbar (leer = keine), gespeicherter Wert beim Anlegen gleichwertig.
- `settings/general/type/type.page#field-e6aa9e5e`: Gleiche Auswahl und gleiche gespeicherte relevant_groups, nur FilterChips und kürzerer Hinweis mit gleicher Bedeutung.
- `settings/general/type/type.page#modal-0895b1d0`: Gleicher Inhalt inline statt im Sheet-Modal.
- `settings/general/type/type.page#popover-31d23755`: Gleiche 9 Farben und Auswahl, nur Dialog statt Popover.
- `settings/general/type/type.page#text-2c11308c`: Gleiche Filter-Einstellungen, nur auf zwei Abschnitte verteilt; Hinweis auf „Filter“ findet sich im Abschnitt „Zusatzfeld-Filter“ wieder.
- `settings/help/article/help-article.page#popover-c1b18c0d`: Gleicher Inhalt, nur zentrierter Dialog mit Schließen-Button statt Popover.
- `settings/settings/settings.page#modal-2d9ef553`: Registrierung öffnet als Vollbildseite statt Modal, gleiche Funktion.
- `settings/settings/settings.page#modal-35a628ef`: Archivierte Person öffnet als Seite statt Modal, schreibgeschützt mit Reaktivieren wie in Ionic.
- `settings/settings/settings.page#modal-574f5f7c`: Ablaufpläne öffnen als Seite statt Modal, gleiche Funktion und Rückkehr.
- `settings/settings/settings.page#modal-fb3873fe`: Ausstehende Person öffnet als Seite statt Modal, Freigabe-Aktionen wie in Ionic per FAB.

## nativ (2)

- `x-8140fe9e0d` **Push-Kanal 'default' neu mit hoher Wichtigkeit**: Pushes kommen gleich an, nur als Heads-up-Banner statt still in der Leiste.
- `x-bc26763c9d` **Adaptives Icon: Logo deutlich kleiner**: Nur die Größe des Logos im App-Icon weicht ab.

## personen (11)

- `people/list/list.page#modal-11a551b4`: Nur Dialogtyp anders, Felder und geschriebene Daten gleich.
- `people/list/list.page#modal-38ba21ec`: Nur Darstellung als Seite statt Modal, Inhalt und Leserechte gleich.
- `people/person/person.page#action-40313396`: Gleiche Aktionen (Ersetzen/Entfernen/Ansehen) nur in einem Aktionsblatt statt im Bildbetrachter angeordnet.
- `people/person/person.page#action-ea218e71`: 'Ersetzen' vorhanden, nur an anderer Stelle (Aktionsblatt statt Betrachter).
- `people/person/person.page#alert-692c7626`: Texte, Fehlermeldungsart und Toast anders, Ablauf, Pflichtgrund und DB-Wirkung gleich.
- `people/person/person.page#field-0755eef9`: Datum per Kalender statt Texteingabe wählbar, Funktion gleich.
- `people/person/person.page#field-3abdeaf8`: Datum per Kalender (mit Jahresauswahl) statt Texteingabe wählbar, gespeicherter Wert gleich; nur Warnfarbe bleibt bis Neuöffnen.
- `people/person/person.page#field-6c24372b`: Datum per Kalender statt Texteingabe wählbar, Funktion gleich.
- `people/person/person.page#modal-75561fb4`: Nur Dialogtyp und Feldbeschriftung anders, Archivieren mit Datum und Notiz gleich.
- `people/person/person.page#modal-b80602d8`: Nur Dialog statt Sheet, Inhalt gleich.
- `people/person/person.page#modal-ecac8535`: Bildbetrachter weiterhin erreichbar, nur über einen Eintrag im Aktionsblatt.

## planung (8)

- `org-settings/org-planning-templates/org-planning-templates.page#field-d3412616`: Minuten der Standardfelder sind weiterhin änderbar, nur über den Bearbeiten-Dialog statt inline – andere Platzierung.
- `org-settings/org-planning-templates/org-planning-templates.page#popover-21e36ab9`: Gleiche Einträge in gleicher Reihenfolge, nur Aktionsblatt statt Popover und ohne Trenner.
- `planning/planning.page#actionsheet-0c53b41c`: Alle Ionic-Optionen vorhanden, Flutter hat nur zusätzlich „Freigabe aufheben“ und Icons.
- `planning/planning.page#alert-75ab0ccf`: Gleiche Tagesoptionen und gleiches Ergebnis, nur Aktionsblatt statt Radio-Alert mit Speichern.
- `planning/planning.page#modal-bbd6596e`: Nur Dialogtyp (AlertDialog statt Vollbild-Modal), gleiche Felder und gleiches Ergebnis.
- `public-planning/public-planning.page#alert-53b00c7b`: Löschen bleibt per Wischen möglich, „Updaten“ statt „Speichern“ und zusätzliches Minutenfeld – keine fehlende Funktion.
- `shared-plan/shared-plan.page#action-a9ede0e6`: Löschen per Wischen statt Papierkorb-Button; „Nur Block auflösen“ liefert das Ionic-Ergebnis, die Rückfrage ist eine Absicherung.
- `shared-plan/shared-plan.page#action-ec0c1511`: Bearbeitungsmodus bietet alle Ionic-Funktionen plus Extras (Minuten, Einrücken, Block-Optionen); Block-Zeitraum ist nur Mehrinformation.

## querschnitt (2)

- `services/db.service#alert-f27cc642`: Vollseite statt Radio-Alert, jede Instanz (auch die gespeicherte, die 'Abbrechen' öffnet) ist direkt wählbar.
- `shared/files-folder-picker/files-folder-picker.component#action-c2019029`: Gleiche Ordnerwahl, nur Position/Beschriftung anders; der Ordnername steht im Pfad oben, auch während des Ladens wird der dort angezeigte Ordner gewählt.

## termine (4)

- `attendance/att-list/att-list.page#alert-c973a254`: „Anderer Dirigent“ wird inline statt per Dialog eingegeben, gleiches Ergebnis.
- `attendance/attendance/attendance.page#alert-9b3e485d`: Sheet statt Alert bei einem Anmeldefeld mit gleichen Eingabearten und gleichem Speichern; zusätzlicher Toast.
- `attendance/attendance/attendance.page#alert-aadedcba`: „Anderer Dirigent“ wird inline statt per Dialog eingegeben, gleiches Ergebnis.
- `attendance/attendance/attendance.page#toast-821c46bb`: Gleicher Fehlertext als Fehlerseite mit „Neu laden“ statt Toast mit Auto-Zurück; Fehler bleibt nicht unbemerkt.

## uebersicht (6)

- `home-dashboard/components/absences-card/absences-card.component#modal-6daf3e85`: Person öffnet als Seite statt als Modal, Bearbeitbarkeit und Neuladen gleich.
- `home-dashboard/components/birthdays-card/birthdays-card.component#modal-388a556f`: Person öffnet als Seite statt als Modal, Bearbeitbarkeit und Neuladen gleich.
- `home-dashboard/components/critical-persons-card/critical-persons-card.component#modal-160799e3`: Person öffnet als Seite statt als Modal, Bearbeitbarkeit und Neuladen gleich.
- `home-dashboard/components/member-changes-card/member-changes-card.component#modal-04f3c3d5`: Person öffnet als Seite statt als Modal, Bearbeitbarkeit und Neuladen gleich.
- `home-dashboard/components/next-event-card/next-event-card.component#modal-29087654`: Termin öffnet als Seite statt als Modal, Rollen und Neuladen gleich.
- `stats/stats.page#field-2d5da58e`: Mehrfachauswahl als Dialog mit Abbrechen statt als Modal, Anzeige und Filterwirkung gleich.

## werke (2)

- `songs/song/song.page#modal-81e9f13d`: AlertDialog statt Sheet-Modal, gleiche Auswahl, Vorbelegung und gespeicherte Werte.
- `songs/songs.page#popover-21a14c45`: Gleiche Filter- und Ansichtsoptionen, nur Bottom-Sheet mit Überschriften und Chips statt Popover.

