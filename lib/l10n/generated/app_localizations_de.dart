// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get a11yAdd => 'Hinzufügen';

  @override
  String get a11yClearInput => 'Eingabe löschen';

  @override
  String get a11yDecrease => 'Verringern';

  @override
  String get a11yHelp => 'Hilfe';

  @override
  String get a11yIncrease => 'Erhöhen';

  @override
  String get a11yMoreActions => 'Weitere Aktionen';

  @override
  String get a11yNextPage => 'Nächste Seite';

  @override
  String get a11yPreviousPage => 'Vorherige Seite';

  @override
  String a11yRating(Object count) {
    return '$count von 5 Sternen';
  }

  @override
  String get a11ySelectDate => 'Datum wählen';

  @override
  String get adminAddChurch => 'Gemeinde hinzufügen';

  @override
  String get adminChurchAdded => 'Die Gemeinde wurde erfolgreich hinzugefügt.';

  @override
  String get adminChurchName => 'Name der Gemeinde';

  @override
  String get adminChurchRenamed => 'Gemeinde umbenannt';

  @override
  String adminChurchesCount(Object count) {
    return 'Gemeinden ($count)';
  }

  @override
  String get adminCurrentlyUsed => 'Aktuell belegt';

  @override
  String adminDuplicateGroups(Object count) {
    return '$count Duplikat-Gruppe(n) gefunden';
  }

  @override
  String get adminDuplicatesHint => 'Gemeinden mit gleichem Namen können zusammengeführt werden.';

  @override
  String get adminEvaluation => 'Auswertung';

  @override
  String get adminFlutterAddFailed => 'Fehler beim Hinzufügen';

  @override
  String adminGb(Object value) {
    return '$value GB';
  }

  @override
  String get adminInvalidLimit => 'Bitte eine Zahl größer 0 eingeben oder das Feld leeren (unbegrenzt).';

  @override
  String get adminInvalidValues => 'Bitte gib gültige Werte ein.';

  @override
  String get adminLimitHelper => 'Leer lassen für unbegrenzt. Neue Instanzen starten mit 5 GB.';

  @override
  String get adminMaxStorage => 'Max. Speicher (GB)';

  @override
  String get adminMerge => 'Zusammenführen';

  @override
  String get adminMergeAll => 'Alle zusammenführen';

  @override
  String get adminMergeAllDuplicates => 'Alle Duplikate zusammenführen';

  @override
  String adminMergeAllMessage(Object total, Object groups) {
    return '$total Duplikat(e) in $groups Gruppe(n) werden zusammengeführt. Fortfahren?';
  }

  @override
  String get adminMergeChurches => 'Gemeinden zusammenführen';

  @override
  String get adminMergeFailed => 'Fehler beim Zusammenführen';

  @override
  String adminMergeMessage(Object source, Object target) {
    return '„$source“ wird in „$target“ zusammengeführt. Alle Personen werden aktualisiert. Fortfahren?';
  }

  @override
  String adminMergeMoveMessage(Object source, Object target) {
    return '„$source“ wird gelöscht und alle Personen zu „$target“ verschoben. Fortfahren?';
  }

  @override
  String adminMergeWith(Object name) {
    return '„$name“ zusammenführen mit...';
  }

  @override
  String adminMerged(Object count) {
    return 'Zusammengeführt: $count Person(en) aktualisiert';
  }

  @override
  String adminMergedAll(Object updated, Object total) {
    return '$updated Person(en) aktualisiert, $total Duplikat(e) entfernt';
  }

  @override
  String get adminMerging => 'Gemeinden werden zusammengeführt...';

  @override
  String get adminRenameChurch => 'Gemeinde umbenennen';

  @override
  String get adminRenameFailed => 'Fehler beim Umbenennen';

  @override
  String get adminShowAllChurches => 'Alle Gemeinden anzeigen';

  @override
  String adminStorageFor(Object name) {
    return 'Speicher Dateiablage: $name';
  }

  @override
  String adminStorageLimit(Object gb) {
    return 'Speicherlimit: $gb GB';
  }

  @override
  String get adminStorageUnlimited => 'Speicher: unbegrenzt';

  @override
  String adminTimesPresent(Object count) {
    return '${count}x vorhanden';
  }

  @override
  String get adminTitle => 'Administration';

  @override
  String get adminUnlimited => 'Unbegrenzt';

  @override
  String get agendaAddTask => 'Aufgabe hinzufügen';

  @override
  String agendaAddTopics(num count, Object min) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Themen',
      one: '$count Thema',
    );
    return '$_temp0 aufnehmen · $min min';
  }

  @override
  String get agendaAgendaUpdated => 'Tagesordnung aktualisiert';

  @override
  String get agendaAlreadyInPlan => 'bereits im Ablaufplan';

  @override
  String get agendaAlreadyPlanned => ' (bereits eingeplant)';

  @override
  String get agendaChooseTopics => 'Themen auswählen';

  @override
  String agendaCreateAsNew(Object name) {
    return '„$name“ als neues Thema anlegen';
  }

  @override
  String get agendaCreateFailed => 'Thema konnte nicht angelegt werden';

  @override
  String get agendaDefault => 'Standard';

  @override
  String get agendaDeleteConfirm => 'Thema wirklich löschen?';

  @override
  String get agendaDeleteFailed => 'Löschen fehlgeschlagen';

  @override
  String get agendaDeleteMessage => 'Es verschwindet aus dem Themenspeicher. Bereits geplante Ablaufpläne und Protokolle bleiben unverändert. Soll es nur aus einem Termin raus, entferne es dort über „Themen aufnehmen“ oder in der Teamorganisation.';

  @override
  String get agendaDeleteTopic => 'Thema löschen';

  @override
  String get agendaDeleted => 'Gelöscht';

  @override
  String get agendaDescription => 'Beschreibung';

  @override
  String get agendaDescriptionPlaceholder => 'Hintergrund, Ziel, offene Fragen …';

  @override
  String agendaDone(Object who) {
    return '$who · erledigt';
  }

  @override
  String agendaDoneOn(Object who, Object date) {
    return '$who · erledigt $date';
  }

  @override
  String agendaDueOn(Object who, Object date) {
    return '$who · fällig $date';
  }

  @override
  String get agendaDurationPerSession => 'Dauer pro Sitzung (Min.)';

  @override
  String get agendaEnterTitle => 'Bitte einen Titel eingeben';

  @override
  String get agendaFlutterNoMatch => 'Kein passendes Thema gefunden.';

  @override
  String get agendaFlutterNoOpenTopics => 'Keine offenen Themen. Lege oben ein neues an.';

  @override
  String get agendaFlutterNotFound => 'Thema nicht gefunden';

  @override
  String get agendaHigh => 'Hoch';

  @override
  String get agendaHistory => 'Verlauf';

  @override
  String agendaInsertAfter(Object name) {
    return 'Wird nach „$name“ eingefügt';
  }

  @override
  String get agendaInsertAtStart => 'Wird am Anfang eingefügt';

  @override
  String get agendaLoadFailed => 'Themen konnten nicht geladen werden';

  @override
  String get agendaLonger => 'Länger';

  @override
  String get agendaLow => 'Niedrig';

  @override
  String get agendaMedium => 'Mittel';

  @override
  String agendaNewEnd(Object where, Object time) {
    return '$where · Ende neu $time';
  }

  @override
  String get agendaNewEvent => 'Neuen Termin anlegen';

  @override
  String get agendaNewTopic => 'Neues Thema';

  @override
  String get agendaNoOutcome => 'Ohne Ergebnis';

  @override
  String get agendaNoProtocolEvent => 'Noch kein Termin mit Tagesordnung geplant';

  @override
  String get agendaNoTasks => 'Keine Aufgaben';

  @override
  String get agendaNobody => 'Niemand';

  @override
  String get agendaNotDiscussed => 'Noch in keinem Termin besprochen.';

  @override
  String get agendaPlanFailed => 'Thema konnte nicht eingeplant werden';

  @override
  String get agendaPlanIn => 'Einplanen';

  @override
  String get agendaPlanSaveFailed => 'Ablaufplan konnte nicht gespeichert werden';

  @override
  String get agendaPlanned => 'Geplant';

  @override
  String agendaPlannedFor(Object date) {
    return 'Eingeplant für $date';
  }

  @override
  String get agendaPostponed => 'Vertagt';

  @override
  String get agendaPostponedFromLast => 'Vertagt aus letzter Sitzung';

  @override
  String agendaPostponedOn(Object date) {
    return 'Vertagt $date';
  }

  @override
  String get agendaPriority => 'Priorität';

  @override
  String agendaProposedBy(Object name) {
    return 'Vorschlag von $name';
  }

  @override
  String agendaRemoveTopics(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Themen',
      one: '$count Thema',
    );
    return '$_temp0 entfernen';
  }

  @override
  String get agendaRemovedFromPlan => 'wird aus dem Ablaufplan entfernt';

  @override
  String get agendaResponsible => 'Verantwortlich';

  @override
  String get agendaSaveFailed => 'Thema konnte nicht gespeichert werden';

  @override
  String get agendaSearchOrCreate => 'Thema suchen oder neu anlegen';

  @override
  String get agendaShorter => 'Kürzer';

  @override
  String get agendaStatus => 'Status';

  @override
  String get agendaStatusDone => 'Erledigt';

  @override
  String get agendaStatusDropped => 'Verworfen';

  @override
  String get agendaStatusOpen => 'Offen';

  @override
  String get agendaTasks => 'Aufgaben';

  @override
  String agendaTasksDone(Object done, Object total) {
    return '$done von $total erledigt';
  }

  @override
  String get agendaTitlePlaceholder => 'Worum geht es?';

  @override
  String get agendaTopic => 'Thema';

  @override
  String get agendaTopicAdded => 'Thema aufgenommen';

  @override
  String get agendaTopicRemoved => 'Thema aus dem Ablaufplan entfernt';

  @override
  String get agendaTopicStore => 'Themenspeicher';

  @override
  String agendaTopicsAdded(Object count) {
    return '$count Themen aufgenommen';
  }

  @override
  String agendaTopicsRemoved(Object count) {
    return '$count Themen aus dem Ablaufplan entfernt';
  }

  @override
  String get agendaWhichEvent => 'In welchen Termin einplanen?';

  @override
  String get appChangePassword => 'Passwort ändern';

  @override
  String get appConfirmLinkInvalid => 'Der Bestätigungslink ist ungültig oder abgelaufen.';

  @override
  String get appEmailConfirmed => 'E-Mail-Adresse bestätigt. Willkommen!';

  @override
  String get appMinSixPlaceholder => 'Min. 6 Zeichen eingeben...';

  @override
  String appNativeAdGoTo(Object store) {
    return 'Zum $store';
  }

  @override
  String get appNativeAdHeader => 'Attendix als App verfügbar!';

  @override
  String appNativeAdMessage(Object store) {
    return 'Attendix gibt es jetzt als native App mit Push-Benachrichtigungen und schnellerem Zugriff. Jetzt im $store herunterladen!';
  }

  @override
  String get appNewPassword => 'Neues Passwort eingeben';

  @override
  String get appPasswordMin => 'Bitte gib ein Passwort mit mindestens 6 Zeichen ein';

  @override
  String get appRedirectLoadApp => 'Lade die App im Store deines Geräts:';

  @override
  String get appResetLinkInvalid => 'Der Link zum Zurücksetzen ist ungültig oder abgelaufen.';

  @override
  String get attListAddEvent => 'Termin hinzufügen';

  @override
  String get attListAddEvents => 'Termine hinzufügen';

  @override
  String get attListAddSongs => 'Werk(e) hinzufügen';

  @override
  String get attListAverage => 'Durchschnitt';

  @override
  String get attListChooseOneDate => 'Bitte wähle mindestens ein Datum aus';

  @override
  String get attListChooseSongs => 'Werke auswählen';

  @override
  String get attListConductor => 'Dirigent';

  @override
  String get attListContinue => 'Fortfahren';

  @override
  String attListCountAbsent(Object count) {
    return '$count abwesend';
  }

  @override
  String attListCountExcused(Object count) {
    return '$count entschuldigt';
  }

  @override
  String attListCountPresent(Object count) {
    return '$count anwesend';
  }

  @override
  String get attListDateMulti => 'Datum (Mehrfachauswahl möglich)';

  @override
  String get attListDistributeDuties => 'Dienste verteilen';

  @override
  String get attListDurationDays => 'Dauer (in Tagen)';

  @override
  String attListDutyFilled(Object text) {
    return '$text besetzt';
  }

  @override
  String get attListEnterConductor => 'Dirigent eingeben';

  @override
  String get attListEventAdded => 'Termin hinzugefügt';

  @override
  String get attListEventTypes => 'Veranstaltungstypen';

  @override
  String get attListEvents => 'Termine';

  @override
  String get attListEventsAdded => 'Termine hinzugefügt';

  @override
  String attListEventsSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine ausgewählt',
      one: '$count Termin ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get attListHolidays => 'Feiertage';

  @override
  String get attListHolidaysOfState => 'Feiertage des ausgewählten Bundeslandes';

  @override
  String get attListInfoText => 'Info-Text (optional)';

  @override
  String get attListInfoTextHelper => 'Dieser Text wird anstelle des Typs angezeigt.';

  @override
  String get attListInvalidType => 'Ungültiger Anwesenheitstyp ausgewählt';

  @override
  String get attListLess => 'Weniger';

  @override
  String get attListMore => 'Mehr';

  @override
  String attListNeededPeople(Object label) {
    return 'Benötigte Personen · $label';
  }

  @override
  String get attListNoDate => 'Kein Datum ausgewählt';

  @override
  String get attListNoEventsYet => 'Bisher wurden noch keine Termine angelegt';

  @override
  String get attListNoSongsFound => 'Keine Werke gefunden';

  @override
  String get attListNoSongsSelected => 'Keine Werke ausgewählt';

  @override
  String get attListOtherConductor => 'Anderer Dirigent';

  @override
  String get attListPlace => 'Ort (für Navigation)';

  @override
  String get attListPlacePlaceholder => 'z. B. Gemeindehaus, Musterstr. 1, 12345 Berlin';

  @override
  String attListPresentOf(Object present, Object total) {
    return '$present von $total anwesend';
  }

  @override
  String get attListRemoveConfirm => 'Möchtest du den Termin wirklich entfernen?';

  @override
  String get attListSchoolHolidays => 'Ferien';

  @override
  String get attListSchoolHolidaysOfState => 'Ferien des ausgewählten Bundeslandes';

  @override
  String get attListSearchSong => 'Werk suchen...';

  @override
  String get attListShowAll => 'Alle anzeigen';

  @override
  String get attListSongs => 'Werke';

  @override
  String get attListSongsLabel => 'Werk(e)';

  @override
  String attListSongsSelected(num count) {
    return '$count Werk(e) ausgewählt';
  }

  @override
  String get attListTodayDeselected => 'Das aktuelle Datum wurde deselektiert';

  @override
  String get attListType => 'Typ';

  @override
  String get attListUnknownConductor => 'Unbekannter Dirigent';

  @override
  String get attListUnknownSong => 'Unbekanntes Lied';

  @override
  String get attendanceAdd => 'Hinzufügen';

  @override
  String get attendanceAddNote => 'Notiz hinzufügen';

  @override
  String get attendanceAddPeopleFailed => 'Fehler beim Hinzufügen der Personen';

  @override
  String get attendanceAddPerson => 'Person hinzufügen';

  @override
  String attendanceAddPersonsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen hinzufügen',
      one: '$count Person hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String get attendanceAddTodo => 'To-Do hinzufügen';

  @override
  String get attendanceAddTopics => 'Themen aufnehmen';

  @override
  String get attendanceAddingPeople => 'Personen werden hinzugefügt...';

  @override
  String get attendanceAddressPlaceholder => 'Adresse oder Ortsname';

  @override
  String get attendanceAllAlreadyIncluded => 'Alle Personen sind bereits in dieser Anwesenheit enthalten.';

  @override
  String get attendanceAssign => 'Einteilen';

  @override
  String get attendanceAssignPerson => 'Person einteilen';

  @override
  String attendanceAssignedNotified(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eingeteilt, die Personen werden benachrichtigt',
      one: 'Eingeteilt, die Person wird benachrichtigt',
    );
    return '$_temp0';
  }

  @override
  String attendanceAtTime(Object time) {
    return ' um $time Uhr';
  }

  @override
  String get attendanceAttachmentUploaded => 'Anhang hochgeladen';

  @override
  String get attendanceAvailable => 'Verfügbar';

  @override
  String attendanceCannotWithNote(Object note) {
    return 'Kann nicht: $note';
  }

  @override
  String get attendanceChangeConductor => 'Dirigent ändern';

  @override
  String get attendanceChangeFolder => 'Ordner ändern';

  @override
  String attendanceChangedOn(Object date) {
    return '· geändert am $date';
  }

  @override
  String get attendanceChecklist => 'Checkliste';

  @override
  String get attendanceChecklistRestored => 'Checkliste wiederhergestellt';

  @override
  String get attendanceChoose => 'Wählen';

  @override
  String get attendanceChoosePeople => 'Personen auswählen';

  @override
  String get attendanceChoosePersonMin => 'Bitte wähle mindestens eine Person aus';

  @override
  String get attendanceChurchOverview => 'Gemeinde-Übersicht';

  @override
  String get attendanceClearFilter => 'Filter löschen';

  @override
  String get attendanceConfirmed => 'bestätigt';

  @override
  String get attendanceConnectionRestored => 'Verbindung wiederhergestellt';

  @override
  String get attendanceCreateRunSheet => 'Ablaufplan erstellen';

  @override
  String attendanceCurrentNote(Object note) {
    return 'Aktuell: $note';
  }

  @override
  String get attendanceCustomNote => 'Eigene Notiz';

  @override
  String get attendanceCustomNoteEllipsis => 'Eigene Notiz...';

  @override
  String get attendanceDate => 'Datum';

  @override
  String get attendanceDeadlineDate => 'Fristdatum';

  @override
  String get attendanceDeadlineHelper => 'Personen können sich nur bis zu diesem Datum anmelden. Eine Abmeldung ist weiterhin möglich.';

  @override
  String get attendanceDeadlineHours => 'Deadline in Stunden (optional)';

  @override
  String get attendanceDeclined => 'abgesagt';

  @override
  String get attendanceDefaultSortGroup => 'Standard (Gruppe)';

  @override
  String get attendanceDeleteNote => 'Notiz löschen';

  @override
  String get attendanceDeleteTodo => 'To-Do löschen';

  @override
  String get attendanceDeleteTodoConfirm => 'Möchtest du dieses To-Do wirklich löschen?';

  @override
  String get attendanceDeletedByOther => 'Die Anwesenheit wurde soeben von einem anderen Nutzer gelöscht';

  @override
  String get attendanceDescriptionAttachment => 'Beschreibung & Anhang';

  @override
  String get attendanceDescriptionPlaceholder => 'Beschreibung eingeben...';

  @override
  String get attendanceDraft => 'Entwurf';

  @override
  String attendanceDraftEdited(Object date) {
    return 'Entwurf · zuletzt bearbeitet $date Uhr';
  }

  @override
  String get attendanceDueNow => 'Jetzt fällig';

  @override
  String attendanceDueOn(Object date) {
    return '· fällig $date';
  }

  @override
  String get attendanceEditDescription => 'Beschreibung & Anhang bearbeiten';

  @override
  String get attendanceEditRegFields => 'Anmeldefelder bearbeiten';

  @override
  String get attendanceEditRunSheet => 'Ablaufplan bearbeiten';

  @override
  String get attendanceEmailLink => 'Link in der E-Mail';

  @override
  String get attendanceEnd => 'Ende';

  @override
  String get attendanceEnterNote => 'Notiz eingeben...';

  @override
  String get attendanceEnterText => 'Bitte einen Text eingeben';

  @override
  String get attendanceEventFallback => 'Termin';

  @override
  String attendanceEventOnDate(Object type, Object date) {
    return '$type am $date';
  }

  @override
  String get attendanceExplicitStatus => 'Explizite Statusauswahl';

  @override
  String get attendanceExplicitStatusHint => 'Status über Dropdown statt Antippen wählen';

  @override
  String get attendanceExportExcel => 'Anwesenheit als Excel exportieren';

  @override
  String get attendanceExportPdf => 'Exportieren (PDF)';

  @override
  String get attendanceExportPdfA5 => 'Exportieren (PDF 2x A5)';

  @override
  String get attendanceFewerPeopleNeeded => 'Weniger Personen benötigt';

  @override
  String get attendanceFilesFolder => 'Ordner in der Dateiablage';

  @override
  String get attendanceFilesFolderHint => 'z. B. Aufnahmen des Termins';

  @override
  String attendanceFilterActive(Object count) {
    return '$count aktiv';
  }

  @override
  String get attendanceFlutterA4Standard => 'A4 (Standard)';

  @override
  String get attendanceFlutterA5OnA4 => '2x A5 auf A4';

  @override
  String get attendanceFlutterAddAttachment => 'Anhang hinzufügen';

  @override
  String get attendanceFlutterAddPhoto => 'Foto hinzufügen';

  @override
  String get attendanceFlutterAsImage => 'Als Bild';

  @override
  String attendanceFlutterAttendancesCount(Object count) {
    return '$count Anwesenheiten';
  }

  @override
  String get attendanceFlutterCalendar => 'Kalender';

  @override
  String get attendanceFlutterCamera => 'Kamera';

  @override
  String get attendanceFlutterChooseDeadline => 'Anmeldefrist wählen';

  @override
  String get attendanceFlutterChooseType => 'Bitte wähle einen Veranstaltungstyp';

  @override
  String get attendanceFlutterCreatingExcel => 'Erstelle Excel-Export...';

  @override
  String get attendanceFlutterDataUnavailable => 'Daten nicht verfügbar';

  @override
  String get attendanceFlutterDeadlineDisabled => 'Anmeldefrist deaktiviert';

  @override
  String get attendanceFlutterDeadlineEnabled => 'Anmeldefrist aktiviert';

  @override
  String get attendanceFlutterDeadlineUpdated => 'Anmeldefrist aktualisiert';

  @override
  String get attendanceFlutterDeleteTodoTitle => 'To-Do löschen?';

  @override
  String get attendanceFlutterEndAfterStart => 'Ende muss nach Beginn liegen';

  @override
  String get attendanceFlutterEndTime => 'Endzeit';

  @override
  String get attendanceFlutterEndTimeUpdated => 'Endzeit aktualisiert';

  @override
  String attendanceFlutterErrorWith(Object error) {
    return 'Fehler: $error';
  }

  @override
  String attendanceFlutterEventsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine',
      one: '$count Termin',
    );
    return '$_temp0';
  }

  @override
  String get attendanceFlutterExcusedShort => 'Entsch.';

  @override
  String get attendanceFlutterExportFormat => 'Export-Format';

  @override
  String get attendanceFlutterGallery => 'Galerie';

  @override
  String get attendanceFlutterHoliday => 'Feiertag';

  @override
  String get attendanceFlutterListLoadFailed => 'Die Anwesenheitsliste konnte nicht geladen werden.';

  @override
  String get attendanceFlutterLoadError => 'Fehler beim Laden';

  @override
  String get attendanceFlutterNoAccount => 'Die Person hat keinen Account';

  @override
  String get attendanceFlutterNoEntry => 'Kein Anwesenheitseintrag gefunden';

  @override
  String get attendanceFlutterNoEventTypes => 'Keine Veranstaltungstypen konfiguriert';

  @override
  String get attendanceFlutterNoItemsToExport => 'Keine Programmpunkte zum Exportieren';

  @override
  String get attendanceFlutterNoItemsToSend => 'Keine Programmpunkte zum Senden';

  @override
  String get attendanceFlutterNoPermission => 'Keine Berechtigung';

  @override
  String get attendanceFlutterNoPlanToExport => 'Kein Ablaufplan zum Exportieren';

  @override
  String get attendanceFlutterNoPlanToSend => 'Kein Ablaufplan zum Senden';

  @override
  String get attendanceFlutterNoTodos => 'Keine To-Dos vorhanden';

  @override
  String get attendanceFlutterNotFound => 'Anwesenheit nicht gefunden';

  @override
  String get attendanceFlutterNoteDeleted => 'Notiz gelöscht';

  @override
  String get attendanceFlutterNotesOptional => 'Notizen (optional)';

  @override
  String get attendanceFlutterOnePlanPerPage => 'Ein Plan pro Seite';

  @override
  String get attendanceFlutterOpen => 'Offen';

  @override
  String get attendanceFlutterPhoto => 'Foto';

  @override
  String get attendanceFlutterPhotoUploaded => 'Foto hochgeladen';

  @override
  String get attendanceFlutterPlanNotShared => 'Plan wird nicht mehr geteilt';

  @override
  String get attendanceFlutterPlanSentTelegram => 'Plan per Telegram gesendet';

  @override
  String get attendanceFlutterPlanShared => 'Plan wird jetzt mit Mitgliedern geteilt';

  @override
  String get attendanceFlutterQuickPreview => 'Für schnelle Vorschau';

  @override
  String get attendanceFlutterRecordAttendance => 'Anwesenheit erfassen';

  @override
  String get attendanceFlutterRegFieldsSaved => 'Anmeldefelder gespeichert';

  @override
  String get attendanceFlutterRemoveAttachment => 'Anhang entfernen';

  @override
  String get attendanceFlutterRestoreChecklistMessage => 'Die aktuelle Checkliste wird durch die Standard-Checkliste ersetzt.';

  @override
  String get attendanceFlutterRestoreChecklistTitle => 'Checkliste wiederherstellen?';

  @override
  String attendanceFlutterSaveFailedWith(Object error) {
    return 'Fehler beim Speichern: $error';
  }

  @override
  String get attendanceFlutterSchoolHolidays => 'Schulferien';

  @override
  String get attendanceFlutterSelectDate => 'Datum auswählen';

  @override
  String attendanceFlutterSendFailedWith(Object error) {
    return 'Fehler beim Senden: $error';
  }

  @override
  String attendanceFlutterShowAllCount(Object count) {
    return 'Alle $count anzeigen';
  }

  @override
  String get attendanceFlutterShowLess => 'Weniger anzeigen';

  @override
  String get attendanceFlutterSongRemoved => 'Werk entfernt';

  @override
  String get attendanceFlutterStandardFormat => 'Standard-Format';

  @override
  String get attendanceFlutterStartTimeUpdated => 'Startzeit aktualisiert';

  @override
  String get attendanceFlutterTelegramNotConnected => 'Telegram nicht verbunden. Bitte zuerst in den Einstellungen verbinden.';

  @override
  String get attendanceFlutterTodoAdded => 'To-Do hinzugefügt';

  @override
  String get attendanceFlutterTodoDeleted => 'To-Do gelöscht';

  @override
  String get attendanceFlutterTwoIdenticalPlans => 'Zwei identische Pläne (Querformat)';

  @override
  String get attendanceFlutterTwoPlansOnePage => 'Zwei Pläne auf einer Seite';

  @override
  String attendanceFlutterUploadFailedWith(Object error) {
    return 'Fehler beim Hochladen: $error';
  }

  @override
  String get attendanceFlutterUploadingPhoto => 'Lade Foto hoch...';

  @override
  String get attendanceGeneral => 'Allgemein';

  @override
  String attendanceInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Tagen',
      one: 'in $count Tag',
    );
    return '$_temp0';
  }

  @override
  String attendanceInHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Stunden',
      one: 'in $count Stunde',
    );
    return '$_temp0';
  }

  @override
  String get attendanceInfoText => 'Info-Text';

  @override
  String attendanceLastChangedBy(Object name) {
    return 'Zuletzt geändert von $name';
  }

  @override
  String attendanceLastChangedByAt(Object name, Object date, Object time) {
    return 'Zuletzt geändert von $name am $date um $time Uhr';
  }

  @override
  String get attendanceLateExcusedParen => 'Verspätet (entsch.)';

  @override
  String get attendanceLoadFailed => 'Anwesenheitsliste konnte nicht geladen werden';

  @override
  String get attendanceLoadFailedReopen => 'Anwesenheit konnte nicht geladen werden — bitte erneut öffnen.';

  @override
  String get attendanceLoadPeopleFailed => 'Fehler beim Laden der Personen';

  @override
  String get attendanceLoadingPeople => 'Lade Personen...';

  @override
  String get attendanceMatchingPeople => 'Passende Personen';

  @override
  String get attendanceMessage => 'Nachricht';

  @override
  String get attendanceMessagePlaceholder => 'Nachrichtentext';

  @override
  String attendanceMinutesShort(Object min) {
    return '$min min';
  }

  @override
  String get attendanceMorePeopleNeeded => 'Mehr Personen benötigt';

  @override
  String attendanceNeeded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '$count Person',
    );
    return 'Benötigt: $_temp0';
  }

  @override
  String get attendanceNoConnection => 'Keine Internetverbindung vorhanden';

  @override
  String get attendanceNoDefaultChecklist => 'Keine Standard-Checkliste vorhanden';

  @override
  String get attendanceNoGroup => 'Keine Gruppe';

  @override
  String get attendanceNoPeople => 'Keine Personen vorhanden';

  @override
  String get attendanceNobodyAssigned => 'Niemand zugewiesen';

  @override
  String get attendanceNotStarted => 'Noch nicht begonnen';

  @override
  String get attendanceNoteAdded => 'Notiz hinzugefügt';

  @override
  String get attendanceNotes => 'Notizen';

  @override
  String get attendanceOffline => 'Offline';

  @override
  String get attendanceOnlyNeutral => 'Nur Personen ohne Status';

  @override
  String get attendanceOnlyNeutralHint => 'Sendet nur an Personen, die noch keine Rückmeldung gegeben haben';

  @override
  String get attendanceOpenProtocol => 'Protokoll öffnen';

  @override
  String get attendanceOtherPeople => 'Andere Personen';

  @override
  String attendanceOverdueDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage überfällig',
      one: '$count Tag überfällig',
    );
    return '$_temp0';
  }

  @override
  String attendanceOverdueHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden überfällig',
      one: '$count Stunde überfällig',
    );
    return '$_temp0';
  }

  @override
  String attendancePending(Object count) {
    return '$count ausstehend';
  }

  @override
  String attendancePeopleAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen hinzugefügt',
      one: '$count Person hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get attendancePersonRemoveFailed => 'Fehler beim Entfernen der Person';

  @override
  String get attendancePersonRemoved => 'Person aus Anwesenheit entfernt';

  @override
  String get attendancePictureFailed => 'Fehler beim hinzufügen des Bildes, versuche es später erneut';

  @override
  String get attendancePlace => 'Ort';

  @override
  String get attendancePresentPeople => 'Anwesende';

  @override
  String get attendanceProtocol => 'Protokoll';

  @override
  String get attendancePublished => 'Freigegeben';

  @override
  String attendancePublishedOn(Object date) {
    return 'Freigegeben am $date';
  }

  @override
  String get attendanceReadProtocol => 'Protokoll lesen';

  @override
  String get attendanceRegFields => 'Anmeldefelder';

  @override
  String attendanceRegularlyUnavailableWithReason(Object reason) {
    return 'Regelmäßig verhindert: $reason';
  }

  @override
  String get attendanceReload => 'Neu laden';

  @override
  String get attendanceReloadFailed => 'Neu laden fehlgeschlagen — bitte erneut versuchen.';

  @override
  String get attendanceReminderInfo => 'Die Erinnerung wird per App-Benachrichtigung und per E-Mail verschickt. Betreff und Nachricht können frei angepasst werden.';

  @override
  String get attendanceReminderSent => 'Erinnerung versendet';

  @override
  String attendanceReminderTitle(Object event) {
    return '🔔 Erinnerung: $event';
  }

  @override
  String get attendanceRemoveFolder => 'Ordner entfernen';

  @override
  String get attendanceRemovePerson => 'Person entfernen';

  @override
  String attendanceRemovePersonConfirm(Object name) {
    return 'Möchtest du $name wirklich aus dieser Anwesenheit entfernen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get attendanceRequested => 'angefragt';

  @override
  String get attendanceResetChecklist => 'Checkliste zurücksetzen';

  @override
  String get attendanceRunSheetAgenda => 'Ablaufplan & Tagesordnung';

  @override
  String get attendanceSelfSignedUp => 'selbst eingetragen';

  @override
  String get attendanceSend => 'Versenden';

  @override
  String get attendanceSendFailed => 'Fehler beim Versenden';

  @override
  String get attendanceSendReminder => 'Erinnerung versenden';

  @override
  String get attendanceSendReminderShort => 'Erinnerung senden';

  @override
  String get attendanceSending => 'Wird versendet...';

  @override
  String get attendanceSetDeadline => 'Anmeldefrist setzen';

  @override
  String get attendanceSetNeutral => 'Status neutral setzen';

  @override
  String get attendanceShare => 'Teilen';

  @override
  String get attendanceShareRunSheet => 'Ablaufplan teilen';

  @override
  String get attendanceShowPictures => 'Bilder anzeigen';

  @override
  String get attendanceShowRegFields => 'Anmeldefelder anzeigen';

  @override
  String get attendanceSignedOut => 'abgemeldet';

  @override
  String attendanceSongsCount(Object count) {
    return 'Werke ($count)';
  }

  @override
  String get attendanceSorting => 'Sortierung';

  @override
  String get attendanceStaffing => 'Besetzung';

  @override
  String get attendanceStart => 'Beginn';

  @override
  String get attendanceStartChecklist => 'Checkliste starten';

  @override
  String get attendanceStartLabel => 'Start';

  @override
  String get attendanceStartSession => 'Sitzung starten & protokollieren';

  @override
  String get attendanceStatusChangeFailed => 'Fehler beim Ändern des Anwesenheitsstatus, bitte versuche es später erneut';

  @override
  String get attendanceStatusFilter => 'Status-Filter';

  @override
  String get attendanceStatusNotChanged => 'Der Status wurde bisher nicht verändert';

  @override
  String get attendanceStatusOverview => 'Status-Übersicht';

  @override
  String get attendanceSubject => 'Betreff';

  @override
  String get attendanceSubjectPlaceholder => 'z. B. 🔔 Erinnerung: Probe am 01.09.2026';

  @override
  String get attendanceTasksFromEvent => 'Aufgaben aus diesem Termin';

  @override
  String get attendanceTelegramImage => 'Per Telegram senden (Bild)';

  @override
  String get attendanceTelegramPdf => 'Per Telegram senden (PDF)';

  @override
  String get attendanceTelegramPdfA5 => 'Per Telegram senden (PDF 2x A5)';

  @override
  String attendanceTimeOClock(Object time) {
    return '$time Uhr';
  }

  @override
  String get attendanceToSong => 'Zum Werk';

  @override
  String get attendanceTodoText => 'To-Do Text...';

  @override
  String attendanceTotalPeople(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '$count Person',
    );
    return 'Gesamt: $_temp0';
  }

  @override
  String get attendanceTryAgain => 'Bitte versuche es erneut.';

  @override
  String get attendanceUnassign => 'Austragen';

  @override
  String get attendanceUnassignConfirm => 'Aus dem Dienst austragen?';

  @override
  String get attendanceUploadFailed => 'Fehler beim Hochladen';

  @override
  String get attendanceView => 'Ansicht';

  @override
  String get attendanceWhoChanged => 'Wer hat geändert?';

  @override
  String audioPlayFailed(Object error) {
    return 'Fehler beim Abspielen: $error';
  }

  @override
  String get authConfirmEmailFirst => 'Bitte bestätige zuerst deine E-Mail-Adresse.';

  @override
  String get authConfirmationResent => 'Bestätigungs-E-Mail wurde erneut gesendet';

  @override
  String get authInvalidCredentials => 'Ungültige Anmeldedaten';

  @override
  String get authResendConfirmationFailed => 'Fehler beim Senden der Bestätigungs-E-Mail';

  @override
  String get authResetFailed => 'Fehler beim Zurücksetzen des Passworts';

  @override
  String get authResetRetry => 'Fehler beim zurücksetzen, versuche es noch einmal';

  @override
  String get authResetSent => 'E-Mail zum Zurücksetzen des Passworts wurde gesendet';

  @override
  String get authUserNotFound => 'Benutzer nicht gefunden';

  @override
  String get bellCurrentInstance => 'Aktuelle Instanz';

  @override
  String get bellDeleteAll => 'Alle löschen';

  @override
  String get bellDeleteAllHeader => 'Alle Benachrichtigungen löschen?';

  @override
  String get bellDeleteAllMessage => 'Alle Benachrichtigungen aus allen Instanzen werden gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get bellMark => 'Markieren';

  @override
  String get bellMarkAllHeader => 'Alle als gelesen markieren?';

  @override
  String get bellMarkAllMessage => 'Alle Benachrichtigungen aus allen Instanzen werden als gelesen markiert.';

  @override
  String get bellMarkAllRead => 'Alle gelesen';

  @override
  String get bellNone => 'Keine Benachrichtigungen';

  @override
  String get bellNoneAvailable => 'Keine Benachrichtigungen vorhanden.';

  @override
  String get bellTitle => 'Benachrichtigungen';

  @override
  String get brandingFlutterReplaceLogo => 'Logo ersetzen';

  @override
  String get brandingFlutterUploadLogo => 'Logo hochladen';

  @override
  String get brandingIntro => 'Logo und Text erscheinen dezent auf exportierten Plänen und Listen (PDF/Bild). Das Logo darf maximal 2 MB groß sein. Das Branding gilt für alle Instanzen der Organisation.';

  @override
  String get brandingLogo => 'Logo';

  @override
  String get brandingLogoRemoved => 'Logo entfernt. Speichern nicht vergessen.';

  @override
  String get brandingLogoTooBig => 'Das Logo darf maximal 2MB groß sein.';

  @override
  String get brandingLogoUploaded => 'Logo hochgeladen. Speichern nicht vergessen.';

  @override
  String get brandingOrgOnly => 'Branding wird auf Organisationsebene verwaltet. Diese Instanz ist keiner Organisation zugeordnet.';

  @override
  String get brandingRemoveLogo => 'Logo entfernen';

  @override
  String get brandingSaved => 'Branding gespeichert.';

  @override
  String get brandingSaving => 'Branding wird gespeichert...';

  @override
  String get brandingSelectImage => 'Bitte wähle eine Bilddatei aus.';

  @override
  String get brandingText => 'Branding-Text';

  @override
  String get brandingTextPh => 'z.B. Verbandsname';

  @override
  String get churchOverviewChurches => 'Gemeinden';

  @override
  String get churchOverviewNoChurch => 'Ohne Gemeinde';

  @override
  String get churchOverviewNoPeople => 'Keine Personen vorhanden';

  @override
  String get churchOverviewTitle => 'Gemeinde-Übersicht';

  @override
  String get churchOverviewTotal => 'Gesamt';

  @override
  String get churchOverviewUnassigned => 'Ohne Zuordnung';

  @override
  String get churchOverviewUnknownChurch => 'Unbekannte Gemeinde';

  @override
  String get commonAll => 'Alle';

  @override
  String get commonAppleMaps => 'Apple Karten';

  @override
  String get commonApply => 'Übernehmen';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonCannotUndo => 'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get commonClefC => 'Altschlüssel';

  @override
  String get commonClefF => 'Bassschlüssel';

  @override
  String get commonClefG => 'Violinschlüssel';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonCreate => 'Anlegen';

  @override
  String commonCreatedAt(Object date) {
    return 'Erstellt am: $date';
  }

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonError => 'Fehler';

  @override
  String get commonGroupLabelGroup => 'Gruppe';

  @override
  String get commonGroupLabelInstrument => 'Instrument';

  @override
  String get commonGroupLabelVoice => 'Stimme';

  @override
  String get commonHistoryArchived => 'Archiviert';

  @override
  String get commonHistoryGroupChange => 'Wechsel';

  @override
  String get commonHistoryPaused => 'Pausiert';

  @override
  String get commonHistoryReturned => 'Reaktiviert';

  @override
  String get commonHistoryUnexcused => 'Unentschuldigt';

  @override
  String get commonIntlLocale => 'de-DE';

  @override
  String get commonLoading => 'Wird geladen …';

  @override
  String get commonNext => 'Weiter';

  @override
  String get commonNgDate => 'dd.MM.yyyy';

  @override
  String get commonNgDayMonth => 'dd.MM.';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonOk => 'OK';

  @override
  String get commonOpen => 'Öffnen';

  @override
  String get commonOther => 'Sonstiges';

  @override
  String get commonOtherPlural => 'Sonstige';

  @override
  String get commonPeople => 'Personen';

  @override
  String commonPersons(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '$count Person',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get commonRolesAdmin => 'Admin';

  @override
  String get commonRolesHelper => 'Helfer';

  @override
  String get commonRolesMember => 'Mitglied';

  @override
  String get commonRolesParent => 'Elternteil';

  @override
  String get commonRolesResponsible => 'Verantwortlicher';

  @override
  String get commonRolesViewer => 'Beobachter';

  @override
  String get commonRolesVoiceLeader => 'Stimmführer';

  @override
  String get commonRolesVoiceLeaderHelper => 'Stimmführer & Helfer';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonStatusAbsent => 'Abwesend';

  @override
  String get commonStatusAccepted => 'Zugesagt';

  @override
  String get commonStatusExcused => 'Entschuldigt';

  @override
  String get commonStatusLate => 'Verspätet anwesend';

  @override
  String get commonStatusLateExcused => 'Verspätet entschuldigt';

  @override
  String get commonStatusLateExcusedShort => 'Verspätet entsch.';

  @override
  String get commonStatusLateReported => 'Verspätung gemeldet';

  @override
  String get commonStatusLateShort => 'Verspätet';

  @override
  String get commonStatusNeutral => 'Neutral';

  @override
  String get commonStatusPresent => 'Anwesend';

  @override
  String get commonUnknown => 'Unbekannt';

  @override
  String get commonUnknownError => 'Unbekannter Fehler';

  @override
  String commonWithout(Object list) {
    return 'Ohne $list';
  }

  @override
  String get commonYes => 'Ja';

  @override
  String get coreFlutterAccessDenied => 'Zugriff verweigert';

  @override
  String get coreFlutterDifficultyEasy => 'Leicht';

  @override
  String get coreFlutterDifficultyHard => 'Schwer';

  @override
  String get coreFlutterDifficultyMedium => 'Mittel';

  @override
  String get coreFlutterDifficultyVeryHard => 'Sehr schwer';

  @override
  String coreFlutterErrorWith(Object error) {
    return 'Fehler: $error';
  }

  @override
  String coreFlutterExportAttendanceHeader(Object name, Object date) {
    return '$name Anwesenheit Stand: $date';
  }

  @override
  String coreFlutterExportEndAt(Object time) {
    return 'Ende: $time Uhr';
  }

  @override
  String get coreFlutterExportOpen => 'Offen';

  @override
  String get coreFlutterExportPdfRenderFailed => 'PDF konnte nicht gerendert werden';

  @override
  String coreFlutterExportPlayerListHeader(Object name, Object date) {
    return '$name Spielerliste Stand: $date';
  }

  @override
  String get coreFlutterExportPlayerListSheet => 'Spielerliste';

  @override
  String get coreFlutterExportRate => 'Quote';

  @override
  String get coreFlutterExportRehearsalProgramme => 'Probenprogramm';

  @override
  String get coreFlutterFeedbackAnonymousHint => 'Deine Daten werden nicht mitgesendet';

  @override
  String get coreFlutterFeedbackQuestionIntro => 'Hast du eine Frage oder brauchst Hilfe?';

  @override
  String get coreFlutterFeedbackQuestionRequired => 'Bitte gib eine Frage ein';

  @override
  String get coreFlutterFeedbackRatingIntro => 'Wie gefällt dir die App?';

  @override
  String get coreFlutterFileBytesUnavailable => 'Datei-Bytes nicht verfügbar';

  @override
  String get coreFlutterFilePathUnavailable => 'Dateipfad nicht verfügbar';

  @override
  String get coreFlutterHistoryApproved => 'Genehmigt';

  @override
  String get coreFlutterHistoryCopiedFrom => 'Kopiert von';

  @override
  String get coreFlutterHistoryCopiedTo => 'Kopiert an';

  @override
  String get coreFlutterHistoryCritical => 'Kritisch markiert';

  @override
  String get coreFlutterHistoryDeclined => 'Abgelehnt';

  @override
  String get coreFlutterHistoryInstrumentChange => 'Instrumentenwechsel';

  @override
  String get coreFlutterHistoryReturned => 'Zurückgekehrt';

  @override
  String get coreFlutterHistoryTransferredFrom => 'Übertragen von';

  @override
  String get coreFlutterHistoryTransferredTo => 'Übertragen an';

  @override
  String get coreFlutterHistoryUnpaused => 'Pause beendet';

  @override
  String get coreFlutterHoliday => 'Feiertag';

  @override
  String coreFlutterImportBirthdayUnreadable(Object value) {
    return 'Geburtsdatum \"$value\" konnte nicht gelesen werden';
  }

  @override
  String coreFlutterImportCategoryNotFound(Object name) {
    return 'Kategorie \"$name\" nicht gefunden';
  }

  @override
  String coreFlutterImportDifficultyInvalid(Object value) {
    return 'Schwierigkeit \"$value\" muss 1, 2 oder 3 sein';
  }

  @override
  String get coreFlutterImportDuplicateEmailInFile => 'Doppelte E-Mail in der Datei';

  @override
  String get coreFlutterImportDuplicateNumberInFile => 'Doppelte Nummer in der Datei';

  @override
  String get coreFlutterImportEmailExists => 'E-Mail existiert bereits in dieser Instanz';

  @override
  String coreFlutterImportEmailInvalid(Object email) {
    return 'E-Mail \"$email\" sieht ungültig aus';
  }

  @override
  String coreFlutterImportJoinedUnreadable(Object value) {
    return 'Eintrittsdatum \"$value\" konnte nicht gelesen werden';
  }

  @override
  String coreFlutterImportLinkInvalid(Object link) {
    return 'Link \"$link\" sieht ungültig aus';
  }

  @override
  String get coreFlutterImportNameRequired => 'Vor- und Nachname sind erforderlich';

  @override
  String get coreFlutterImportNumberRequired => 'Nummer ist erforderlich und muss eine Zahl sein';

  @override
  String get coreFlutterImportSongNameRequired => 'Name ist erforderlich';

  @override
  String get coreFlutterImportSongNumberExists => 'Liednummer existiert bereits in dieser Instanz';

  @override
  String get coreFlutterInvalidCopyCount => 'Ungültige Kopienanzahl';

  @override
  String get coreFlutterLoadFailed => 'Fehler beim Laden';

  @override
  String get coreFlutterNewVersionAvailable => 'Neue Version verfügbar';

  @override
  String get coreFlutterNoBranding => 'Kein Branding';

  @override
  String get coreFlutterNoConnection => 'Keine Internetverbindung vorhanden';

  @override
  String get coreFlutterNoCopiesSelected => 'Keine Kopien zum Drucken ausgewählt';

  @override
  String get coreFlutterNoEmailAddress => 'Keine E-Mail-Adresse vorhanden';

  @override
  String get coreFlutterNoFilesDownloaded => 'Keine Dateien konnten heruntergeladen werden';

  @override
  String get coreFlutterNoFilesToDownload => 'Keine Dateien zum Herunterladen';

  @override
  String get coreFlutterNoInstanceSelected => 'Keine Instanz ausgewählt';

  @override
  String get coreFlutterNoResponse => 'Keine Antwort erhalten';

  @override
  String coreFlutterNoResultsFor(Object query) {
    return 'Keine Ergebnisse für \"$query\"';
  }

  @override
  String get coreFlutterNoTenantSelected => 'Kein Tenant ausgewählt';

  @override
  String get coreFlutterNoVersionHistory => 'Keine Versionshistorie verfügbar';

  @override
  String get coreFlutterNotLoggedIn => 'Nicht eingeloggt';

  @override
  String get coreFlutterNotSignedIn => 'Nicht angemeldet';

  @override
  String get coreFlutterOfflineQueueSaveFailed => 'Die Änderung konnte nicht offline gespeichert werden';

  @override
  String get coreFlutterOpenExternally => 'Extern öffnen';

  @override
  String get coreFlutterPausedLower => 'pausiert';

  @override
  String coreFlutterPausedUntil(Object date) {
    return 'bis $date';
  }

  @override
  String coreFlutterPdfLoadFailed(Object status) {
    return 'PDF konnte nicht geladen werden (HTTP $status)';
  }

  @override
  String get coreFlutterPersonHasNoId => 'Person hat keine ID';

  @override
  String coreFlutterPlanDayN(Object day) {
    return 'Tag $day';
  }

  @override
  String coreFlutterPlanStartsInHours(Object hours) {
    return 'beginnt in $hours Std.';
  }

  @override
  String coreFlutterPlanStartsInHoursMin(Object hours, Object min) {
    return 'beginnt in $hours Std. $min Min.';
  }

  @override
  String coreFlutterPlanStartsInMin(Object min) {
    return 'beginnt in $min Min.';
  }

  @override
  String get coreFlutterPlanStartsSoon => 'beginnt gleich';

  @override
  String get coreFlutterRegistration => 'Anmeldung';

  @override
  String get coreFlutterRepoAccountCreateFailed => 'Der Account konnte nicht erstellt werden.';

  @override
  String get coreFlutterRepoAlreadyAdmin => 'Diese Person ist bereits Admin.';

  @override
  String get coreFlutterRepoCategoryCreateFailed => 'Kategorie konnte nicht erstellt werden';

  @override
  String coreFlutterRepoCategoryNotFound(Object id) {
    return 'Gruppenkategorie mit ID $id nicht gefunden';
  }

  @override
  String coreFlutterRepoChangeRoleFailed(Object error) {
    return 'Fehler beim Ändern der Rolle: $error';
  }

  @override
  String get coreFlutterRepoEventExistsOnDate => 'Ein Termin an diesem Datum existiert bereits';

  @override
  String get coreFlutterRepoEventNotInTenant => 'Termin gehört nicht zur aktuellen Instanz';

  @override
  String get coreFlutterRepoForeignTenantDenied => 'Zugriff auf fremde Instanz verweigert';

  @override
  String get coreFlutterRepoGroupCreateFailed => 'Gruppe konnte nicht erstellt werden';

  @override
  String coreFlutterRepoGroupHasPlayers(Object count) {
    return 'Gruppe kann nicht gelöscht werden: $count Spieler sind noch zugewiesen';
  }

  @override
  String coreFlutterRepoGroupNotFound(Object id) {
    return 'Gruppe mit ID $id nicht gefunden';
  }

  @override
  String get coreFlutterRepoMeetingExistsOnDate => 'Eine Besprechung an diesem Datum existiert bereits';

  @override
  String get coreFlutterRepoNoPermissionInTenant => 'Keine Berechtigung in dieser Instanz';

  @override
  String get coreFlutterRepoNoValidPersons => 'Keine gültigen Personen';

  @override
  String get coreFlutterRepoPersonsNotInTenant => 'Personen gehören nicht zur aktuellen Instanz';

  @override
  String get coreFlutterRepoRootNotDeletable => 'Root kann nicht gelöscht werden.';

  @override
  String get coreFlutterRepoSongNotFoundOrDenied => 'Song nicht gefunden oder Zugriff verweigert';

  @override
  String get coreFlutterRepoTenantNotLinked => 'Instanz ist nicht verknüpft';

  @override
  String coreFlutterRepoTypeInUse(Object count) {
    return 'Typ kann nicht gelöscht werden: Wird von $count Anwesenheit(en) verwendet';
  }

  @override
  String coreFlutterRepoUnlinkAccountFailed(Object error) {
    return 'Fehler beim Entfernen der Account-Verknüpfung: $error';
  }

  @override
  String get coreFlutterRolePermissionWithoutId => 'Rollenberechtigung ohne ID';

  @override
  String get coreFlutterRouterGoHome => 'Zur Startseite';

  @override
  String get coreFlutterRouterInvalidAttendanceId => 'Ungültige Anwesenheits-ID';

  @override
  String get coreFlutterRouterInvalidPersonId => 'Ungültige Person-ID';

  @override
  String get coreFlutterRouterInvalidTenantId => 'Ungültige Instanz-ID';

  @override
  String coreFlutterRouterPageNotFound(Object path) {
    return 'Seite nicht gefunden: $path';
  }

  @override
  String get coreFlutterRuleOverall => 'insgesamt';

  @override
  String get coreFlutterRuleSinceSeasonStart => 'seit Saisonstart';

  @override
  String coreFlutterRuleStatusN(Object n) {
    return 'Status $n';
  }

  @override
  String get coreFlutterSchoolHolidays => 'Schulferien';

  @override
  String get coreFlutterSearchHint => 'Suchen...';

  @override
  String get coreFlutterSheetMusic => 'Notenblatt';

  @override
  String coreFlutterShiftFreeRange(Object start, Object end) {
    return 'Frei ($start - $end)';
  }

  @override
  String coreFlutterShiftWorkRange(Object start, Object end, Object hours) {
    return 'Arbeit ($start - $end, ${hours}h)';
  }

  @override
  String get coreFlutterSongFiles => 'Song-Dateien';

  @override
  String get coreFlutterSongNotFound => 'Song wurde nicht gefunden oder bereits gelöscht';

  @override
  String get coreFlutterUpdate => 'Aktualisieren';

  @override
  String get coreFlutterVoices => 'Stimmen';

  @override
  String get coreFlutterXlsUnsupported => 'Das alte Excel-Format (.xls) wird nicht unterstützt. Bitte als .xlsx oder .csv speichern.';

  @override
  String get coreFlutterZipFailed => 'ZIP konnte nicht erstellt werden';

  @override
  String get dashSettingsCards => 'Karten';

  @override
  String get dashSettingsFlutterReorder => 'Reihenfolge ändern';

  @override
  String dashSettingsFlutterSaveFailed(Object error) {
    return 'Fehler beim Speichern: $error';
  }

  @override
  String get dashSettingsReorderHint => 'Tippe auf das Symbol oben rechts, um die Reihenfolge per Drag & Drop anzupassen.';

  @override
  String get dashSettingsReset => 'Zurücksetzen';

  @override
  String get dashSettingsShowTab => 'Dashboard-Tab anzeigen';

  @override
  String get dashSettingsTab => 'Tab';

  @override
  String get dateDialogChangeDate => 'Datum ändern';

  @override
  String get dateDialogChangeFailed => 'Datum konnte nicht geändert werden';

  @override
  String get dateDialogCreateFailed => 'Termin konnte nicht angelegt werden';

  @override
  String dateDialogCreated(Object date) {
    return 'Termin am $date angelegt';
  }

  @override
  String get dateDialogFromToday => 'Bitte ein Datum ab heute wählen';

  @override
  String get dateDialogKeep => 'Behalten';

  @override
  String get dateDialogLoadFailed => 'Termin konnte nicht geladen werden';

  @override
  String get dateDialogMoveTo => 'Auf welchen Tag soll der Termin verschoben werden?';

  @override
  String dateDialogMoved(Object date) {
    return 'Termin auf $date verschoben';
  }

  @override
  String get dateDialogNoProtocolType => 'Kein Termintyp mit Protokoll & Tagesordnung vorhanden';

  @override
  String get dateDialogReset => 'Zurücksetzen';

  @override
  String get dateDialogResetStatus => 'Status zurücksetzen?';

  @override
  String dateDialogResetStatusMessage(Object status) {
    return 'Nicht alle stehen auf „$status“. Sollen mit der Verschiebung alle auf den Standardstatus zurückgesetzt werden? Abwesenheiten am neuen Tag werden danach wieder eingetragen.';
  }

  @override
  String get dateDialogWhichDay => 'An welchem Tag findet der Termin statt?';

  @override
  String get dateDialogWhichType => 'Welcher Termintyp?';

  @override
  String get dbAccountDisabled => 'Dein Konto wurde deaktiviert. Bitte wende dich an den Administrator deiner Instanz.';

  @override
  String get dbAddDefaultTypesFailed => 'Fehler beim Hinzufügen der Standard Anwesenheitstypen';

  @override
  String get dbAddParentFailed => 'Fehler beim hinzufügen des Elternteils.';

  @override
  String get dbAddViewerFailed => 'Fehler beim hinzufügen des Beobachters.';

  @override
  String get dbChooseInstanceHeader => 'Instanz auswählen';

  @override
  String get dbChooseInstanceMessage => 'Bitte wähle die Instanz aus, die du öffnen möchtest:';

  @override
  String get dbCodeExpired => 'Der Code ist abgelaufen. Bitte fordere einen neuen an.';

  @override
  String get dbCodeInvalid => 'Der Code ist ungültig. Bitte überprüfe deine Eingabe.';

  @override
  String get dbCodeSendFailed => 'Der Code konnte nicht gesendet werden. Bitte versuche es erneut.';

  @override
  String get dbCodeSent => 'Wir haben dir einen Code per E-Mail gesendet.';

  @override
  String get dbCreateAccountFailed => 'Fehler beim Erstellen des Accounts';

  @override
  String dbCreateAccountFailedWith(Object error) {
    return 'Fehler beim Erstellen des Accounts: $error';
  }

  @override
  String get dbCreateInstanceFailed => 'Fehler beim Erstellen der Instanz, bitte versuche es später erneut.';

  @override
  String get dbCreateUserFailed => 'Fehler beim Erstellen des Benutzers, bitte versuche es später erneut.';

  @override
  String get dbDeleteAccountFailed => 'Fehler beim Löschen des Kontos';

  @override
  String get dbDeleteInstanceFailed => 'Fehler beim Löschen der Instanz, bitte versuche es später erneut.';

  @override
  String get dbDeleteParentFailed => 'Fehler beim Löschen des Elternteils';

  @override
  String get dbDeleteViewerFailed => 'Fehler beim Löschen des Beobachters';

  @override
  String get dbDemoRestricted => 'Diese Funktion ist im Demo-Modus nicht verfügbar.';

  @override
  String get dbEmailExists => 'Deine E-Mail-Adresse existiert bereits. Bitte melde dich an.';

  @override
  String get dbEnterCorrectData => 'Bitte gib die richtigen Daten an!';

  @override
  String get dbFavoriteFailed => 'Fehler beim Setzen des Favoriten, bitte versuche es später erneut.';

  @override
  String get dbInstanceCreated => 'Instanz wurde erfolgreich erstellt!';

  @override
  String get dbInstanceDeleted => 'Instanz wurde erfolgreich gelöscht!';

  @override
  String get dbInvalidEmail => 'Ungültige E-Mail Adresse';

  @override
  String get dbInvalidPassword => 'Ungültiges Passwort';

  @override
  String get dbLoadAttendanceTypeFailed => 'Fehler beim Laden des Anwesenheitstyps';

  @override
  String get dbLoadChildrenFailed => 'Fehler beim Laden der Kinder';

  @override
  String get dbLoadGroupMembersFailed => 'Fehler beim Laden der Gruppenteilnehmer';

  @override
  String get dbLoadPeopleFailed => 'Fehler beim Laden der Personen';

  @override
  String get dbLoadRoleFailed => 'Fehler beim Laden der Rolle';

  @override
  String get dbLoadTenantsFailed => 'Fehler beim Laden der Tenants';

  @override
  String get dbLoadTenantsFailed2 => 'Fehler beim Laden der Mandanten';

  @override
  String get dbLoadUserFailed => 'Fehler beim Laden des Benutzers';

  @override
  String get dbLoginFailed => 'Fehler beim Anmelden';

  @override
  String get dbMainGroupNotFound => 'Hauptgruppe nicht gefunden';

  @override
  String get dbNoAccount => 'Kein Konto mit dieser E-Mail-Adresse gefunden. Bitte registriere dich zuerst.';

  @override
  String get dbNoPersonFound => 'Keine Person gefunden';

  @override
  String get dbNotifyUserFailed => 'Fehler beim Informieren des Benutzers';

  @override
  String get dbOtpUnavailable => 'Anmeldung per Code ist derzeit nicht möglich.';

  @override
  String get dbPasswordChangeFailed => 'Passwort konnte nicht geändert werden. Bitte versuche es erneut.';

  @override
  String get dbPasswordSameAsOld => 'Das neue Passwort darf nicht mit dem alten übereinstimmen.';

  @override
  String get dbPasswordTooWeak => 'Das Passwort ist zu schwach. Bitte wähle ein sichereres Passwort.';

  @override
  String get dbPasswordUpdated => 'Passwort wurde erfolgreich aktualisiert';

  @override
  String get dbPauseOtherFailed => 'Fehler beim Pausieren in anderer Instanz';

  @override
  String dbPersonExistsWithEmail(Object email) {
    return 'In der Zielinstanz existiert bereits eine Person mit der E-Mail-Adresse \"$email\".';
  }

  @override
  String dbPersonExistsWithName(Object name) {
    return 'In der Zielinstanz existiert bereits eine Person mit dem Namen \"$name\".';
  }

  @override
  String get dbRegisterFailed => 'Fehler beim Registrieren';

  @override
  String get dbRemoveAuthEmailFailed => 'Fehler beim Entfernen der E-Mail aus der Authentifizierung';

  @override
  String get dbRemoveFromTenantFailed => 'Fehler beim Löschen des Accounts vom Mandanten';

  @override
  String get dbResetPasswordFailed => 'Fehler beim Zurücksetzen des Passworts. Versuche es später erneut';

  @override
  String get dbResetPasswordSent => 'Eine E-Mail mit weiteren Anweisungen wurde dir zugesandt';

  @override
  String get dbRoleParent => 'Elternteil';

  @override
  String get dbRoleViewer => 'Beobachter';

  @override
  String get dbSessionExpired => 'Deine Sitzung ist abgelaufen. Bitte fordere den Link zum Zurücksetzen erneut an.';

  @override
  String get dbTooManyAttempts => 'Zu viele Versuche. Bitte versuche es später erneut.';

  @override
  String get dbTooManyAttemptsWait => 'Zu viele Versuche. Bitte warte einen Moment und versuche es erneut.';

  @override
  String get dbTooManyLogins => 'Zu viele Anmeldeversuche. Bitte versuche es später erneut.';

  @override
  String get dbTooManyRequests => 'Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.';

  @override
  String get dbUpdateChurchFailed => 'Fehler beim Aktualisieren der Kirchenzuordnung';

  @override
  String get dbUpdatePlayerFailed => 'Fehler beim updaten des Spielers';

  @override
  String get dbUpdateProfileFailed => 'Fehler beim Aktualisieren des Profils';

  @override
  String get dbUpdateRoleFailed => 'Fehler beim Aktualisieren der Benutzerrolle';

  @override
  String get dbUpdateSongHistoryFailed => 'Fehler beim Aktualisieren des Song-Verlaufs';

  @override
  String get dbUpdateUserFailed => 'Fehler beim Updaten des Benutzers';

  @override
  String get dbUpdateUserFailed2 => 'Fehler beim updaten des Benutzers';

  @override
  String dbUserAlreadyInInstanceAs(Object name, Object role) {
    return 'Der Benutzer ist bereits in dieser Instanz: $name ($role)';
  }

  @override
  String get dbUserAlreadyInTenant => 'Der Benutzer ist bereits in diesem Mandanten';

  @override
  String dbUserAlreadyInTenantAs(Object name, Object role) {
    return 'Der Benutzer ist bereits in diesem Mandanten: $name ($role)';
  }

  @override
  String get dbWeakPasswordRequirements => 'Das Passwort erfüllt nicht die Sicherheitsanforderungen.';

  @override
  String get dbWrongCredentials => 'E-Mail oder Passwort falsch. Falls du kein Passwort gesetzt hast, nutze den Anmelde-Code per E-Mail.';

  @override
  String get defaultsShowAllInfoText => 'Du bist bei diesem Termin nicht dabei.';

  @override
  String get defaultsTypesMeeting => 'Treffen';

  @override
  String get defaultsTypesPerformance => 'Vortrag';

  @override
  String get defaultsTypesRehearsal => 'Probe';

  @override
  String get defaultsTypesRehearsalPlan => 'Probenplan';

  @override
  String get deleteAccountAccess => 'Dein Zugang zur App';

  @override
  String get deleteAccountAttendance => 'Alle deine Anwesenheitsdaten';

  @override
  String get deleteAccountCannotUndo => 'Diese Aktion kann <strong>nicht rückgängig</strong> gemacht werden.';

  @override
  String get deleteAccountCode => 'Bestätigungscode';

  @override
  String get deleteAccountCodePlaceholder => 'Code eingeben';

  @override
  String get deleteAccountConfirm => 'Konto wirklich löschen?';

  @override
  String get deleteAccountConfirmMessage => 'Dein Konto und alle damit verbundenen Daten werden unwiderruflich entfernt. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountDeleteFinal => 'Endgültig löschen';

  @override
  String get deleteAccountDeleteForever => 'Konto endgültig löschen';

  @override
  String get deleteAccountDeleted => 'Dein Konto wurde gelöscht.';

  @override
  String get deleteAccountDeleting => 'Konto wird gelöscht...';

  @override
  String get deleteAccountEnterCode => 'Bitte gib zur Bestätigung den folgenden Code ein:';

  @override
  String deleteAccountFailed(Object error) {
    return 'Fehler beim Löschen: $error';
  }

  @override
  String get deleteAccountIntro => 'Wenn du dein Konto löschst, werden <strong>alle</strong> deine Daten unwiderruflich entfernt:';

  @override
  String get deleteAccountMemberships => 'Alle deine Mitgliedschaften in jeder Instanz';

  @override
  String get deleteAccountProfile => 'Dein Profil und Passbild';

  @override
  String get deleteAccountTitle => 'Konto löschen';

  @override
  String get deleteAccountWarning => 'Achtung';

  @override
  String get dutyAddRule => 'Regel hinzufügen';

  @override
  String get dutyAllAssigned => 'Alle aus dem Personenkreis sind schon eingeteilt.';

  @override
  String get dutyAllTypes => 'alle Termintypen';

  @override
  String get dutyAllTypesHint => 'Ohne Auswahl gilt die Regel für alle Termintypen.';

  @override
  String get dutyAlsoPlanned => 'Auch geplante Termine?';

  @override
  String get dutyAlsoPlannedButton => 'Auch geplante';

  @override
  String dutyAlsoPlannedOther(num count, Object preview, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count schon geplante Termine passen',
      one: '$count schon geplanter Termin passt',
    );
    return '$_temp0 zu dieser Regel ($preview). Soll $name dort als entschuldigt eingetragen werden? Termine mit eigener Antwort oder Einteilung bleiben unverändert.';
  }

  @override
  String dutyAlsoPlannedSelf(num count, Object preview) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count schon geplante Termine passen',
      one: '$count schon geplanter Termin passt',
    );
    return '$_temp0 zu dieser Regel ($preview). Sollst du dort als entschuldigt eingetragen werden? Termine mit eigener Antwort oder Einteilung bleiben unverändert.';
  }

  @override
  String get dutyAssignHint => 'Sortiert nach Anzahl Dienste. Eingeteilte bekommen sofort eine Push-Nachricht und müssen bestätigen.';

  @override
  String dutyAssignName(Object name) {
    return '$name einteilen';
  }

  @override
  String dutyAssignPeople(Object count) {
    return '$count Personen einteilen';
  }

  @override
  String dutyAssignedToast(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dienste eingeteilt',
      one: '$count Dienst eingeteilt',
    );
    return '$_temp0. Alle bekommen eine Push-Nachricht.';
  }

  @override
  String get dutyAssigning => 'Teile ein…';

  @override
  String get dutyCalculate => 'Vorschlag berechnen';

  @override
  String get dutyChildrenHourPlaceholder => 'z. B. Kinderstunde';

  @override
  String get dutyChoosePerson => 'Person wählen';

  @override
  String get dutyChooseTypeMin => 'Bitte wähle mindestens einen Termintyp';

  @override
  String get dutyChooseWeekday => 'Bitte wähle mindestens einen Wochentag';

  @override
  String get dutyDeclinedToast => 'Abgesagt, das Team wird informiert.';

  @override
  String get dutyDeleteRule => 'Regel löschen';

  @override
  String get dutyDeleteRuleConfirm => 'Regel löschen?';

  @override
  String get dutyDeleteRuleMessage => 'Bereits eingetragene Abmeldungen bleiben bestehen.';

  @override
  String get dutyDistributeHint => 'Nur offene Plätze werden gefüllt, bestehende Einteilungen bleiben. Wer abgesagt hat oder regelmäßig verhindert ist, wird nicht eingeteilt. Wer bisher am wenigsten Dienste hat, kommt zuerst dran.';

  @override
  String get dutyDistributing => 'Verteile Dienste…';

  @override
  String dutyDutiesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dienste',
      one: '$count Dienst',
    );
    return '$_temp0';
  }

  @override
  String get dutyDutiesPerPerson => 'Dienste pro Person im Zeitraum';

  @override
  String get dutyDuty => 'Dienst';

  @override
  String get dutyEventTypes => 'Termintypen';

  @override
  String dutyEventsAdjusted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine angepasst',
      one: '$count Termin angepasst',
    );
    return '$_temp0';
  }

  @override
  String get dutyFlutterAllFilled => 'alles besetzt';

  @override
  String get dutyFlutterDeclineFailed => 'Fehler beim Abmelden';

  @override
  String get dutyFlutterDeleteFailed => 'Fehler beim Löschen';

  @override
  String dutyFlutterErrorWith(Object error) {
    return 'Fehler: $error';
  }

  @override
  String dutyFlutterNameRequested(Object name) {
    return '$name (angefragt)';
  }

  @override
  String get dutyFlutterNobodyAssigned => 'noch niemand eingeteilt';

  @override
  String get dutyFlutterNothingToDistribute => 'Nichts zu verteilen';

  @override
  String dutyFlutterPlannedNew(Object count) {
    return '(+$count neu)';
  }

  @override
  String dutyFlutterSaveAssignments(Object count) {
    return '$count Einteilungen speichern';
  }

  @override
  String dutyFlutterTimeOClock(Object time) {
    return '$time Uhr';
  }

  @override
  String dutyFlutterUnassignMessage(Object name) {
    return '$name ist dann nicht mehr eingeteilt.';
  }

  @override
  String get dutyForWhichTypes => 'Für welche Termintypen?';

  @override
  String get dutyFrom => 'Von';

  @override
  String get dutyGreyHint => 'Grau = schon eingeteilt, bleibt unverändert.';

  @override
  String dutyInMonth(Object month) {
    return ' im $month';
  }

  @override
  String get dutyMaxPerPerson => 'Höchstens pro Person';

  @override
  String get dutyMyRequestsTitle => 'Deine Dienste: bitte bestätigen';

  @override
  String get dutyNoDutyEvents => 'Im Zeitraum gibt es keine Termine mit Dienst-Modus.';

  @override
  String get dutyNoRuleOther => 'Noch keine Regel. Trag ein, an welchen Wochentagen die Person grundsätzlich nicht kann, z. B. mittwochs wegen der Kinderstunde.';

  @override
  String get dutyNoRuleSelf => 'Noch keine Regel. Trag ein, an welchen Wochentagen du grundsätzlich nicht kannst, z. B. mittwochs wegen der Kinderstunde.';

  @override
  String get dutyNobody => 'Niemand (Platz offen lassen)';

  @override
  String get dutyNobodyElse => 'Niemand sonst ist für diesen Termin verfügbar';

  @override
  String get dutyNotTwiceSameDay => 'Nicht zweimal am selben Tag';

  @override
  String get dutyOnlyNew => 'Nur neue Termine';

  @override
  String get dutyOpen => 'offen';

  @override
  String get dutyOverbooked => 'Du hast mehr Personen gewählt als Plätze frei sind. Der Dienst ist dann überbesetzt.';

  @override
  String get dutyPeriod => 'Zeitraum';

  @override
  String dutyPlacesFree(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Plätze frei',
      one: '$count Platz frei',
    );
    return '$_temp0';
  }

  @override
  String dutyPlannedSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einteilungen',
      one: '$count Einteilung',
    );
    return '$_temp0 geplant.';
  }

  @override
  String dutyPlannedSummaryMissing(num count, num missing) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einteilungen',
      one: '$count Einteilung',
    );
    String _temp1 = intl.Intl.pluralLogic(
      missing,
      locale: localeName,
      other: '$missing Plätze bleiben',
      one: '$missing Platz bleibt',
    );
    return '$_temp0 geplant, $_temp1 offen.';
  }

  @override
  String get dutyReasonOptional => 'Grund (optional)';

  @override
  String get dutyRedistribute => 'Neu verteilen';

  @override
  String get dutyRuleHint => 'Neue Termine an diesen Tagen werden automatisch als entschuldigt eingetragen. Bei Diensten wirst du dann nicht eingeteilt.';

  @override
  String get dutyRules => 'Regeln';

  @override
  String get dutySameDay => '· am selben Tag schon dran';

  @override
  String get dutySaved => 'Gespeichert';

  @override
  String dutySwap(Object name) {
    return '$name tauschen';
  }

  @override
  String get dutyTapToSwap => 'Tippe auf einen Namen zum Tauschen.';

  @override
  String get dutyTo => 'Bis';

  @override
  String get dutyUnlimited => 'unbefristet';

  @override
  String dutyUntil(Object date) {
    return 'bis $date';
  }

  @override
  String get dutyValidUntil => 'Gültig bis (optional)';

  @override
  String get dutyWeekdays => 'Wochentage';

  @override
  String get editorAgendaDesc => 'Tagesordnungspunkt einfügen';

  @override
  String get editorBold => 'Fett';

  @override
  String get editorBulletDesc => 'Ungeordnete Liste';

  @override
  String get editorBulletList => 'Aufzählung';

  @override
  String get editorFormatting => 'Formatierung';

  @override
  String get editorH1 => 'Überschrift 1';

  @override
  String get editorH1Desc => 'Große Überschrift';

  @override
  String get editorH2 => 'Überschrift 2';

  @override
  String get editorH2Desc => 'Mittlere Überschrift';

  @override
  String get editorHeading => 'Überschrift';

  @override
  String get editorItalic => 'Kursiv';

  @override
  String get editorLink => 'Link';

  @override
  String get editorLinkText => 'Angezeigter Text (optional)';

  @override
  String get editorMessagePlaceholder => 'Nachricht schreiben …';

  @override
  String get editorNewTask => '/aufgabe – Neue Aufgabe';

  @override
  String get editorNewTaskDesc => 'Aufgabe erstellen und verknüpfen';

  @override
  String get editorNotesPlaceholder => 'Tippe hier, um Notizen zu schreiben …';

  @override
  String get editorOrderedDesc => 'Geordnete Liste';

  @override
  String get editorOrderedList => 'Nummerierte Liste';

  @override
  String get editorStrike => 'Durchgestrichen';

  @override
  String get editorUnderline => 'Unterstrichen';

  @override
  String get editorUndo => 'Rückgängig';

  @override
  String get excuseCustomOption => 'Sonstiger Grund (Text)';

  @override
  String get excuseLate => 'Verspätung';

  @override
  String get excuseMinChars => 'Mindestens 5 Zeichen eingeben...';

  @override
  String get excuseReason => 'Grund';

  @override
  String get excuseSignOut => 'Abmeldung';

  @override
  String get exportAddExtraField => 'Extrafeld hinzufügen';

  @override
  String get exportAddField => 'Feld hinzufügen';

  @override
  String get exportAsc => 'Aufsteigend (A–Z)';

  @override
  String get exportAttendance => 'Anwesenheit';

  @override
  String exportAttendanceFile(Object name, Object date) {
    return '${name}_${date}_Anwesenheit.xlsx';
  }

  @override
  String exportAttendanceFileAsOf(Object name, Object date) {
    return '${name}_Anwesenheit_Stand_$date';
  }

  @override
  String get exportAttendancePercent => 'Anwesenheit %';

  @override
  String exportAttendanceTitle(Object name) {
    return '$name Anwesenheit';
  }

  @override
  String get exportChurch => 'Gemeinde';

  @override
  String get exportDesc => 'Absteigend (Z–A)';

  @override
  String get exportDuration => 'Dauer';

  @override
  String get exportExport => 'Exportieren';

  @override
  String get exportExportType => 'Export-Typ';

  @override
  String get exportFields => 'Felder';

  @override
  String get exportFirstName => 'Vorname';

  @override
  String get exportFlutterColumnName => 'Spaltenname';

  @override
  String get exportFlutterCustomFieldEmpty => 'Eigenes Feld (leer)';

  @override
  String exportFlutterFailedWith(Object error) {
    return 'Fehler beim Export: $error';
  }

  @override
  String get exportFlutterPdfLimitHint => 'PDF-Export ist auf die letzten 8 Termine begrenzt. Für alle Termine der Saison nutze den Excel-Export.';

  @override
  String get exportFlutterSuccess => 'Export erfolgreich';

  @override
  String get exportGroup => 'Gruppe';

  @override
  String get exportLastName => 'Nachname';

  @override
  String get exportNoPlan => 'Kein Plan verfügbar';

  @override
  String get exportNotes => 'Bemerkung';

  @override
  String get exportOrder => 'Reihenfolge';

  @override
  String get exportPerformer => 'Ausführung';

  @override
  String exportPlayerListFile(Object name, Object date) {
    return '${name}_Spielerliste_Stand_$date';
  }

  @override
  String exportPlayerListTitle(Object name) {
    return '$name Spielerliste';
  }

  @override
  String get exportPlayers => 'Spieler';

  @override
  String get exportProgrammeItem => 'Programmpunkt';

  @override
  String get exportRunSheet => 'Ablaufplan';

  @override
  String get exportSortBy => 'Sortieren nach';

  @override
  String get exportStatus => 'Status';

  @override
  String get exportTime => 'Uhrzeit';

  @override
  String get exportTitle => 'Daten exportieren';

  @override
  String get extraFieldsAddNew => 'Neues Feld hinzufügen';

  @override
  String get extraFieldsAddOption => 'Bitte füge mindestens eine Option für das Auswahlfeld hinzu.';

  @override
  String get extraFieldsAllNeedName => 'Alle Zusatzfelder müssen einen Namen haben.';

  @override
  String get extraFieldsAsChip => 'Als Chip';

  @override
  String get extraFieldsChurch => 'BFECG Gemeinde';

  @override
  String get extraFieldsDefaultOptional => 'Standardwert (optional)';

  @override
  String get extraFieldsDefaultValue => 'Standardwert';

  @override
  String get extraFieldsDeleteField => 'Zusatzfeld löschen?';

  @override
  String extraFieldsDeleteFieldMessage(Object name) {
    return 'Möchtest du das Zusatzfeld „$name“ wirklich löschen?';
  }

  @override
  String get extraFieldsDeleteOption => 'Option löschen?';

  @override
  String extraFieldsDeleteOptionMessage(Object option) {
    return 'Wenn du die Option „$option“ löschst, werden alle betroffenen Datensätze auf den Standardwert zurückgesetzt.';
  }

  @override
  String get extraFieldsDisplay => 'Anzeige in Listen';

  @override
  String extraFieldsDisplayLine(Object mode) {
    return 'Anzeige: $mode';
  }

  @override
  String get extraFieldsEditable => 'Von Mitgliedern bearbeitbar';

  @override
  String get extraFieldsEditableHelper => 'Aktivieren, damit Mitglieder den Wert selbst ändern können.';

  @override
  String get extraFieldsEditableSuffix => ' (bearbeitbar)';

  @override
  String get extraFieldsFlutterFirstOptionDefault => 'Erste Option ist der Standardwert';

  @override
  String get extraFieldsFlutterLeaveMessage => 'Du hast ungespeicherte Änderungen. Möchtest du die Seite trotzdem verlassen?';

  @override
  String get extraFieldsForPersons => 'Zusätzliche Felder für Personen';

  @override
  String get extraFieldsForSongs => 'Zusätzliche Felder für Werke';

  @override
  String get extraFieldsIdEmpty => 'Die ID des Zusatzfeldes darf nicht leer sein.';

  @override
  String get extraFieldsIdExists => 'Ein Zusatzfeld mit dieser ID existiert bereits. Bitte wähle einen anderen Namen.';

  @override
  String get extraFieldsInvalidName => 'Bitte gib einen gültigen Namen für das Zusatzfeld ein.';

  @override
  String get extraFieldsNoOptions => 'Keine Optionen';

  @override
  String get extraFieldsNoOptionsSelected => 'Keine Optionen ausgewählt';

  @override
  String get extraFieldsNoneYet => 'Es wurden noch keine zusätzlichen Felder hinzugefügt.';

  @override
  String get extraFieldsNumber => 'Zahl';

  @override
  String get extraFieldsOptionsEmpty => 'Optionen dürfen nicht leer sein.';

  @override
  String extraFieldsOptionsEmptyIn(Object name) {
    return 'Die Optionen im Feld „$name“ dürfen nicht leer sein.';
  }

  @override
  String extraFieldsPersonsUpdated(Object count) {
    return '$count Personen aktualisiert';
  }

  @override
  String get extraFieldsResetAll => 'Alle Werte auf Standard zurücksetzen';

  @override
  String get extraFieldsResetValues => 'Werte zurücksetzen?';

  @override
  String extraFieldsResetValuesMessage(Object name) {
    return 'Möchtest du alle Werte des Feldes „$name“ auf den Standardwert zurücksetzen? Dies kann nicht rückgängig gemacht werden!';
  }

  @override
  String get extraFieldsSaveFailed => 'Fehler beim Speichern';

  @override
  String get extraFieldsSaved => 'Felder gespeichert';

  @override
  String get extraFieldsSaving => 'Felder werden gespeichert...';

  @override
  String get extraFieldsSelect => 'Auswahl';

  @override
  String extraFieldsSelectNeedsOption(Object name) {
    return 'Das Auswahlfeld „$name“ muss mindestens eine Option haben.';
  }

  @override
  String get extraFieldsTextarea => 'Textbereich';

  @override
  String get extraFieldsTitle => 'Zusatzfelder';

  @override
  String extraFieldsTypeLine(Object type) {
    return 'Typ: $type';
  }

  @override
  String get extraFieldsUnderName => 'Unter dem Namen';

  @override
  String get extraFieldsValuePh => 'Wert eingeben...';

  @override
  String get extraFieldsVisible => 'Für Mitglieder sichtbar';

  @override
  String get extraFieldsVisibleHelper => 'Aktivieren, damit Mitglieder dieses Feld in ihren Stammdaten sehen können.';

  @override
  String get extraFieldsYesNo => 'Ja/Nein';

  @override
  String get filesAlmostFull => ' · fast voll';

  @override
  String filesAndMore(Object count) {
    return ' und $count weitere';
  }

  @override
  String get filesAscending => 'aufsteigend';

  @override
  String filesChangedAt(Object date) {
    return '· Geändert: $date';
  }

  @override
  String get filesConnectTelegram => 'Bitte verbinde zuerst Telegram in den Benachrichtigungen.';

  @override
  String get filesCreate => 'Erstellen';

  @override
  String get filesCreateFolder => 'Ordner erstellen';

  @override
  String filesDeleteFailed(Object error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String get filesDeleteFile => 'Datei löschen?';

  @override
  String get filesDeleteFolder => 'Ordner löschen?';

  @override
  String filesDeleteMessage(Object name) {
    return 'Möchtest du $name wirklich löschen?';
  }

  @override
  String get filesDeleted => 'Eintrag wurde gelöscht.';

  @override
  String get filesDescending => 'absteigend';

  @override
  String get filesDownload => 'Datei herunterladen';

  @override
  String filesDownloadFailed(Object error) {
    return 'Download fehlgeschlagen: $error';
  }

  @override
  String get filesExists => 'Datei existiert bereits';

  @override
  String filesExistsMessage(Object names) {
    return 'Folgende Datei(en) existieren bereits: $names. Möchtest du diese überschreiben?';
  }

  @override
  String get filesFlutterAscending => 'Aufsteigend';

  @override
  String get filesFlutterDescending => 'Absteigend';

  @override
  String get filesFlutterMovePh => 'z. B. Dokumente/2026';

  @override
  String get filesFlutterOpenDownload => 'Datei öffnen/downloaden';

  @override
  String get filesFlutterOpenFolder => 'Ordner öffnen';

  @override
  String get filesFlutterOpenLinkFailed => 'Link konnte nicht geöffnet werden';

  @override
  String get filesFlutterShareFolderLink => 'Link zu diesem Ordner teilen';

  @override
  String get filesFlutterShareRootLink => 'Link zur Dateiablage teilen';

  @override
  String get filesFolderCreated => 'Ordner wurde erstellt.';

  @override
  String get filesFolderEmpty => 'Dieser Ordner ist leer.';

  @override
  String filesFolderFailed(Object error) {
    return 'Ordner konnte nicht erstellt werden: $error';
  }

  @override
  String get filesFolderName => 'Ordnername';

  @override
  String get filesFull => ' · voll';

  @override
  String get filesHowMuch => 'Wie viel Speicher braucht ihr ungefähr? (optional)';

  @override
  String get filesLinkCopied => 'Link in Zwischenablage kopiert';

  @override
  String filesLinkToast(Object url) {
    return 'Link: $url';
  }

  @override
  String get filesLinkedNotFound => 'Die verlinkte Datei wurde nicht gefunden.';

  @override
  String filesLoadFailed(Object error) {
    return 'Fehler beim Laden der Dateien: $error';
  }

  @override
  String get filesModified => 'Änderungsdatum';

  @override
  String get filesMove => 'Verschieben';

  @override
  String filesMoveFailed(Object error) {
    return 'Verschieben fehlgeschlagen: $error';
  }

  @override
  String get filesMoveHint => 'Zielordner relativ zum Tenant-Root. Leer lassen für Root.';

  @override
  String get filesMoved => 'Eintrag wurde verschoben.';

  @override
  String get filesName => 'Name';

  @override
  String get filesNewName => 'Neuer Name';

  @override
  String get filesNoAccess => 'Du hast keinen Zugriff auf Dateien.';

  @override
  String get filesNoDeleteRights => 'Du darfst Dateien nicht löschen.';

  @override
  String get filesNoEditRights => 'Du darfst Dateien nicht bearbeiten.';

  @override
  String filesNoHits(Object term) {
    return 'Keine Treffer für „$term“.';
  }

  @override
  String get filesNoneUploaded => 'Keine Datei hochgeladen.';

  @override
  String get filesOverwrite => 'Überschreiben';

  @override
  String filesPlayFailed(Object error) {
    return 'Fehler beim Abspielen: $error';
  }

  @override
  String filesPreviewFailed(Object error) {
    return 'Bildvorschau fehlgeschlagen: $error';
  }

  @override
  String get filesRename => 'Umbenennen';

  @override
  String filesRenameFailed(Object error) {
    return 'Umbenennen fehlgeschlagen: $error';
  }

  @override
  String get filesRenameFile => 'Datei umbenennen';

  @override
  String get filesRenameFolder => 'Ordner umbenennen';

  @override
  String get filesRenamed => 'Eintrag wurde umbenannt.';

  @override
  String filesRequestFailed(Object error) {
    return 'Fehler beim Senden der Anfrage: $error';
  }

  @override
  String get filesRequestHint => 'Die Anfrage geht an den Attendix-Admin. Er meldet sich bei dir.';

  @override
  String get filesRequestMore => 'Mehr Speicher anfragen';

  @override
  String get filesRequestSent => 'Deine Anfrage wurde gesendet. Wir melden uns so schnell wie möglich.';

  @override
  String get filesResetSearch => 'Suche zurücksetzen';

  @override
  String get filesRoot => 'Root';

  @override
  String get filesSearch => 'Suche';

  @override
  String get filesSearchCombine => 'Filter sind kombinierbar, z. B. <strong>protokoll typ:pdf datum:2026</strong>.';

  @override
  String get filesSearchDate => '<strong>datum:&lt;wert&gt;</strong> · Filtert nach Änderungsdatum (z. B. <strong>datum:2026</strong>, <strong>datum:03.2026</strong>, <strong>datum:03.03.2026</strong>).';

  @override
  String get filesSearchHelp => 'Freitext durchsucht den Dateinamen/Ordnernamen.';

  @override
  String get filesSearchPlaceholder => 'Dateien & Ordner suchen...';

  @override
  String get filesSearchType => '<strong>typ:&lt;wert&gt;</strong> · Filtert nach Dateityp oder Art (z. B. <strong>typ:pdf</strong>, <strong>typ:ordner</strong>, <strong>typ:datei</strong>).';

  @override
  String get filesSend => 'Senden';

  @override
  String get filesSendTelegram => 'Per Telegram senden';

  @override
  String get filesSendingTelegram => 'Datei wird per Telegram gesendet...';

  @override
  String get filesShareLink => 'Link teilen';

  @override
  String get filesSize => 'Dateigröße';

  @override
  String get filesSkip => 'Überspringen';

  @override
  String filesSortDate(Object dir) {
    return 'Datum ($dir)';
  }

  @override
  String filesSortName(Object dir) {
    return 'Name ($dir)';
  }

  @override
  String filesSortSize(Object dir) {
    return 'Größe ($dir)';
  }

  @override
  String get filesSorting => 'Sortierung';

  @override
  String get filesStorageFull => 'Speicher voll';

  @override
  String filesStorageFullMessage(Object needed, Object free, Object max) {
    return 'Für diesen Upload werden $needed benötigt, frei sind noch $free von $max. Lösche nicht mehr benötigte Dateien oder frage mehr Speicher an.';
  }

  @override
  String filesStorageUsed(Object used) {
    return 'Speicher: $used belegt';
  }

  @override
  String filesStorageUsedOf(Object used, Object max) {
    return 'Speicher: $used von $max belegt';
  }

  @override
  String filesTelegramFailed(Object error) {
    return 'Telegram-Versand fehlgeschlagen: $error';
  }

  @override
  String get filesTitle => 'Dateien';

  @override
  String get filesUpload => 'Dateien hochladen';

  @override
  String filesUploadProgress(Object done, Object total, Object percent) {
    return 'Upload $done/$total ($percent%)';
  }

  @override
  String filesUploadSummary(Object ok, Object skipped, Object failed) {
    return '$ok hochgeladen, $skipped übersprungen, $failed fehlgeschlagen.';
  }

  @override
  String filesUploadedMany(Object count) {
    return '$count Dateien wurden hochgeladen.';
  }

  @override
  String get filesUploadedOne => 'Datei wurde hochgeladen.';

  @override
  String get folderPickerChoose => 'Wählen';

  @override
  String get folderPickerChooseThis => 'Diesen Ordner wählen';

  @override
  String folderPickerLoadFailed(Object error) {
    return 'Fehler beim Laden der Ordner: $error';
  }

  @override
  String get folderPickerNoSubfolders => 'Keine Unterordner vorhanden.';

  @override
  String get folderPickerParent => 'Übergeordneter Ordner';

  @override
  String get folderPickerTitle => 'Ordner wählen';

  @override
  String get generalSettingsAbsenceReasons => 'Abwesenheitsgründe';

  @override
  String get generalSettingsAddReason => 'Grund hinzufügen';

  @override
  String get generalSettingsAddRule => 'Regel hinzufügen';

  @override
  String get generalSettingsAllEvents => 'Alle Termine für Mitglieder sichtbar';

  @override
  String get generalSettingsAllEventsHelper => 'Aktivieren, damit Mitglieder auf der Abmelde-Seite alle Termine der Instanz sehen können (nicht nur eigene). Eigene Termine werden hervorgehoben.';

  @override
  String get generalSettingsAllTime => 'Gesamte Historie';

  @override
  String get generalSettingsAllTypes => 'Alle Typen';

  @override
  String get generalSettingsAllowRegister => 'Registrierung erlauben';

  @override
  String get generalSettingsAnd => 'UND (alle Regeln müssen zutreffen)';

  @override
  String get generalSettingsAttTypes => 'Anwesenheits-Typen';

  @override
  String get generalSettingsAttendance => 'Anwesenheiten';

  @override
  String get generalSettingsAutoApprove => 'Auto-Genehmigung';

  @override
  String get generalSettingsAutoApproveHelper => 'Aktivieren, um neue Registrierungen automatisch zu genehmigen. Andernfalls müssen neue Registrierungen manuell genehmigt werden.';

  @override
  String get generalSettingsBranding => 'Branding';

  @override
  String get generalSettingsCombine => 'Verknüpfung';

  @override
  String get generalSettingsCombineHelper => 'Wie diese Regel mit anderen Regeln kombiniert wird';

  @override
  String get generalSettingsCount => 'Anzahl';

  @override
  String get generalSettingsCriticalRules => 'Problemfall-Regeln';

  @override
  String get generalSettingsDays => 'Anzahl Tage';

  @override
  String get generalSettingsDaysHelper => 'Anzahl der Tage, die zurück geprüft werden';

  @override
  String get generalSettingsDeleteRule => 'Regel löschen?';

  @override
  String get generalSettingsDeleteRuleMessage => 'Möchtest du diese Regel wirklich löschen?';

  @override
  String get generalSettingsDutyView => 'Dienstplan-Ansicht für Meine Termine';

  @override
  String get generalSettingsDutyViewHelper => '„Meine Termine“ zeigt für Personen aus einem Dienst-Team zuerst ihre Dienste, offene Dienste und Zahlen statt der Anwesenheitsquote. Andere Termine stehen eingeklappt darunter.';

  @override
  String get generalSettingsFlutterAndHint => 'Person ist kritisch, wenn ALLE Regeln zutreffen';

  @override
  String get generalSettingsFlutterAndShort => 'UND';

  @override
  String get generalSettingsFlutterDaysSuffix => 'Tage';

  @override
  String generalSettingsFlutterDeleteRuleNamed(Object name) {
    return 'Möchtest du die Regel \"$name\" wirklich löschen?';
  }

  @override
  String get generalSettingsFlutterDisabled => 'Deaktiviert';

  @override
  String get generalSettingsFlutterEditRule => 'Regel bearbeiten';

  @override
  String get generalSettingsFlutterExcuses => 'Entschuldigungen';

  @override
  String get generalSettingsFlutterExcusesHelper => 'Erlaubt \"Entschuldigt\" als Status';

  @override
  String generalSettingsFlutterFieldsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Felder',
      one: '$count Feld',
    );
    return '$_temp0';
  }

  @override
  String get generalSettingsFlutterNoHolidays => 'Keine Feiertage';

  @override
  String get generalSettingsFlutterNoTypes => 'Keine Terminarten vorhanden';

  @override
  String get generalSettingsFlutterOrHint => 'Person ist kritisch, wenn EINE der Regeln zutrifft';

  @override
  String get generalSettingsFlutterOrShort => 'ODER';

  @override
  String get generalSettingsFlutterPracticeEnd => 'Probenende';

  @override
  String get generalSettingsFlutterPracticeStart => 'Probenbeginn';

  @override
  String get generalSettingsFlutterRuleAdded => 'Regel hinzugefügt';

  @override
  String get generalSettingsFlutterRuleDeleted => 'Regel gelöscht';

  @override
  String get generalSettingsFlutterRuleEnabled => 'Regel aktiviert';

  @override
  String get generalSettingsFlutterRuleEnabledHelper => 'Deaktivierte Regeln werden nicht ausgewertet';

  @override
  String get generalSettingsFlutterRuleUpdated => 'Regel aktualisiert';

  @override
  String get generalSettingsFlutterStatusCritical => 'Status (zählt als kritisch)';

  @override
  String get generalSettingsForeignInfo => 'Info-Text für fremde Termine';

  @override
  String get generalSettingsForeignInfoPh => 'Du bist bei diesem Termin nicht dabei.';

  @override
  String get generalSettingsGeneral => 'Allgemein';

  @override
  String get generalSettingsGroupNameEmpty => 'Der Gruppenname darf nicht leer sein.';

  @override
  String get generalSettingsHolidayState => 'Bundesland für Ferien/Feiertage';

  @override
  String get generalSettingsHolidaysHelper => 'Aktivieren, um beim Anlegen der Anwesenheiten die Ferien und Feiertage hervorzuheben. (nur verfügbar für Deutschland)';

  @override
  String get generalSettingsLastXDays => 'Letzte X Tage';

  @override
  String get generalSettingsLateExcusedShort => 'Verspätet (entsch.)';

  @override
  String get generalSettingsLateReasons => 'Verspätungsgründe';

  @override
  String get generalSettingsMaintainTeachers => 'Lehrer pflegen';

  @override
  String get generalSettingsMembersList => 'Mitgliederliste für alle';

  @override
  String get generalSettingsMembersListHelper => 'Aktivieren, um Mitgliedern (Spieler, Helfer, Stimmführer) eine Übersicht aller Personen anzuzeigen.';

  @override
  String get generalSettingsNameOptional => 'Name (optional)';

  @override
  String get generalSettingsNeutral => 'Neutral';

  @override
  String get generalSettingsNewRule => 'Neue Regel hinzufügen';

  @override
  String get generalSettingsNoGroupsYet => 'Es sind noch keine Gruppen vorhanden. Bitte lege zuerst mindestens eine Gruppe an, bevor du die Registrierung aktivierst.';

  @override
  String get generalSettingsNoRules => 'Es wurden noch keine Problemfall-Regeln definiert. Regeln bestimmen, wann eine Person als Problemfall markiert wird.';

  @override
  String get generalSettingsNone => 'Keine';

  @override
  String get generalSettingsOr => 'ODER (eine Regel muss zutreffen)';

  @override
  String get generalSettingsOther => 'Sonstiges';

  @override
  String get generalSettingsParentsFeature => 'Eltern-Funktion';

  @override
  String get generalSettingsParentsHelper => 'Aktivieren, um Eltern die Möglichkeit zu geben, Einsicht in die Anwesenheiten ihrer Kinder zu geben und Abwesenheiten pflegen zu können.';

  @override
  String get generalSettingsPercent => 'Prozent';

  @override
  String get generalSettingsPeriodHelper => 'Bestimmt den Zeitraum für die Zählung';

  @override
  String get generalSettingsPeriodPositive => 'Der Zeitraum muss größer als 0 sein.';

  @override
  String get generalSettingsPeriodType => 'Zeitraum-Typ';

  @override
  String get generalSettingsReasonPh => 'Grund eingeben...';

  @override
  String get generalSettingsReasons => 'Abwesenheits- & Verspätungsgründe';

  @override
  String generalSettingsReasonsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Gründe',
      one: '$count Grund',
    );
    return '$_temp0 konfiguriert';
  }

  @override
  String get generalSettingsRegisterFields => 'Registrierungsfelder';

  @override
  String get generalSettingsRegisterFieldsHint => 'Wähle die Felder aus, die bei der Registrierung angezeigt werden sollen. Alle ausgewählten Felder sind Pflichtfelder.';

  @override
  String get generalSettingsRegisterHelper => 'Aktivieren, um neuen Personen die Registrierung in dieser Instanz zu erlauben. Der Link wird automatisch generiert und kann nach dem Speichern kopiert werden.';

  @override
  String get generalSettingsRegisterNoGroups => 'Registrierung kann nicht aktiviert werden: Bitte lege zuerst mindestens eine Gruppe an.';

  @override
  String get generalSettingsRegistration => 'Registrierung';

  @override
  String get generalSettingsReload => 'Neu laden';

  @override
  String get generalSettingsRestoreDefaults => 'Standardwerte wiederherstellen';

  @override
  String get generalSettingsRulePh => 'z.B. Verspätungs-Warnung';

  @override
  String get generalSettingsSaveFailed => 'Fehler beim Aktualisieren der Einstellungen';

  @override
  String get generalSettingsSaved => 'Einstellungen gespeichert';

  @override
  String get generalSettingsSavedReload => 'Die Einstellungen wurden erfolgreich gespeichert. Bitte lade die Seite neu, um die Änderungen zu sehen.';

  @override
  String get generalSettingsSaving => 'Einstellungen werden gespeichert...';

  @override
  String get generalSettingsSeasonHelper => 'Anwesenheiten werden erst ab diesem Datum bei den Personen berücksichtigt';

  @override
  String get generalSettingsSeasonStart => 'Saisonbeginn';

  @override
  String get generalSettingsSelectStatus => 'Bitte wähle mindestens einen Status aus.';

  @override
  String get generalSettingsShareSongs => 'Werke öffentlich teilen';

  @override
  String get generalSettingsShareSongsHelper => 'Aktivieren, um Werke als öffentlichen link zu teilen. Jeder mit dem Link kann die Werke ansehen aber nicht bearbeiten. Der Link wird automatisch generiert und kann nach dem Speichern kopiert werden.';

  @override
  String get generalSettingsShiftPlans => 'Schichtpläne';

  @override
  String get generalSettingsShiftPresent => 'Schicht-/Arbeitsbedingt = Anwesend';

  @override
  String get generalSettingsShiftPresentHelper => 'Aktivieren, um schicht- oder arbeitsbedingt entschuldigte Abwesenheiten als anwesend für die prozentuale Berechnung zu werten.';

  @override
  String get generalSettingsShortNameEmpty => 'Der Kurzname darf nicht leer sein.';

  @override
  String get generalSettingsShortNameHelper => 'Wird vor allem als Dateiname bei Exports verwendet';

  @override
  String get generalSettingsShowHolidays => 'Ferien/Feiertage anzeigen';

  @override
  String get generalSettingsSinceSeason => 'Seit Saisonbeginn';

  @override
  String get generalSettingsSongDb => 'Werk-Datenbank';

  @override
  String get generalSettingsTeachersHelper => 'Aktivieren, um die Lehrer der Spieler verwalten zu können.';

  @override
  String get generalSettingsTenantName => 'Instanz-Name';

  @override
  String get generalSettingsTenantShort => 'Instanz-Kürzel';

  @override
  String get generalSettingsThresholdPositive => 'Der Schwellenwert muss größer als 0 sein.';

  @override
  String get generalSettingsThresholdType => 'Schwellenwert-Typ';

  @override
  String get handoverAddFilter => 'Filter hinzufügen';

  @override
  String handoverAlreadyThere(Object names) {
    return 'Die folgenden Personen konnten nicht übertragen werden, da sie bereits in der Zielinstanz vorhanden sind:\n$names';
  }

  @override
  String get handoverArchiveNote => 'Die Personen werden in dieser Instanz archiviert.';

  @override
  String handoverConfirm(Object count, Object tenant, Object note) {
    return 'Möchtest du die $count ausgewählten Personen wirklich in die Instanz „$tenant“ übertragen? $note';
  }

  @override
  String get handoverFailed => 'Fehler bei der Personenübergabe';

  @override
  String handoverFailedWith(Object error) {
    return 'Fehler bei der Personenübergabe: $error';
  }

  @override
  String get handoverGroupMapping => 'Gruppen-Zuordnung';

  @override
  String get handoverInGroupDots => 'Ist in der Gruppe...';

  @override
  String get handoverIntro => 'Hiermit kannst du Personen innerhalb einer Organisation weitergeben oder in einer andere Instanz kopieren. Falls die Person ein Account hat, wird diese informiert.';

  @override
  String get handoverKeepHelper => 'Die Person wird in der aktuellen Instanz nicht archiviert sondern bleibt aktiv';

  @override
  String get handoverKeepInTenant => 'Personen in Instanz behalten';

  @override
  String get handoverMainGroupHelper => 'Personen die in der Hauptgruppe sind, werden auch angezeigt';

  @override
  String get handoverNoData => 'Keine Daten für die Personenübergabe vorhanden.';

  @override
  String get handoverNoOtherTenants => 'Es sind keine weiteren Instanzen vorhanden. Bitte füge weitere Instanzen dieser Organisation hinzu.';

  @override
  String get handoverNoneSelected => 'Keine Personen ausgewählt';

  @override
  String get handoverOlderThan => 'Älter als';

  @override
  String get handoverOlderThanDots => 'Älter als...';

  @override
  String get handoverPersonList => 'Personenliste';

  @override
  String get handoverRespectMainGroup => 'Hauptgruppe beachten';

  @override
  String get handoverSelectAll => 'Alle auswählen';

  @override
  String get handoverSelectGroup => 'Gruppe auswählen';

  @override
  String get handoverSettings => 'Einstellungen';

  @override
  String get handoverStayNote => 'Die Personen bleiben in dieser Instanz erhalten.';

  @override
  String get handoverTargetTenant => 'Ziel-Instanz';

  @override
  String get handoverTitle => 'Personenübergabe';

  @override
  String get handoverTransfer => 'Übertragen';

  @override
  String handoverTransferred(Object count) {
    return '$count Personen wurden übertragen.';
  }

  @override
  String get handoverTransferring => 'Personen werden übertragen...';

  @override
  String get handoverYoungerThan => 'Jünger als';

  @override
  String get handoverYoungerThanDots => 'Jünger als...';

  @override
  String get helpArticleNotFound => 'Dieser Artikel wurde nicht gefunden.';

  @override
  String get helpArticles => 'Artikel';

  @override
  String get helpGlossary => 'Glossar';

  @override
  String get helpLookup => 'Nachschlagen';

  @override
  String helpNoHits(Object term) {
    return 'Keine Treffer für „$term“.';
  }

  @override
  String get helpNoTerms => 'Keine Begriffe gefunden.';

  @override
  String get helpSearchPlaceholder => 'Frage oder Stichwort suchen...';

  @override
  String get helpSearchTerm => 'Begriff suchen...';

  @override
  String get helpTitle => 'Hilfe';

  @override
  String get helpTopics => 'Themen';

  @override
  String get historyAddSongs => 'Werk(e) hinzufügen';

  @override
  String get historyDatePlaceholder => 'TT.MM.JJJJ';

  @override
  String get historyFlutterEntryDeleted => 'Eintrag gelöscht';

  @override
  String get historyFlutterNoTenant => 'Kein Tenant ausgewählt';

  @override
  String historyFlutterSongsAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Werke hinzugefügt',
      one: 'Werk hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get historyFlutterUnknownSong => 'Unbekanntes Werk';

  @override
  String get historyNoneFound => 'Keine Werke gefunden';

  @override
  String get historyNoneSelected => 'Keine Werke ausgewählt';

  @override
  String get historyNoneYet => 'Noch keine Werke gespielt';

  @override
  String historyRehearsals(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Proben',
      one: '$count Probe',
    );
    return '$_temp0';
  }

  @override
  String get historyRemoveConfirm => 'Möchtest du den Eintrag wirklich entfernen?';

  @override
  String get historySearchSong => 'Werk suchen...';

  @override
  String get historySelectAtLeastOne => 'Bitte wähle mindestens ein Werk an';

  @override
  String get historySelectSongs => 'Werke auswählen';

  @override
  String historySelectedCount(Object count) {
    return '$count Werk(e) ausgewählt';
  }

  @override
  String get historySongs => 'Werk(e)';

  @override
  String get historyTitle => 'Werkhistorie';

  @override
  String get homeDashboardAbsences => 'Abwesenheiten & Pausierungen';

  @override
  String get homeDashboardAllHidden => 'Alle Karten sind ausgeblendet. Konfiguriere das Dashboard unter Einstellungen.';

  @override
  String get homeDashboardAverage => 'Durchschnitt';

  @override
  String get homeDashboardBirthdayRange => 'Letzte und nächste 14 Tage';

  @override
  String get homeDashboardBirthdays => 'Geburtstage';

  @override
  String get homeDashboardConfigure => 'Dashboard konfigurieren';

  @override
  String get homeDashboardCurrent => 'Aktuell';

  @override
  String get homeDashboardCurrentPlan => 'Aktueller Ablaufplan';

  @override
  String get homeDashboardCurrentProblemCases => 'Aktuelle Problemfälle';

  @override
  String get homeDashboardCurrentSongs => 'Aktuelle Werke';

  @override
  String homeDashboardDaysAgo(Object count) {
    return 'vor $count Tagen';
  }

  @override
  String get homeDashboardEvents => 'Termine';

  @override
  String get homeDashboardFlutterExit => 'Austritt';

  @override
  String get homeDashboardFlutterJoin => 'Beitritt';

  @override
  String homeDashboardFlutterLoadFailed(Object error) {
    return 'Fehler beim Laden: $error';
  }

  @override
  String get homeDashboardFlutterPause => 'Pause';

  @override
  String homeDashboardFlutterTimeRange(Object time) {
    return '$time Uhr';
  }

  @override
  String homeDashboardInDays(Object count) {
    return 'in $count Tagen';
  }

  @override
  String get homeDashboardLast4Weeks => 'Letzte 4 Wochen';

  @override
  String get homeDashboardLast60Days => 'Letzte 60 Tage';

  @override
  String get homeDashboardLastEvent => 'Letzter Termin';

  @override
  String homeDashboardLastSummary(Object present, Object total, Object excused) {
    return '$present/$total anwesend · $excused entschuldigt';
  }

  @override
  String get homeDashboardLateExcusedShort => 'Entsch. verspätet';

  @override
  String get homeDashboardLive => 'Live';

  @override
  String get homeDashboardMemberChanges => 'Mitglieder-Veränderungen';

  @override
  String get homeDashboardNextAndLast => 'Nächster & letzter Termin';

  @override
  String get homeDashboardNoAbsences => 'Keine Abwesenheiten im Zeitraum.';

  @override
  String get homeDashboardNoBirthdays => 'Keine Geburtstage im Zeitraum.';

  @override
  String get homeDashboardNoChanges => 'Keine Veränderungen im Zeitraum.';

  @override
  String get homeDashboardNoEvents => 'Keine Termine gefunden.';

  @override
  String get homeDashboardNoPlannedSongs => 'Keine geplanten Werke.';

  @override
  String get homeDashboardNoProblemCases => 'Keine Problemfälle vorhanden.';

  @override
  String homeDashboardPlanTimes(Object start, Object end, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Positionen',
      one: '$count Position',
    );
    return '$start – $end Uhr · $_temp0';
  }

  @override
  String get homeDashboardPlannedSongs => 'Geplante Werke';

  @override
  String get homeDashboardProblemCases => 'Problemfälle';

  @override
  String get homeDashboardRecently => 'Zuletzt';

  @override
  String get homeDashboardShift => 'Schicht';

  @override
  String homeDashboardShiftCount(Object count) {
    return '$count Schicht';
  }

  @override
  String get homeDashboardSignOuts => 'Abmeldungen';

  @override
  String get homeDashboardSignedOut => 'Abgemeldet';

  @override
  String homeDashboardTotalCount(Object count) {
    return '$count gesamt';
  }

  @override
  String homeDashboardTurned(Object age) {
    return 'ist $age geworden';
  }

  @override
  String homeDashboardTurns(Object age) {
    return 'wird $age';
  }

  @override
  String homeDashboardTurnsToday(Object age) {
    return 'wird heute $age';
  }

  @override
  String get homeDashboardYesterday => 'Gestern';

  @override
  String get imageViewerHint => 'Doppeltippen oder mit zwei Fingern zoomen';

  @override
  String get imageViewerLoadFailed => 'Bild konnte nicht geladen werden';

  @override
  String get imageViewerZoomIn => 'Vergrößern';

  @override
  String get imageViewerZoomOut => 'Verkleinern';

  @override
  String get imageViewerZoomReset => 'Zoom zurücksetzen';

  @override
  String get instrumentsAddGroup => 'Gruppe hinzufügen';

  @override
  String get instrumentsCannotDelete => 'Du kannst das Instrument nicht löschen, da es Spieler gibt (gab), die darauf spielen';

  @override
  String get instrumentsCategories => 'Kategorien';

  @override
  String get instrumentsCategory => 'Kategorie';

  @override
  String get instrumentsCategoryName => 'Name der Kategorie';

  @override
  String get instrumentsDeleteCategory => 'Kategorie wirklich löschen? Alle Gruppen in dieser Kategorie verlieren die Kategorisierung.';

  @override
  String get instrumentsDeleteGroup => 'Gruppe wirklich löschen?';

  @override
  String get instrumentsDragCategories => 'Ziehe die Kategorien, um die Reihenfolge anzupassen. Klicke auf das Häkchen, um zu speichern.';

  @override
  String get instrumentsDragGroups => 'Ziehe die Gruppen, um die Reihenfolge anzupassen. Klicke auf das Häkchen, um zu speichern.';

  @override
  String get instrumentsEditCategory => 'Kategorie bearbeiten';

  @override
  String get instrumentsEnterName => 'Bitte gib einem Namen an';

  @override
  String get instrumentsEs => 'Es';

  @override
  String get instrumentsFlutterAddFailed => 'Fehler beim Hinzufügen';

  @override
  String instrumentsFlutterClef(Object clef) {
    return '$clef-Schlüssel';
  }

  @override
  String get instrumentsFlutterClefs => 'Notenschlüssel';

  @override
  String get instrumentsFlutterGenerateSynonyms => 'Synonyme generieren';

  @override
  String get instrumentsFlutterNoCategories => 'Keine Kategorien';

  @override
  String get instrumentsFlutterNoCategoriesHint => 'Tippe + um eine Kategorie zu erstellen';

  @override
  String get instrumentsFlutterShortName => 'Kurzname';

  @override
  String get instrumentsGeneratingSynonyms => 'Synonyme werden generiert...';

  @override
  String get instrumentsGroupPh => 'z.B. Mädchen, Posaune, Alt 1, etc.';

  @override
  String instrumentsGroupsCount(Object count) {
    return 'Gruppen ($count)';
  }

  @override
  String instrumentsMainGroup(Object name) {
    return '$name (Hauptgruppe)';
  }

  @override
  String get instrumentsNameFirst => 'Bitte gib zuerst einen Namen an!';

  @override
  String get instrumentsNameRequired => 'Bitte gib einen Namen an!';

  @override
  String get instrumentsNewCategory => 'Neue Kategorie';

  @override
  String get instrumentsNoCategory => 'Keine Kategorie';

  @override
  String get instrumentsOrderFailed => 'Fehler beim Speichern der Reihenfolge';

  @override
  String get instrumentsRange => 'Tonumfang';

  @override
  String get instrumentsSavingOrder => 'Reihenfolge wird gespeichert...';

  @override
  String get instrumentsSynonyms => 'Synonyme';

  @override
  String get instrumentsSynonymsFailed => 'Fehler beim Generieren der Synonyme';

  @override
  String get instrumentsSynonymsGenerated => 'Synonyme erfolgreich generiert!';

  @override
  String get instrumentsSynonymsHelper => 'Definiere Synonyme um beim Hinzufügen von Dateien zu Werken die Instrumente automatisch zuordnen zu können. Synonyme durch Komma trennen.';

  @override
  String get instrumentsTuning => 'Stimmung';

  @override
  String get instrumentsUpdate => 'Aktualisieren';

  @override
  String instrumentsUpdated(Object name) {
    return '$name wurde erfolgreich aktualisiert';
  }

  @override
  String get legalLoadFailed => 'Inhalt konnte nicht geladen werden.';

  @override
  String get legalTitle => 'Impressum & Datenschutz';

  @override
  String get linkPersonsFailed => 'Fehler beim Verknüpfen';

  @override
  String get linkPersonsIgnore => 'Ignorieren';

  @override
  String get linkPersonsIntro => 'Mögliche Übereinstimmungen aus verschiedenen Instanzen. Verknüpfte Personen synchronisieren Name, Geburtstag, E-Mail und Telefon automatisch.';

  @override
  String get linkPersonsLink => 'Verknüpfen';

  @override
  String linkPersonsLinked(Object count) {
    return '$count Personen verknüpft';
  }

  @override
  String linkPersonsLinkedCount(Object count) {
    return '$count Personen wurden verknüpft.';
  }

  @override
  String get linkPersonsNoMore => 'Keine weiteren Vorschläge.';

  @override
  String get linkPersonsReasonFirstNamePrefix => 'Vorname-Präfix';

  @override
  String get linkPersonsReasonLastNamePrefix => 'Nachname-Präfix';

  @override
  String get linkPersonsReasonLinked => 'Verknüpfte Person';

  @override
  String get linkPersonsReasonNearlyIdentical => 'Name fast identisch';

  @override
  String get linkPersonsReasonSameBirthday => 'Gleicher Geburtstag';

  @override
  String get linkPersonsReasonSameEmail => 'E-Mail identisch';

  @override
  String get linkPersonsReasonSameFirstName => 'Vorname identisch';

  @override
  String get linkPersonsReasonSameLastName => 'Nachname identisch';

  @override
  String get linkPersonsReasonSimilarBirthday => 'Ähnlicher Geburtstag';

  @override
  String get linkPersonsReasonSimilarName => 'Ähnlicher Name';

  @override
  String get linkPersonsReasonSwapped => 'Vor-/Nachname vertauscht';

  @override
  String get linkPersonsSelectOne => 'Bitte mindestens eine Übereinstimmung auswählen';

  @override
  String get linkPersonsTitle => 'Personen verknüpfen';

  @override
  String get loginEmail => 'E-Mail';

  @override
  String get loginEmailPlaceholder => 'E-Mail eingeben...';

  @override
  String get loginFailedHeader => 'Anmeldung fehlgeschlagen';

  @override
  String get loginFailedMessage => 'E-Mail oder Passwort ist falsch. Falls du kein Passwort gesetzt hast, kannst du dich stattdessen mit einem Code per E-Mail anmelden.';

  @override
  String get loginFlutterAccessDenied => 'Der Zugriff wurde verweigert.';

  @override
  String get loginFlutterBackToLogin => 'Zurück zum Login';

  @override
  String get loginFlutterCheckSpam => 'Bitte prüfe auch deinen Spam-Ordner.';

  @override
  String get loginFlutterConfirmEmail => 'E-Mail bestätigen';

  @override
  String loginFlutterConfirmEmailSent(Object email) {
    return 'Wir haben dir eine E-Mail an $email gesendet. Bitte klicke auf den Link darin, um deinen Account zu aktivieren.';
  }

  @override
  String get loginFlutterEnterPassword => 'Bitte Passwort eingeben';

  @override
  String get loginFlutterLinkFailed => 'Der Link konnte nicht verarbeitet werden.';

  @override
  String get loginFlutterNewPassword => 'Neues Passwort';

  @override
  String get loginFlutterOtherEmail => 'Andere E-Mail verwenden';

  @override
  String get loginFlutterResetIntro => 'Gib deine E-Mail-Adresse ein und wir senden dir einen Link zum Zurücksetzen.';

  @override
  String loginFlutterResetLinkSent(Object email) {
    return 'Wir haben einen Link zum Zurücksetzen deines Passworts an $email gesendet.';
  }

  @override
  String get loginFlutterSendLink => 'Link senden';

  @override
  String get loginFlutterToLogin => 'Zum Login';

  @override
  String get loginFlutterUnexpectedError => 'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.';

  @override
  String get loginForgotPassword => 'Passwort vergessen?';

  @override
  String get loginInstallUpdate => 'Update installieren';

  @override
  String get loginLegal => 'Impressum & Datenschutz';

  @override
  String get loginLinkAndSignIn => 'Verknüpfen & anmelden';

  @override
  String get loginLinkNote => 'Verknüpfe dein Attendix-Konto einmalig mit Microsoft. Melde dich mit deinen Attendix-Zugangsdaten an – danach wirst du in Teams automatisch angemeldet.';

  @override
  String get loginModeOtp => 'Code per E-Mail';

  @override
  String get loginModePassword => 'Passwort';

  @override
  String get loginNoAccountHeader => 'Kein Konto gefunden';

  @override
  String get loginNoAccountMessage => 'Für diese E-Mail-Adresse existiert noch kein Konto. Möchtest du dich jetzt registrieren?';

  @override
  String get loginNotConfirmedHeader => 'E-Mail nicht bestätigt';

  @override
  String get loginNotConfirmedMessage => 'Deine E-Mail-Adresse wurde noch nicht bestätigt. Möchtest du die Bestätigungs-E-Mail erneut senden?';

  @override
  String get loginNotConfirmedResend => 'Erneut senden';

  @override
  String get loginOtpLabel => 'Code aus der E-Mail';

  @override
  String get loginPassword => 'Passwort';

  @override
  String get loginRegister => 'Registrieren';

  @override
  String get loginResendCode => 'Code erneut senden';

  @override
  String loginResendIn(Object seconds) {
    return 'Erneut senden (${seconds}s)';
  }

  @override
  String get loginResetConfirm => 'Zurücksetzen';

  @override
  String get loginResetHeader => 'Passwort zurücksetzen';

  @override
  String get loginSendCode => 'Code senden';

  @override
  String get loginShowPassword => 'Passwort anzeigen';

  @override
  String get loginSignIn => 'Anmelden';

  @override
  String get loginStartDemo => 'Demo starten';

  @override
  String get loginToastEnterEmail => 'Bitte gib deine E-Mail-Adresse ein.';

  @override
  String get loginToastInvalidEmail => 'Bitte eine gültige E-Mail Adresse eingeben.';

  @override
  String get loginToastMsLinked => 'Microsoft-Konto verknüpft. Du wirst künftig automatisch angemeldet.';

  @override
  String get loginToastRegistered => 'Registrierung erfolgreich, bitte bestätige deine E-Mail-Adresse.';

  @override
  String loginVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get messagesAllActive => 'Alle aktiven Mitglieder';

  @override
  String messagesAllCount(Object count) {
    return 'Alle $count';
  }

  @override
  String get messagesCountsFailed => 'Die Empfänger konnten nicht geladen werden.';

  @override
  String get messagesDeleteConfirm => 'Mitteilung löschen?';

  @override
  String get messagesDeleteFailed => 'Fehler beim Löschen';

  @override
  String get messagesDeleteHint => 'Die Mitteilung verschwindet auch bei allen Empfängern aus der App. Bereits versendete E-Mails bleiben bestehen.';

  @override
  String get messagesDeleteMessage => 'Mitteilung löschen';

  @override
  String get messagesEarlier => 'Frühere Mitteilungen';

  @override
  String get messagesEmail => 'E-Mail';

  @override
  String get messagesEmailBounced => 'E-Mail unzustellbar';

  @override
  String messagesEmailCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen haben',
      one: '$count Person hat',
    );
    return '$_temp0 eine E-Mail-Adresse';
  }

  @override
  String get messagesEmailDelivered => 'E-Mail zugestellt';

  @override
  String get messagesEmailDeliveredChip => 'E-Mail zugestellt';

  @override
  String get messagesEmailFailed => 'E-Mail fehlgeschlagen';

  @override
  String messagesEmailOpened(Object time) {
    return 'E-Mail geöffnet $time';
  }

  @override
  String get messagesEmailOpenedApprox => 'E-Mail geöffnet (ungefähr)';

  @override
  String get messagesEmailPending => 'E-Mail ausstehend';

  @override
  String get messagesEmailSent => 'E-Mail gesendet';

  @override
  String get messagesFlutterHideMessage => 'Nachricht ausblenden';

  @override
  String messagesFlutterProblems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Probleme',
      one: '$count Problem',
    );
    return '$_temp0';
  }

  @override
  String get messagesFlutterShowMessage => 'Nachricht anzeigen';

  @override
  String messagesFrom(Object name, Object date) {
    return 'Von $name · $date';
  }

  @override
  String get messagesInclMainGroup => 'inkl. Hauptgruppe';

  @override
  String get messagesIsSending => 'Mitteilung wird versendet';

  @override
  String get messagesListLoadFailed => 'Mitteilungen konnten nicht geladen werden';

  @override
  String get messagesLoadFailed => 'Mitteilung konnte nicht geladen werden';

  @override
  String get messagesMessage => 'Mitteilung';

  @override
  String get messagesMessages => 'Mitteilungen';

  @override
  String get messagesNewMessage => 'Neue Mitteilung';

  @override
  String get messagesNoAccount => 'Kein App-Konto';

  @override
  String get messagesNoAccountNoEmail => 'Kein App-Konto, keine E-Mail';

  @override
  String get messagesNoEmail => 'Keine E-Mail';

  @override
  String get messagesNoPeopleView => 'Keine Personen in dieser Ansicht.';

  @override
  String get messagesNone => 'Noch keine Mitteilungen';

  @override
  String get messagesNoneHint => 'Informiere deine Gruppe mit einer Mitteilung und sieh direkt, wer sie schon gelesen hat.';

  @override
  String get messagesNotAvailable => 'Diese Mitteilung gibt es nicht mehr oder du hast keinen Zugriff darauf.';

  @override
  String get messagesOnlyGroups => 'Nur bestimmte Gruppen';

  @override
  String messagesOpenCount(Object count) {
    return 'Offen $count';
  }

  @override
  String get messagesOpenedEstimate => '„Geöffnet“ bei E-Mails ist ein Schätzwert: manche Mail-Apps laden Bilder vorab, andere blockieren sie.';

  @override
  String get messagesOverview => 'Übersicht';

  @override
  String messagesProblemsCount(Object count) {
    return 'Probleme $count';
  }

  @override
  String get messagesPush => 'Push';

  @override
  String messagesPushCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen haben',
      one: '$count Person hat',
    );
    return '$_temp0 Mitteilungen aktiviert';
  }

  @override
  String get messagesPushDelivered => 'Push/Telegram zugestellt';

  @override
  String get messagesPushFailed => 'Push fehlgeschlagen';

  @override
  String get messagesPushOff => 'Push aus';

  @override
  String get messagesPushTelegram => 'Push / Telegram';

  @override
  String messagesReadAt(Object time) {
    return '✓ Gelesen $time';
  }

  @override
  String messagesReadCount(Object count) {
    return 'Gelesen $count';
  }

  @override
  String get messagesReadInApp => 'in der App gelesen';

  @override
  String messagesReadOf(Object read, Object total) {
    return '$read von $total gelesen';
  }

  @override
  String get messagesRecipients => 'Empfänger';

  @override
  String messagesRecipientsSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '$count Person',
    );
    return '<strong>$_temp0</strong> erhalten diese Mitteilung.';
  }

  @override
  String get messagesRetry => 'Erneut versuchen';

  @override
  String get messagesSend => 'Senden';

  @override
  String get messagesSendConfirm => 'Mitteilung senden?';

  @override
  String messagesSendConfirmMessage(Object title, num count, Object channels) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '$count Person',
    );
    return '„$title“ geht an $_temp0 ($channels). Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get messagesSendFailed => 'Fehler beim Versenden, bitte versuche es erneut.';

  @override
  String get messagesSendVia => 'Versand über';

  @override
  String get messagesSending => 'Versand läuft …';

  @override
  String get messagesSendingNow => 'Wird versendet …';

  @override
  String get messagesSent => 'Gesendet';

  @override
  String get messagesStillSending => 'Der Versand läuft noch. Ziehe nach unten, um zu aktualisieren.';

  @override
  String get messagesTelegram => 'Telegram';

  @override
  String get messagesTitle => 'Titel';

  @override
  String get messagesTitlePlaceholder => 'z. B. Probe am Samstag fällt aus';

  @override
  String messagesToPeople(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '$count Person',
    );
    return 'an $_temp0';
  }

  @override
  String get messagesUnreachable => 'Nicht erreichbar';

  @override
  String messagesUnreachableSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen sind über keinen Kanal erreichbar und sehen',
      one: '$count Person ist über keinen Kanal erreichbar und sieht',
    );
    return '$_temp0 die Mitteilung nur, wenn sie die App öffnen.';
  }

  @override
  String get messagesUnread => 'Ungelesen';

  @override
  String messagesViaEmail(Object count) {
    return '$count per E-Mail';
  }

  @override
  String messagesViaPush(Object count) {
    return '$count per Push/Telegram';
  }

  @override
  String get messagesWriteFirst => 'Erste Mitteilung schreiben';

  @override
  String get notifAnnouncements => 'Mitteilungen';

  @override
  String get notifAnnouncementsHelper => 'Nachrichten von Admins und Verantwortlichen deiner Instanz';

  @override
  String get notifAppUpdates => 'App-Updates';

  @override
  String get notifAppUpdatesHelper => 'Erhalte Benachrichtigungen über App-Updates sobald verfügbar';

  @override
  String get notifBirthdays => 'Geburtstage';

  @override
  String get notifBirthdaysHelper => 'Erhalte täglich um 8:00 Uhr eine Benachrichtigung, falls jemand heute Geburtstag hat';

  @override
  String get notifBothChannels => 'Beide Kanäle gleichzeitig';

  @override
  String get notifBothChannelsHelper => 'Push und Telegram werden parallel gesendet, nicht nur als Fallback.';

  @override
  String get notifChecklist => 'Checklisten-Erinnerungen';

  @override
  String get notifChecklistHelper => 'Erhalte Erinnerungen für fällige To-Dos in deiner Checkliste. Nur möglich, wenn du Verantwortlicher einer Gruppe bist.';

  @override
  String get notifConnect => 'Verbinden';

  @override
  String get notifDisconnect => 'Trennen';

  @override
  String get notifDisconnectConfirm => 'Möchtest du die Verbindung wirklich trennen?';

  @override
  String get notifDisconnectHint => 'Die Verbindung kann jederzeit wiederhergestellt werden';

  @override
  String get notifDuties => 'Dienste';

  @override
  String get notifDutiesHelper => 'Wenn du für einen Dienst eingeteilt wirst, an die Bestätigung erinnert wirst oder jemand zum Einspringen gesucht wird. Dringende Anfragen kommen trotzdem an.';

  @override
  String get notifEnable => 'Benachrichtigungen aktivieren';

  @override
  String get notifEventReminders => 'Terminerinnerungen';

  @override
  String get notifFlutterConfigNotFound => 'Konfiguration nicht gefunden';

  @override
  String notifFlutterLoadFailed(Object error) {
    return 'Fehler beim Laden: $error';
  }

  @override
  String get notifFlutterTelegramOpenFailed => 'Konnte Telegram nicht öffnen';

  @override
  String get notifFlutterUpdateFailed => 'Fehler beim Aktualisieren der Konfiguration';

  @override
  String get notifFlutterUserIdCopied => 'Benutzer-Id kopiert';

  @override
  String get notifLinked => 'Konto erfolgreich verknüpft';

  @override
  String get notifLiveActivity => 'Laufender Ablaufplan';

  @override
  String get notifLiveActivityHelper => 'Zeigt den aktuellen Punkt eines laufenden Ablaufplans auf dem Sperrbildschirm.';

  @override
  String get notifLiveActivityHelperIos => 'Zeigt den aktuellen Punkt eines laufenden Ablaufplans auf dem Sperrbildschirm und in der Dynamic Island.';

  @override
  String get notifNewProblemCases => 'Neue Problemfälle';

  @override
  String get notifNewRegistrations => 'Neu-Registrierungen';

  @override
  String get notifPush => 'Push-Benachrichtigungen';

  @override
  String get notifPushPreferred => 'Push wird bevorzugt. Telegram wird nur als Fallback genutzt, wenn keine Push-Zustellung möglich ist.';

  @override
  String get notifResponsibleOnly => 'Nur möglich, wenn du Verantwortlicher einer Gruppe bist.';

  @override
  String get notifSignIns => 'Anmeldungen';

  @override
  String get notifSignOuts => 'Abmeldungen';

  @override
  String get notifTasks => 'Aufgaben-Erinnerungen';

  @override
  String get notifTasksHelper => 'Erhalte Erinnerungen 2 Tage vor Fälligkeit von Aufgaben, für die du verantwortlich bist.';

  @override
  String get notifTelegram => 'Telegramverknüpfung';

  @override
  String get notifTenantSettings => 'Instanz-Einstellungen';

  @override
  String get notifTitle => 'Benachrichtigungen';

  @override
  String get notifUserId => 'Benutzer-Id';

  @override
  String get openFileLinkFailed => 'Der Link konnte nicht geöffnet werden.';

  @override
  String get openFileNoTenantAccess => 'Du hast keinen Zugriff auf diese Instanz.';

  @override
  String get orgAppearancePlans => 'Darstellung & Pläne';

  @override
  String get orgChoose => 'Auswählen';

  @override
  String get orgCreate => 'Organisation erstellen';

  @override
  String get orgCreateNew => 'Neue Organisation erstellen';

  @override
  String get orgCreateOrLink => 'Organisation erstellen / verknüpfen';

  @override
  String get orgCreated => 'Die Organisation wurde erfolgreich erstellt.';

  @override
  String get orgDisable => 'Deaktivieren';

  @override
  String get orgDisableSync => 'Synchronisierung deaktivieren?';

  @override
  String get orgDisableSyncMessage => 'Die Werke dieser Instanz sind danach leer, bis eigene Werke angelegt werden. Historieneinträge auf Werke der Quellinstanz können nicht mehr aufgelöst werden.';

  @override
  String get orgFieldsAddOption => 'Bitte füge mindestens eine Auswahloption hinzu.';

  @override
  String get orgFieldsApplyChanges => 'Änderungen übernehmen';

  @override
  String get orgFieldsFlutterFirstOptionDefault => 'Erste Option ist der Standardwert';

  @override
  String get orgFieldsIntro => 'Diese Felder und ihre Werte gelten für dieselbe Person gemeinsam in allen Instanzen der Organisation.';

  @override
  String get orgFieldsInvalid => 'Ungültige Organisations-Zusatzfelder.';

  @override
  String get orgFieldsNameExists => 'Ein Zusatzfeld mit diesem Namen existiert bereits.';

  @override
  String orgFieldsNeedsOptions(Object name) {
    return 'Das Auswahlfeld „$name“ benötigt Optionen.';
  }

  @override
  String get orgFieldsNone => 'Es wurden noch keine organisationsweiten Zusatzfelder hinzugefügt.';

  @override
  String get orgFieldsSaved => 'Organisations-Zusatzfelder gespeichert.';

  @override
  String get orgFieldsTitle => 'Personen-Zusatzfelder';

  @override
  String orgFlutterFieldCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Felder',
      one: '$count Feld',
    );
    return '$_temp0';
  }

  @override
  String get orgFlutterNoFields => 'Keine Felder';

  @override
  String get orgFlutterUnlinkFailed => 'Fehler beim Trennen';

  @override
  String get orgHandover => 'Übergabe';

  @override
  String get orgLinkPersonsHint => 'Personen aus verschiedenen Instanzen miteinander verbinden';

  @override
  String get orgNamePh => 'Name eingeben...';

  @override
  String get orgNoneAdminOnly => 'Diese Instanz ist keiner Organisation zugewiesen. Nur Administratoren können Organisationen verwalten.';

  @override
  String get orgNoneIntro => 'Erstelle eine neue Organisation oder verknüpfe diese Instanz mit einer bestehenden, um Personen organisationsweit zu verbinden und gemeinsame Pläne zu nutzen.';

  @override
  String get orgNoneLinked => 'Keine Organisation verknüpft';

  @override
  String get orgNoneOwnSongs => 'Keine (eigene Werke)';

  @override
  String get orgOrgPlans => 'Org-Pläne';

  @override
  String get orgPersonFields => 'Personen-Zusatzfelder';

  @override
  String get orgPersonFieldsHint => 'Felder und Werte für verknüpfte Personen gemeinsam verwalten';

  @override
  String get orgPersons => 'Personen';

  @override
  String get orgPleaseSelect => 'Bitte wähle eine Organisation aus.';

  @override
  String get orgRename => 'Organisation umbenennen';

  @override
  String get orgRenamed => 'Organisation umbenannt';

  @override
  String get orgSelect => 'Organisation auswählen';

  @override
  String get orgSelected => 'Die Organisation wurde erfolgreich ausgewählt.';

  @override
  String get orgSongSync => 'Werk-Synchronisierung';

  @override
  String get orgSongSyncIntro => 'Werke einer anderen Instanz verwenden. Alle Änderungen werden dort gespeichert.';

  @override
  String get orgSourceTenant => 'Quellinstanz';

  @override
  String get orgSyncSaved => 'Werk-Synchronisierung gespeichert.';

  @override
  String get orgTapRename => 'Tippen zum Umbenennen';

  @override
  String get orgTemplatesAddTemplate => 'Vorlage hinzufügen';

  @override
  String get orgTemplatesDefaultFields => 'Standardfelder';

  @override
  String get orgTemplatesDefaultFieldsHint => 'Standardfelder erscheinen im Planungs-Menü als schnell hinzufügbare Felder für alle Instanzen der Organisation.';

  @override
  String orgTemplatesDuration(Object h, Object m) {
    return '$h h $m min';
  }

  @override
  String orgTemplatesDurationH(Object h) {
    return '$h h';
  }

  @override
  String orgTemplatesEndApprox(Object time) {
    return 'Ende ca. $time';
  }

  @override
  String get orgTemplatesEnterFieldName => 'Bitte einen Feldnamen eingeben.';

  @override
  String get orgTemplatesEnterName => 'Bitte einen Namen eingeben.';

  @override
  String get orgTemplatesFieldName => 'Feldname';

  @override
  String get orgTemplatesFieldNamePh => 'Feldname...';

  @override
  String get orgTemplatesMinutes => 'Minuten';

  @override
  String get orgTemplatesNoDefaultFields => 'Noch keine Standardfelder definiert';

  @override
  String get orgTemplatesNoTemplates => 'Noch keine Vorlagen definiert';

  @override
  String get orgTemplatesPerformerOptPh => 'Ausführender (optional)...';

  @override
  String get orgTemplatesRenameTemplate => 'Vorlage umbenennen';

  @override
  String get orgTemplatesSongPlaceholder => 'Werk-Platzhalter';

  @override
  String get orgTemplatesTemplateNamePh => 'Name der Vorlage...';

  @override
  String get orgTemplatesTemplates => 'Vorlagen';

  @override
  String get orgTemplatesTemplatesHint => 'Vorlagen können beim Planen mit einem Tippen auf das Programm angewendet werden und ersetzen dabei den aktuellen Ablauf.';

  @override
  String get orgTemplatesTitle => 'Planvorlagen & Felder';

  @override
  String get orgTenants => 'Instanzen';

  @override
  String get orgThisTenant => 'Diese Instanz';

  @override
  String get orgTitle => 'Organisation';

  @override
  String get orgUnlink => 'Organisation von Instanz trennen?';

  @override
  String get orgUnlinkButton => 'Trennen';

  @override
  String orgUnlinkMessage(Object name) {
    return 'Möchtest du die Organisation „$name“ wirklich von der Instanz trennen?';
  }

  @override
  String get orgUnlinkTenant => 'Instanz trennen';

  @override
  String get orgUnlinked => 'Die Organisation wurde erfolgreich von der Instanz getrennt.';

  @override
  String get orgValidName => 'Bitte gib einen gültigen Namen ein.';

  @override
  String get peopleActivate => 'Aktivieren';

  @override
  String get peopleActivating => 'Wird aktiviert...';

  @override
  String get peopleActiveAgain => 'Person wieder aktiv';

  @override
  String get peopleActivePeople => 'Aktive Personen';

  @override
  String peopleAgeShort(Object date, Object age) {
    return '$date ($age J.)';
  }

  @override
  String peopleAgeYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Jahre',
      one: '$count Jahr',
    );
    return '$_temp0';
  }

  @override
  String peopleAndMore(Object count) {
    return '… und $count weitere';
  }

  @override
  String get peopleArchive => 'Archivieren';

  @override
  String peopleArchiveTitle(Object name) {
    return '$name Archivieren';
  }

  @override
  String get peopleAttendance => 'Anwesenheit';

  @override
  String get peopleAttendanceAsc => 'Anwesenheit ↑';

  @override
  String get peopleAttendanceDesc => 'Anwesenheit ↓';

  @override
  String get peopleBirthday => 'Geburtsdatum';

  @override
  String get peopleBirthdayAsc => 'Geburtsdatum ↑';

  @override
  String get peopleBirthdayDesc => 'Geburtsdatum ↓';

  @override
  String get peopleBirthdayToday => 'Geburtstag heute';

  @override
  String peopleBirthdaysToday(Object count) {
    return '$count Geburtstage heute';
  }

  @override
  String get peopleBulkEdit => 'Bulk-Bearbeitung';

  @override
  String get peopleBulkEditHint => 'Wähle ein Feld aus, um die Werte für alle Personen zu bearbeiten.';

  @override
  String get peopleCandidate => 'Prüfling';

  @override
  String get peopleCandidates => 'Prüflinge';

  @override
  String get peopleCannotRemoveSelf => 'Du kannst dich nicht selbst entfernen!';

  @override
  String get peopleCannotUndoExcl => 'Diese Aktion kann nicht rückgängig gemacht werden!';

  @override
  String get peopleCheckingData => 'Daten werden geprüft...';

  @override
  String get peopleChooseField => 'Feld auswählen';

  @override
  String get peopleChooseFieldPlaceholder => 'Feld wählen...';

  @override
  String get peopleChooseFile => 'Datei auswählen';

  @override
  String get peopleChooseGroupPlaceholder => 'Gruppe wählen...';

  @override
  String get peopleChooseInstance => 'Instanz wählen';

  @override
  String get peopleCreateAccounts => 'Konten erstellen';

  @override
  String get peopleCreateAccountsHint => 'Für Personen mit E-Mail-Adresse werden Benutzerkonten erstellt und Einladungs-E-Mails versendet.';

  @override
  String get peopleCurrent => 'Aktuell';

  @override
  String get peopleDemoUnavailable => 'Diese Funktion ist im Demo-Modus nicht verfügbar.';

  @override
  String get peopleDownloadTemplate => 'Vorlage herunterladen';

  @override
  String peopleDuplicates(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Duplikate',
      one: '$count Duplikat',
    );
    return '$_temp0';
  }

  @override
  String get peopleEmail => 'E-Mail';

  @override
  String get peopleEnterValue => 'Wert eingeben';

  @override
  String peopleErrorAt(Object tenant, Object error) {
    return 'Fehler bei $tenant: $error';
  }

  @override
  String get peopleExtraFields => 'Zusatzfelder';

  @override
  String peopleFailedCount(Object count) {
    return '$count fehlgeschlagen.';
  }

  @override
  String peopleFaulty(Object count) {
    return '$count fehlerhaft';
  }

  @override
  String get peopleFileEmpty => 'Die Datei enthält keine Daten.';

  @override
  String peopleFileRows(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen',
      one: '$count Zeile',
    );
    return '$_temp0';
  }

  @override
  String get peopleFileUnreadable => 'Die Datei konnte nicht gelesen werden.';

  @override
  String get peopleFilter => 'Filtern';

  @override
  String get peopleFiltersNoMatch => 'Die aktiven Filter ergeben keine Treffer.';

  @override
  String get peopleFirstName => 'Vorname';

  @override
  String get peopleFlutterAgeFrom => 'Ab';

  @override
  String get peopleFlutterAgeSuffix => 'J.';

  @override
  String get peopleFlutterAgeTo => 'Bis';

  @override
  String get peopleFlutterAttention => 'Achtung';

  @override
  String peopleFlutterBulkUpdated(Object count) {
    return '$count Person(en) aktualisiert';
  }

  @override
  String get peopleFlutterContactCall => 'Anrufen';

  @override
  String get peopleFlutterContactMail => 'E-Mail';

  @override
  String get peopleFlutterContactMailHint => 'E-Mail schreiben';

  @override
  String get peopleFlutterContactTelegramHint => 'Per Telegram schreiben';

  @override
  String get peopleFlutterContactWhatsAppHint => 'Per WhatsApp schreiben';

  @override
  String get peopleFlutterCreateAnyway => 'Trotzdem erstellen';

  @override
  String get peopleFlutterDefaultView => 'Standard';

  @override
  String get peopleFlutterDeselectAll => 'Auswahl aufheben';

  @override
  String peopleFlutterDuplicateMessage(Object name, Object count) {
    return 'Eine Person mit dem Namen \"$name\" existiert bereits (${count}x). Trotzdem erstellen?';
  }

  @override
  String peopleFlutterErrorWith(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get peopleFlutterFirstNameRequired => 'Vorname ist erforderlich';

  @override
  String get peopleFlutterGroupsLoadFailed => 'Fehler beim Laden der Gruppen';

  @override
  String peopleFlutterHandoverCopied(Object count) {
    return '$count Spieler erfolgreich kopiert';
  }

  @override
  String get peopleFlutterHandoverCopy => 'Kopieren';

  @override
  String peopleFlutterHandoverCopyConfirm(Object count, Object tenant) {
    return '$count Spieler nach \"$tenant\" kopieren?';
  }

  @override
  String get peopleFlutterHandoverCopyNote => 'Die ausgewählten Spieler werden in die Ziel-Instanz kopiert. Sie bleiben in dieser Instanz aktiv. Der App-Zugang muss in der Ziel-Instanz neu verknüpft werden.';

  @override
  String get peopleFlutterHandoverCopyQuestion => 'Spieler kopieren?';

  @override
  String get peopleFlutterHandoverCopyTitle => 'Spieler kopieren';

  @override
  String peopleFlutterHandoverCount(Object count, Object total) {
    return '$count von $total Spieler';
  }

  @override
  String get peopleFlutterHandoverMappingHint => 'Ordne die Gruppen der Quell-Instanz den Gruppen der Ziel-Instanz zu:';

  @override
  String get peopleFlutterHandoverMode => 'Modus';

  @override
  String get peopleFlutterHandoverModeCopy => 'Spieler werden kopiert (bleiben hier aktiv)';

  @override
  String get peopleFlutterHandoverModeTransfer => 'Spieler werden übertragen (hier archiviert)';

  @override
  String get peopleFlutterHandoverNoMapping => '-- Nicht zuordnen --';

  @override
  String get peopleFlutterHandoverNoPermission => 'Keine Berechtigung in der Ziel-Instanz';

  @override
  String get peopleFlutterHandoverNoTenants => 'Keine anderen Instanzen verfügbar';

  @override
  String get peopleFlutterHandoverNoTenantsHint => 'Du hast nur Zugriff auf eine Instanz. Um Spieler zu übertragen, benötigst du Zugriff auf mindestens zwei Instanzen.';

  @override
  String peopleFlutterHandoverPartialCopied(Object success, Object duplicate, Object error) {
    return '$success kopiert, $duplicate bereits vorhanden, $error fehlgeschlagen';
  }

  @override
  String peopleFlutterHandoverPartialTransferred(Object success, Object duplicate, Object error) {
    return '$success übertragen, $duplicate bereits vorhanden, $error fehlgeschlagen';
  }

  @override
  String get peopleFlutterHandoverPreparing => 'Bereite Übertragung vor...';

  @override
  String peopleFlutterHandoverProgress(Object name, Object current, Object total) {
    return 'Übertrage $name ($current/$total)...';
  }

  @override
  String get peopleFlutterHandoverTargetNotFound => 'Ziel-Instanz nicht gefunden';

  @override
  String peopleFlutterHandoverTransferConfirm(Object count, Object tenant) {
    return '$count Spieler an \"$tenant\" übertragen? Die Spieler werden in dieser Instanz archiviert. Dieser Vorgang kann nicht rückgängig gemacht werden.';
  }

  @override
  String get peopleFlutterHandoverTransferNote => 'Die ausgewählten Spieler werden in die Ziel-Instanz übertragen. Sie werden in dieser Instanz archiviert und der App-Zugang wird getrennt. Dieser Vorgang kann nicht rückgängig gemacht werden.';

  @override
  String get peopleFlutterHandoverTransferQuestion => 'Spieler übertragen?';

  @override
  String get peopleFlutterHandoverTransferTitle => 'Spieler übertragen';

  @override
  String peopleFlutterHandoverTransferred(Object count) {
    return '$count Spieler erfolgreich übertragen';
  }

  @override
  String get peopleFlutterHandoverTransferring => 'Wird übertragen...';

  @override
  String get peopleFlutterHint => 'Hinweis';

  @override
  String get peopleFlutterLastNameRequired => 'Nachname ist erforderlich';

  @override
  String get peopleFlutterListLoadFailed => 'Die Personenliste konnte nicht geladen werden.';

  @override
  String get peopleFlutterLoadFailed => 'Fehler beim Laden';

  @override
  String get peopleFlutterNotesHint => 'Zusätzliche Informationen...';

  @override
  String peopleFlutterOptional(Object label) {
    return '$label (optional)';
  }

  @override
  String peopleFlutterPausedToast(Object name) {
    return '$name wurde pausiert';
  }

  @override
  String get peopleFlutterPossibleDuplicate => 'Mögliches Duplikat';

  @override
  String get peopleFlutterSaveOrder => 'Reihenfolge speichern';

  @override
  String peopleFlutterSelectedCount(Object count) {
    return '$count ausgewählt';
  }

  @override
  String peopleFlutterTransferCount(Object count) {
    return '$count übertragen';
  }

  @override
  String get peopleFlutterTransferPeople => 'Personen übertragen';

  @override
  String get peopleFromToday => 'Ab heute';

  @override
  String get peopleFullName => 'Name (Vor- und Nachname)';

  @override
  String get peopleGroup => 'Gruppe';

  @override
  String get peopleGroupPlaceholder => 'Gruppe...';

  @override
  String get peopleIgnore => 'Ignorieren';

  @override
  String peopleImportCount(Object count) {
    return '$count importieren';
  }

  @override
  String get peopleImportIntro => 'Importiere Personen aus einer Excel- (.xlsx/.xls) oder CSV-Datei. Die erste Zeile muss Spaltenüberschriften enthalten. Am einfachsten ist es, die Vorlage herunterzuladen und auszufüllen.';

  @override
  String get peopleImportPeople => 'Personen importieren';

  @override
  String peopleImportProgress(Object done, Object total) {
    return '$done / $total importiert...';
  }

  @override
  String peopleImportedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen importiert.',
      one: '$count Person importiert.',
    );
    return '$_temp0';
  }

  @override
  String get peopleInstruments => 'Instrumente';

  @override
  String get peopleJoinAsc => 'Beitrittsdatum ↑';

  @override
  String get peopleJoinDesc => 'Beitrittsdatum ↓';

  @override
  String get peopleJoined => 'Eingetreten';

  @override
  String get peopleLastName => 'Nachname';

  @override
  String get peopleLeaveDate => 'Austrittsdatum';

  @override
  String get peopleMapNames => 'Bitte Spalten für Vor- und Nachnamen zuordnen.';

  @override
  String get peopleMappingIntro => 'Ordne die Spalten deiner Datei den Personenfeldern zu. Vorname und Nachname (oder eine kombinierte Namensspalte) sind erforderlich.';

  @override
  String get peopleMappingMissing => 'Bitte ordne Spalten für Vor- und Nachnamen zu (oder eine kombinierte Namensspalte).';

  @override
  String get peopleMembers => 'Mitglieder';

  @override
  String get peopleMembersLoadFailed => 'Fehler beim Laden der Mitglieder.';

  @override
  String get peopleNew => 'Neu';

  @override
  String get peopleNewPlayers => 'Neue Spieler';

  @override
  String get peopleNextBirthday => 'Nächster Geburtstag';

  @override
  String get peopleNoChanges => 'Keine Änderungen';

  @override
  String get peopleNoEndDate => 'Kein Enddatum gewählt';

  @override
  String get peopleNoGroupAssigned => 'Ohne Gruppe';

  @override
  String get peopleNoMembersFound => 'Keine Mitglieder gefunden.';

  @override
  String get peopleNoPeopleFound => 'Keine Personen gefunden';

  @override
  String get peopleNoPeopleYet => 'Bisher wurden noch keine Personen angelegt';

  @override
  String get peopleNoResult => 'Kein Ergebnis';

  @override
  String get peopleNoTeacher => 'Kein Lehrer';

  @override
  String get peopleNotImported => 'Nicht importierte Personen';

  @override
  String get peopleNote => 'Notiz';

  @override
  String get peopleNotePlaceholder => 'Notiz...';

  @override
  String get peopleNotes => 'Notizen';

  @override
  String get peopleNothingToImport => 'Keine importierbaren Personen.';

  @override
  String get peopleOrderSaveFailed => 'Fehler beim Speichern der Reihenfolge';

  @override
  String get peopleOrderSaved => 'Reihenfolge gespeichert';

  @override
  String get peopleOtherDuties => 'Sonstige Dienste';

  @override
  String get peopleOtherInstanceMember => 'Mitglied anderer Instanz';

  @override
  String get peoplePassportPhoto => 'Passbild';

  @override
  String get peoplePause => 'Pausieren';

  @override
  String get peoplePauseHint => 'Mit einem Startdatum in der Vergangenheit wird die Person auch aus zurückliegenden Anwesenheiten ab diesem Datum entfernt. Wenn ein Enddatum angegeben wird, wird die Person automatisch reaktiviert.';

  @override
  String get peoplePauseOthers => 'Auch in anderen Instanzen pausieren?';

  @override
  String peoplePauseOthersMessage(Object name) {
    return '$name ist auch in anderen Instanzen aktiv. In welchen soll die Person ebenfalls pausiert werden?';
  }

  @override
  String peoplePauseTitle(Object name) {
    return '$name Pausieren';
  }

  @override
  String get peoplePaused => 'Pausiert';

  @override
  String get peoplePausedFrom => 'Pausiert ab (optional)';

  @override
  String get peoplePausing => 'Wird pausiert...';

  @override
  String peoplePeopleCount(Object count) {
    return 'Personen ($count)';
  }

  @override
  String get peoplePhone => 'Telefon';

  @override
  String get peoplePhonePlaceholder => 'Telefon...';

  @override
  String get peoplePreviewFailed => 'Fehler bei der Vorschau.';

  @override
  String get peopleProblemCase => 'Problemfall';

  @override
  String get peopleProblemCases => 'Problemfälle';

  @override
  String get peopleReactivateConfirm => 'Person wieder aktivieren?';

  @override
  String get peopleReadingFile => 'Datei wird gelesen...';

  @override
  String peopleReady(Object count) {
    return '$count bereit';
  }

  @override
  String get peopleReasonPlaceholder => 'Bitte gib einen Grund an...';

  @override
  String get peopleReasonRequired => 'Grund *';

  @override
  String get peopleRemoveConfirm => 'Person wirklich entfernen?';

  @override
  String get peopleRemoved => 'Person wurde entfernt.';

  @override
  String get peopleRemoving => 'Person wird entfernt...';

  @override
  String get peopleReorder => 'Reihenfolge anpassen';

  @override
  String get peopleResetFilter => 'Filter zurücksetzen';

  @override
  String peopleSaveChanges(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen speichern',
      one: '$count Änderung speichern',
    );
    return '$_temp0';
  }

  @override
  String get peopleSaveFailed => 'Fehler beim Speichern';

  @override
  String get peopleSaving => 'Speichern...';

  @override
  String get peopleSavingOrder => 'Reihenfolge wird gespeichert...';

  @override
  String get peopleSearchPerson => 'Person suchen...';

  @override
  String get peopleSetForAll => 'Für alle setzen';

  @override
  String get peopleShowAll => 'Alle Anzeigen';

  @override
  String get peopleSkip => 'Überspringen';

  @override
  String get peopleStandardFields => 'Standard-Felder';

  @override
  String get peopleTeacher => 'Lehrer';

  @override
  String peopleTeacherName(Object name) {
    return 'Lehrer: $name';
  }

  @override
  String get peopleTestResult => 'Testergebnis';

  @override
  String get peopleTestResultMissing => 'Testergebnis fehlt';

  @override
  String peopleUnresolvedGroups(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen konnten keiner Gruppe zugeordnet werden.',
      one: '$count Person konnte keiner Gruppe zugeordnet werden.',
    );
    return '$_temp0 Bitte prüfe und passe die Gruppe unten an – vorerst ist die Hauptgruppe hinterlegt.';
  }

  @override
  String get peopleVoiceLeader => 'Stimmführer';

  @override
  String peopleWithHint(Object count) {
    return '$count mit Hinweis';
  }

  @override
  String get peopleWithoutAccount => 'Ohne Account';

  @override
  String get peopleWithoutTeacher => 'Ohne Lehrer';

  @override
  String get personAbsences => 'Abwesenheiten';

  @override
  String personAbsencesCount(Object count) {
    return 'Abwesenheiten ($count)';
  }

  @override
  String get personAccount => 'Account';

  @override
  String get personAccountBadge => 'Konto';

  @override
  String get personAccountCreated => 'Account wurde erfolgreich angelegt';

  @override
  String get personAccountHelp => 'Sobald die E-Mail Adresse eingeben wurde, kann ein Account erstellt werden. Der Benutzer wird per E-Mail über die Erstellung benachrichtigt. Das Passwort wird automatisch generiert und an die E-Mail Adresse gesendet.';

  @override
  String get personActions => 'Aktionen';

  @override
  String personActiveSince(Object date) {
    return 'Wieder aktiv seid $date';
  }

  @override
  String get personAddAbsence => 'Abwesenheit hinzufügen';

  @override
  String personAddFailed(Object error) {
    return 'Fehler beim hinzufügen der Person: $error';
  }

  @override
  String get personAdded => 'Die Person wurde erfolgreich hinzugefügt';

  @override
  String get personApprovePerson => 'Person genehmigen';

  @override
  String get personApproving => 'Die Person wird genehmigt...';

  @override
  String get personArchived => 'Die Person wurde erfolgreich archiviert';

  @override
  String personArchivedAt(Object date) {
    return 'Archiviert am $date';
  }

  @override
  String get personAssignMyUser => 'Meinen Benutzer zuweisen';

  @override
  String get personAverage => 'Durchschnitt';

  @override
  String personAverageLate(Object count) {
    return 'Durchschnitt (${count}x zu spät)';
  }

  @override
  String get personChooseEntry => 'Eintrag auswählen';

  @override
  String get personCloseSuggestions => 'Vorschläge schließen';

  @override
  String get personCopied => 'Die Person wurde erfolgreich kopiert';

  @override
  String personCopiedAt(Object date) {
    return 'Kopiert am $date';
  }

  @override
  String get personCopyConfirm => 'Möchtest du die Person wirklich in die andere Instanz kopieren?';

  @override
  String personCopyFrom(Object name) {
    return 'Kopieren von $name';
  }

  @override
  String get personCopyNotPossible => 'Kopieren nicht möglich';

  @override
  String get personCopyOther => 'In andere Instanz kopieren';

  @override
  String get personCopyPerson => 'Person kopieren';

  @override
  String get personCreateAccountNow => 'Möchtest du gleich ein Konto für die Person anlegen?';

  @override
  String get personDataTaken => 'Die Daten wurden erfolgreich übernommen';

  @override
  String get personDatePlaceholder => 'TT.MM.JJJJ';

  @override
  String get personDecline => 'Ablehnen';

  @override
  String get personDeclinePerson => 'Person ablehnen';

  @override
  String get personDeclining => 'Die Person wird abgelehnt...';

  @override
  String get personDeleteAbsenceMessage => 'Soll die Abwesenheit gelöscht werden? Bereits entschuldigte Termine in diesem Zeitraum werden auf \"Neutral\" zurückgesetzt.';

  @override
  String get personDiscardChanges => 'Änderungen verwerfen?';

  @override
  String get personDiscardChangesMessage => 'Möchtest du die ungespeicherten Änderungen wirklich verwerfen?';

  @override
  String get personDone => 'Fertig';

  @override
  String get personEditName => 'Namen bearbeiten';

  @override
  String get personEditPerson => 'Person bearbeiten';

  @override
  String get personEmailAdded => 'E-Mail Adresse hinzugefügt';

  @override
  String get personEmailTaken => 'E-Mail bereits vergeben';

  @override
  String get personEmailUpdated => 'Die E-Mail Adresse wurde erfolgreich aktualisiert';

  @override
  String personEmailUsedBy(Object name) {
    return 'Diese E-Mail wird in einer anderen Instanz von $name verwendet. Daten übernehmen?';
  }

  @override
  String get personEmailUsedMany => 'Diese E-Mail wird bereits in anderen Instanzen verwendet. Daten welcher Person übernehmen?';

  @override
  String get personEnableVoiceLeader => 'Stimmführer aktivieren';

  @override
  String get personEnterAbsence => 'Abwesenheit eintragen';

  @override
  String get personEnterNames => 'Bitte gib den Vornamen und Nachnamen an.';

  @override
  String get personEntryRemoveFailed => 'Fehler beim Löschen des Eintrags.';

  @override
  String get personEntryRemoved => 'Eintrag wurde erfolgreich entfernt.';

  @override
  String get personExistingUserHint => 'Falls schon ein Benutzer für die E-Mail Adresse existiert, wird dieser automatisch der Instanz zugewiesen.';

  @override
  String personExistsWithEmail(Object tenant, Object email) {
    return 'In der Instanz \"$tenant\" existiert bereits eine Person mit der E-Mail-Adresse \"$email\".';
  }

  @override
  String personExistsWithName(Object tenant, Object name) {
    return 'In der Instanz \"$tenant\" existiert bereits eine Person mit dem Namen \"$name\".';
  }

  @override
  String get personFlutterAbsenceDeleteFailed => 'Abwesenheit konnte nicht gelöscht werden';

  @override
  String get personFlutterAbsenceSaveFailed => 'Abwesenheit konnte nicht gespeichert werden';

  @override
  String get personFlutterAccountCreatedMail => 'Account erstellt. Passwort-E-Mail wurde gesendet.';

  @override
  String get personFlutterAllEntries => 'Alle Einträge';

  @override
  String get personFlutterApprove => 'Genehmigen';

  @override
  String personFlutterApproveMessage(Object name) {
    return '$name als Mitglied freischalten?';
  }

  @override
  String get personFlutterApproveQuestion => 'Person genehmigen?';

  @override
  String get personFlutterApproved => 'Person wurde genehmigt';

  @override
  String get personFlutterArchiveReasonHint => 'Warum verlässt die Person?';

  @override
  String personFlutterAttendanceLate(Object count) {
    return 'Anwesenheit (${count}x zu spät)';
  }

  @override
  String personFlutterChooseLabel(Object label) {
    return '$label auswählen';
  }

  @override
  String get personFlutterChooseRange => 'Zeitraum wählen';

  @override
  String get personFlutterCreateAccount => 'Account erstellen';

  @override
  String personFlutterCreateAccountFailed(Object name, Object error) {
    return '$name - Fehler beim Erstellen des Accounts: $error';
  }

  @override
  String personFlutterCreateAccountMessage(Object name, Object email) {
    return 'Für $name wird ein Account mit der E-Mail $email erstellt. Die Person erhält eine E-Mail zum Setzen des Passworts.';
  }

  @override
  String get personFlutterCreateAccountQuestion => 'Account erstellen?';

  @override
  String get personFlutterCritical => 'Kritisch';

  @override
  String personFlutterDeclineMessage(Object name) {
    return '$name wird abgelehnt und archiviert.';
  }

  @override
  String get personFlutterDeclineReasonHint => 'Warum wird die Person abgelehnt?';

  @override
  String get personFlutterDeclined => 'Person wurde abgelehnt';

  @override
  String get personFlutterEmailRequiredForAccount => 'Um einen Account zu erstellen, muss eine E-Mail-Adresse hinterlegt werden.';

  @override
  String get personFlutterFrequentLate => 'Häufige Verspätungen';

  @override
  String personFlutterFromSeasonStart(Object date) {
    return 'Ab Saisonstart ($date)';
  }

  @override
  String get personFlutterInstrumentsHint => 'z.B. Klavier, Gitarre';

  @override
  String personFlutterLateCount(Object count, Object threshold) {
    return '$count× zu spät (Schwelle: $threshold)';
  }

  @override
  String personFlutterLateUnexcusedCount(Object count, Object threshold) {
    return '$count× unentschuldigt zu spät (Schwelle: $threshold)';
  }

  @override
  String get personFlutterLinked => 'Verknüpft';

  @override
  String get personFlutterMatchFound => 'Person in anderer Instanz gefunden?';

  @override
  String get personFlutterMore => 'Mehr';

  @override
  String get personFlutterNoAccountLinked => 'Kein Account verknüpft. Ein Dirigent kann einen Account erstellen.';

  @override
  String get personFlutterNoEmail => 'Keine E-Mail-Adresse vorhanden';

  @override
  String get personFlutterNoHistory => 'Keine Historie vorhanden';

  @override
  String get personFlutterNoNote => 'Keine Notiz';

  @override
  String get personFlutterNoNotes => 'Keine Notizen';

  @override
  String get personFlutterNoPermissionArchive => 'Keine Berechtigung zum Archivieren';

  @override
  String get personFlutterNoPermissionCreateAccount => 'Keine Berechtigung zum Erstellen von Accounts';

  @override
  String get personFlutterNoPermissionEdit => 'Keine Berechtigung zum Bearbeiten';

  @override
  String get personFlutterNoPermissionPause => 'Keine Berechtigung zum Pausieren';

  @override
  String get personFlutterNoPermissionReactivate => 'Keine Berechtigung zum Reaktivieren';

  @override
  String get personFlutterNoPermissionRoles => 'Keine Berechtigung zum Ändern von Rollen';

  @override
  String get personFlutterNoPermissionUnlink => 'Keine Berechtigung zum Aufheben von Account-Verknüpfungen';

  @override
  String get personFlutterNoShiftPlan => 'Kein Schichtplan';

  @override
  String personFlutterNoneLabel(Object label) {
    return 'Keine $label';
  }

  @override
  String personFlutterNoneLabelMasc(Object label) {
    return 'Kein $label';
  }

  @override
  String get personFlutterNotAssigned => 'Nicht zugewiesen';

  @override
  String get personFlutterNotFound => 'Person nicht gefunden';

  @override
  String get personFlutterNotSelected => 'Nicht ausgewählt';

  @override
  String get personFlutterNotSpecified => 'Nicht angegeben';

  @override
  String get personFlutterNotesHint => 'Notizen zur Person...';

  @override
  String get personFlutterOtherDutiesHint => 'Weitere Aufgaben...';

  @override
  String personFlutterOtherInstancesCount(Object count) {
    return 'Andere Instanzen ($count)';
  }

  @override
  String personFlutterPausedUntil(Object date) {
    return 'Pausiert bis $date';
  }

  @override
  String get personFlutterPending => 'Ausstehend';

  @override
  String get personFlutterProblemSolved => 'Problemfall gelöst';

  @override
  String get personFlutterRangeHint => 'z.B. C3 - C5';

  @override
  String get personFlutterRemarksHint => 'Was wurde besprochen?';

  @override
  String get personFlutterRequired => 'Pflichtfeld';

  @override
  String get personFlutterRoleAdmin => 'Dirigent (Admin)';

  @override
  String get personFlutterRoleNone => 'Keine Rolle';

  @override
  String personFlutterRoleUpdateFailed(Object error) {
    return 'Rolle konnte nicht angepasst werden: $error';
  }

  @override
  String get personFlutterSaveOnly => 'Nur speichern';

  @override
  String get personFlutterSearchOtherInstance => 'In anderer Instanz suchen';

  @override
  String get personFlutterSeasonOnly => 'Nur Saison';

  @override
  String get personFlutterShowAll => 'Alle anzeigen';

  @override
  String get personFlutterTalkedToHint => 'Bestätigen, dass das Problem besprochen wurde';

  @override
  String get personFlutterTestResultHint => 'Ergebnis eingeben...';

  @override
  String get personFlutterUnlink => 'Verknüpfung aufheben';

  @override
  String get personFlutterUnlinkAccount => 'Account-Verknüpfung aufheben';

  @override
  String personFlutterUnlinkMessage(Object name) {
    return 'Die Account-Verknüpfung für $name wird aufgehoben. Die Person kann sich dann nicht mehr in der App anmelden.';
  }

  @override
  String get personFlutterUnlinkQuestion => 'Account-Verknüpfung aufheben?';

  @override
  String get personFlutterUnlinked => 'Account-Verknüpfung aufgehoben';

  @override
  String personFlutterUploadFailedWith(Object error) {
    return 'Fehler beim Hochladen: $error';
  }

  @override
  String get personFlutterUploadingPhoto => 'Lade Passbild hoch...';

  @override
  String get personFromRequired => 'Von *';

  @override
  String get personGiveReasonShort => 'Gib einen Grund an.';

  @override
  String get personHelp => 'Hilfe';

  @override
  String get personHistory => 'Historie';

  @override
  String get personInvalidEmail => 'Bitte gib eine valide E-Mail Adresse ein...';

  @override
  String get personJoinedOn => 'Beigetreten am';

  @override
  String get personLateCounterReset => 'Verspätungszähler zurückgesetzt';

  @override
  String personLateExcusedExtra(Object count) {
    return 'Zusätzlich ${count}x entschuldigt zu spät.';
  }

  @override
  String personLateWarning(Object count) {
    return 'Diese Person ist <strong>${count}x</strong> unentschuldigt zu spät gekommen.';
  }

  @override
  String get personLateWarningTitle => '🕐 Häufige Verspätungen';

  @override
  String get personLongAbsenceHint => 'Für längere Abwesenheiten empfiehlt sich die Pausieren-Funktion, damit die Person nicht in neuen Terminen erscheint.';

  @override
  String get personMerge => 'Zusammenführen';

  @override
  String get personMergeFailed => 'Fehler beim Zusammenführen der Personen';

  @override
  String personMergeMessage(Object name, Object candidate) {
    return '$name wird mit der bestehenden Person $candidate zusammengeführt. Deren Anwesenheitsdaten bleiben erhalten, der neu registrierte Account wird $candidate zugeordnet. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get personMergePeople => 'Personen zusammenführen';

  @override
  String get personMerged => 'Die Personen wurden erfolgreich zusammengeführt';

  @override
  String get personMerging => 'Die Personen werden zusammengeführt...';

  @override
  String get personNoAbsences => 'Keine Abwesenheiten eingetragen';

  @override
  String get personNoChurchFound => 'Keine Gemeinde gefunden.';

  @override
  String get personNoComment => 'Keine Anmerkung';

  @override
  String get personNoDateChosen => 'Kein Datum gewählt';

  @override
  String get personNoMatchOther => 'Es wurde keine passende Person in einer anderen Instanz gefunden';

  @override
  String get personNoShift => 'Keine Schicht zugewiesen';

  @override
  String get personNotAvailable => 'Nicht verfügbar';

  @override
  String get personNotListed => 'Nicht gelistet';

  @override
  String get personNotSet => 'Nicht festgelegt';

  @override
  String get personNoteChanged => 'Notiz geändert';

  @override
  String personNoteChangedAt(Object date) {
    return 'Notiz geändert am $date';
  }

  @override
  String personOldNote(Object note) {
    return 'Alte Notiz: $note';
  }

  @override
  String get personOtherInstances => 'Andere Instanzen';

  @override
  String get personOtherOrchestras => 'Andere Orchester';

  @override
  String get personParents => 'Eltern';

  @override
  String get personPauseHintAuto => 'Mit einem Startdatum in der Vergangenheit wird die Person auch aus zurückliegenden Anwesenheiten ab diesem Datum entfernt. Wenn ein Enddatum angegeben ist, wird die Person danach automatisch wieder aktiviert.';

  @override
  String get personPauseReasonPlaceholder => 'Gib einen Grund für die Pause an...';

  @override
  String personPauseTitle(Object name) {
    return '$name pausieren';
  }

  @override
  String personPausedAt(Object date) {
    return 'Pausiert am $date';
  }

  @override
  String get personPhoneNumber => 'Telefon-/Handynummer';

  @override
  String get personPhotoChangeFailed => 'Fehler beim ändern des Passbildes, versuche es später erneut';

  @override
  String get personPhotoLoadFailed => 'Fehler beim Laden des Passbildes';

  @override
  String get personPhotoRemoved => 'Das Passbild wurde erfolgreich entfernt';

  @override
  String get personPhotoTooLarge => 'Das Bild darf maximal 2MB groß sein.';

  @override
  String get personPlaysSince => 'Spielt auf dem Instrument seit';

  @override
  String get personPlaysWithTeacher => 'Spielt beim Lehrer';

  @override
  String get personPleaseChoose => 'Bitte auswählen';

  @override
  String get personReactivate => 'Wieder aktivieren';

  @override
  String get personReactivateConfirm => 'Möchtest du die Person wirklich reaktivieren?';

  @override
  String get personReactivatePerson => 'Person reaktivieren';

  @override
  String get personReactivated => 'Die Person wurde erfolgreich wieder aktiviert';

  @override
  String personReactivatedAt(Object date) {
    return 'Reaktiviert am $date';
  }

  @override
  String get personRemarks => 'Anmerkungen';

  @override
  String get personRemoveAccount => 'Account entfernen';

  @override
  String get personRemoveAccountMessage => 'Möchtest du den Account wirklich aus der Instanz entfernen? Die Personendaten bleiben erhalten.';

  @override
  String get personRemoveEntry => 'Eintrag unwiderruflich entfernen?';

  @override
  String get personRemovePersonMessage => 'Möchtest du die Person wirklich entfernen? Alle zugehörigen Daten (Abwesenheiten, Notizen, etc.) gehen dabei verloren!';

  @override
  String get personRemovePhoto => 'Passbild entfernen';

  @override
  String get personRemovePhotoMessage => 'Möchtest du das Passbild wirklich entfernen?';

  @override
  String get personRemoved => 'Die Person wurde erfolgreich entfernt';

  @override
  String get personReplace => 'Ersetzen';

  @override
  String get personResetFailed => 'Fehler beim Zurücksetzen';

  @override
  String get personResetTalked => 'Zurücksetzen (Gespräch geführt)';

  @override
  String get personResetting => 'Wird zurückgesetzt...';

  @override
  String get personRole => 'Rolle';

  @override
  String get personRoleUpdated => 'Die Rolle wurde erfolgreich aktualisiert.';

  @override
  String get personSaveWithRole => 'Mit Rolle speichern';

  @override
  String get personSearchChurch => 'Gemeinde suchen';

  @override
  String get personShift => 'Schicht';

  @override
  String get personShiftPlan => 'Schichtplan';

  @override
  String get personSimilarExists => 'Ähnliche Person bereits vorhanden';

  @override
  String get personStartDate => 'Anfangsdatum';

  @override
  String get personTalkedTo => 'Mit Person gesprochen';

  @override
  String personTalkedToAt(Object date) {
    return 'Mit Person gesprochen ($date)';
  }

  @override
  String get personTargetGroup => 'Ziel-Gruppe';

  @override
  String get personTargetInstance => 'Ziel-Instanz';

  @override
  String get personTransferConfirm => 'Möchtest du die Person wirklich in die andere Instanz übertragen? Alle zugehörigen Daten (Abwesenheiten, Notizen, etc.) gehen dabei verloren!';

  @override
  String personTransferFrom(Object name) {
    return 'Übertragen von $name';
  }

  @override
  String get personTransferNotPossible => 'Übertragen nicht möglich';

  @override
  String get personTransferOther => 'In andere Instanz übertragen';

  @override
  String get personTransferPerson => 'Person übertragen';

  @override
  String get personTransferred => 'Die Person wurde erfolgreich übertragen';

  @override
  String personTransferredAt(Object date) {
    return 'Übertragen am $date';
  }

  @override
  String get personUntilRequired => 'Bis *';

  @override
  String personUpcomingEvents(Object count) {
    return 'Anstehende Termine ($count)';
  }

  @override
  String get personUpdateFailed => 'Fehler beim aktualisieren des Spielers';

  @override
  String personUpdateFailedWith(Object error) {
    return 'Fehler beim aktualisieren des Spielers: $error';
  }

  @override
  String get personUpdated => 'Die Spielerdaten wurden erfolgreich aktualisiert.';

  @override
  String get personUserAssigned => 'Benutzer wurde erfolgreich zugewiesen';

  @override
  String get personUserRemoveFailed => 'Fehler beim Entfernen des Benutzers';

  @override
  String get personUserRemoved => 'Der Benutzer wurde erfolgreich entfernt';

  @override
  String get personVocalRange => 'Stimmumfang';

  @override
  String personVoiceLeaderMessage(Object name) {
    return 'Mit der Stimmführer-Rolle kann $name die Kontaktdaten und anstehenden Termine aller Personen in der Stimme einsehen. Soll die Rolle vergeben werden?';
  }

  @override
  String get personVoiceLeaderStatusOnly => 'Nur Stimmführer-Status';

  @override
  String get planningAddAnotherPlan => 'Weiteren Ablaufplan anlegen';

  @override
  String get planningAddAnotherPlanMessage => 'Soll der neue Plan den aktuellen Ablauf übernehmen oder leer starten?';

  @override
  String get planningAddBlock => 'Programmblock hinzufügen';

  @override
  String get planningAddCurrentSongs => 'Aktuelle Werke hinzufügen';

  @override
  String get planningAddField => 'Feld hinzufügen';

  @override
  String get planningAddNoteField => 'Notizfeld hinzufügen';

  @override
  String get planningAddSong => 'Werk hinzufügen';

  @override
  String get planningAddSubItem => 'Unterpunkt hinzufügen';

  @override
  String get planningAgenda => 'Tagesordnung';

  @override
  String get planningAgendaExists => 'Ein Tagesordnungs-Platzhalter ist bereits vorhanden';

  @override
  String get planningAgendaInsertPos => 'Einfügeposition Tagesordnung';

  @override
  String planningAllPlans(Object count) {
    return 'Alle $count Pläne';
  }

  @override
  String get planningAlto => 'Alt';

  @override
  String planningAsOf(Object date) {
    return 'Stand: $date';
  }

  @override
  String get planningAssignDay => 'Tag zuordnen';

  @override
  String get planningAssignOtherDay => 'Anderem Tag zuordnen';

  @override
  String get planningAttendanceNotes => 'Anwesenheitsnotizen';

  @override
  String get planningBass => 'Bass';

  @override
  String get planningBlockDurationHint => 'Die Dauer ergibt sich aus den Unterpunkten.';

  @override
  String planningBlockHasItems(Object name, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Unterpunkte',
      one: '$count Unterpunkt',
    );
    return '„$name“ hat $_temp0.';
  }

  @override
  String get planningBlockNamePlaceholder => 'Name, z. B. Programm Jugendchor';

  @override
  String planningBlockSubHeader(num count, Object min) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Unterpunkte',
      one: '$count Unterpunkt',
    );
    return '$_temp0 · $min min';
  }

  @override
  String get planningBlocks => 'Programmblöcke';

  @override
  String get planningChooseEventFirst => 'Bitte wähle zuerst einen Termin aus.';

  @override
  String get planningChooseFieldMin => 'Bitte wähle mindestens ein Feld aus.';

  @override
  String get planningChooseSong => 'Werk auswählen';

  @override
  String get planningCollapseBlock => 'Block einklappen';

  @override
  String get planningConductors => 'Dirigenten';

  @override
  String get planningCopy => 'Kopie';

  @override
  String get planningCreateRunSheetFirst => 'Lege zuerst einen Ablauf für diesen Plan an.';

  @override
  String get planningCreateSectionalPlan => 'Registerprobenplan erstellen';

  @override
  String get planningCurrent => 'Aktuelle';

  @override
  String get planningDefaultTitle => 'Standardtitel verwenden';

  @override
  String get planningDefaultWord => 'Wort ';

  @override
  String get planningDeleteAll => 'Alles löschen';

  @override
  String get planningDeleteBlockConfirm => 'Block löschen?';

  @override
  String get planningDeleteBlockWithItems => 'Block mit Unterpunkten löschen';

  @override
  String get planningDeletePlan => 'Plan löschen';

  @override
  String get planningDeletePlanConfirm => 'Plan löschen?';

  @override
  String planningDeletePlanMessage(Object label) {
    return 'Der Plan „$label“ wird gelöscht.';
  }

  @override
  String get planningDeleteTemplate => 'Vorlage löschen';

  @override
  String get planningDeleteTemplateConfirm => 'Vorlage löschen?';

  @override
  String planningDeleteTemplateMessage(Object name) {
    return 'Die Vorlage „$name“ wird gelöscht. Bestehende Pläne bleiben unverändert.';
  }

  @override
  String get planningDissolveBlock => 'Block auflösen';

  @override
  String get planningEditBlock => 'Block bearbeiten';

  @override
  String get planningEditField => 'Feld bearbeiten';

  @override
  String get planningEditLink => 'Bearbeitungs-Link';

  @override
  String get planningEmpty => 'Leer';

  @override
  String get planningEnterFreeText => 'Freitext eingeben...';

  @override
  String get planningEnterItem => 'Programmpunkt eingeben...';

  @override
  String get planningEnterItemPlease => 'Bitte einen Programmpunkt eingeben.';

  @override
  String get planningEnterNamePlease => 'Bitte einen Namen eingeben.';

  @override
  String get planningEnterNote => 'Notiz eingeben...';

  @override
  String get planningEnterPerformer => 'Ausführenden eingeben...';

  @override
  String get planningExpandBlock => 'Block aufklappen';

  @override
  String get planningExport => 'Exportieren';

  @override
  String get planningExportPdf => 'PDF exportieren';

  @override
  String get planningExportPdfA5 => 'PDF exportieren (2x A5)';

  @override
  String get planningExportPdfAll => 'PDF exportieren (alle Pläne)';

  @override
  String get planningFields => 'Felder';

  @override
  String get planningFillRequired => 'Bitte fülle alle erforderlichen Felder aus.';

  @override
  String get planningFirstEvent => 'Dies ist die aktuell erste Veranstaltung';

  @override
  String planningFlutterBlockEntry(Object name, Object min) {
    return 'Programmblock: $name ($min min)';
  }

  @override
  String get planningFlutterConflictDraftApply => 'Entwurf übernehmen';

  @override
  String get planningFlutterConflictDraftDiscard => 'Verwerfen';

  @override
  String get planningFlutterConflictDraftMessage => 'Ein älterer Entwurf wurde wegen eines Konflikts nicht übernommen.';

  @override
  String get planningFlutterConflictDraftTitle => 'Entwurf nicht übernommen';

  @override
  String get planningFlutterDraftLost => 'Ablaufplan konnte nicht gespeichert werden – Änderungen gehen verloren';

  @override
  String get planningFlutterDraftRestored => 'Nicht gespeicherte Änderungen wiederhergestellt';

  @override
  String get planningFlutterDraftSavedLocally => 'Ablaufplan konnte nicht gespeichert werden – Entwurf lokal gesichert';

  @override
  String planningFlutterErrorWith(Object error) {
    return 'Fehler: $error';
  }

  @override
  String planningFlutterExportFailed(Object error) {
    return 'Fehler beim Export: $error';
  }

  @override
  String planningFlutterFieldEntry(Object name, Object min) {
    return 'Feld: $name ($min min)';
  }

  @override
  String get planningFlutterLive => 'Live';

  @override
  String get planningFlutterLiveMode => 'Live-Modus';

  @override
  String get planningFlutterLiveModeEnd => 'Live-Modus beenden';

  @override
  String get planningFlutterNoEvents => 'Keine Termine vorhanden';

  @override
  String get planningFlutterNoItems => 'Keine Programmpunkte';

  @override
  String get planningFlutterPdf2xA5 => 'PDF (2x A5)';

  @override
  String get planningFlutterPdfA4 => 'PDF (A4)';

  @override
  String get planningFlutterPlanChanged => 'Plan wurde inzwischen geändert';

  @override
  String get planningFlutterPlanChangedDraftLost => 'Plan wurde inzwischen geändert – Änderungen gehen verloren';

  @override
  String get planningFlutterPlanChangedDraftSaved => 'Plan wurde inzwischen geändert – Änderungen als Entwurf gesichert';

  @override
  String get planningFlutterPlanDeleted => 'Plan wurde inzwischen gelöscht';

  @override
  String get planningFlutterPlanDeletedDraftLost => 'Plan wurde inzwischen gelöscht – Änderungen gehen verloren';

  @override
  String get planningFlutterPlanDeletedDraftSaved => 'Plan wurde inzwischen gelöscht – Änderungen als Entwurf gesichert';

  @override
  String planningFlutterPlanPosition(Object index, Object total) {
    return '$index von $total';
  }

  @override
  String planningFlutterSaveFailedWith(Object error) {
    return 'Fehler beim Speichern: $error';
  }

  @override
  String planningFlutterShareFailedWith(Object error) {
    return 'Fehler beim Teilen: $error';
  }

  @override
  String get planningFlutterTelegramNotConfigured => 'Telegram nicht konfiguriert';

  @override
  String get planningFlutterTelegramPdf2x => 'Per Telegram senden (PDF 2x A5)';

  @override
  String get planningFlutterUnshareAction => 'Freigabe aufheben';

  @override
  String get planningGroupName => 'Gruppenname';

  @override
  String get planningGroups => 'Gruppen';

  @override
  String get planningHeadingLabel => 'Ablaufplan Überschrift';

  @override
  String get planningIncludeBranding => 'Branding einbeziehen';

  @override
  String get planningIndent => 'Einrücken';

  @override
  String get planningInfo => 'Info';

  @override
  String get planningInfoOptional => 'Info-Text (optional)';

  @override
  String get planningInfoOptionalEllipsis => 'Info-Text (optional)...';

  @override
  String get planningInsertAgenda => 'Tagesordnung einfügen';

  @override
  String get planningItem => 'Programmpunkt';

  @override
  String get planningLastEvent => 'Dies ist die aktuell letzte Veranstaltung';

  @override
  String get planningLinkCopied => 'Link in Zwischenablage kopiert';

  @override
  String get planningMinPlaceholder => 'min';

  @override
  String planningMinShort(Object min) {
    return '$min min';
  }

  @override
  String get planningMinutes => 'Minuten';

  @override
  String get planningMoveLeft => 'Nach links verschieben';

  @override
  String get planningMoveRight => 'Nach rechts verschieben';

  @override
  String get planningName => 'Name';

  @override
  String get planningNext => 'Nächste';

  @override
  String get planningNoPlan => 'Kein Plan verfügbar';

  @override
  String get planningNoPlanAvailable => 'Kein Ablaufplan verfügbar.';

  @override
  String get planningNoScoresInstrument => 'Keine Noten für dein Instrument';

  @override
  String get planningNote => 'Notiz';

  @override
  String get planningOnlyDissolve => 'Nur Block auflösen';

  @override
  String planningOnlyLabel(Object label) {
    return 'Nur $label';
  }

  @override
  String get planningOrgPlan => 'Organisationsplan';

  @override
  String get planningOutdent => 'Ausrücken';

  @override
  String get planningPerformance => 'Ausführung';

  @override
  String get planningPerformanceOptional => 'Ausführung (optional)';

  @override
  String get planningPerformer => 'Ausführender';

  @override
  String planningPlanHeader(Object label) {
    return 'Plan „$label“';
  }

  @override
  String get planningPlanOptions => 'Plan-Optionen';

  @override
  String get planningPrevious => 'Vorige';

  @override
  String get planningReadOnlyLink => 'Nur-Lesen-Link';

  @override
  String get planningRelatedAttendance => 'Zugehörige Anwesenheit';

  @override
  String get planningRename => 'Umbenennen';

  @override
  String get planningRenameHint => 'Leer lassen für den automatischen Namen.';

  @override
  String get planningRenamePlan => 'Plan umbenennen';

  @override
  String get planningResetPlan => 'Plan zurücksetzen';

  @override
  String get planningResetPlanMessage => 'Möchtest du den Plan für diese Veranstaltung wirklich zurücksetzen? Alle Änderungen gehen verloren.';

  @override
  String get planningRunSheet => 'Ablauf';

  @override
  String get planningSaveAsTemplate => 'Als Vorlage speichern';

  @override
  String get planningSectionalPlan => 'Registerprobenplan';

  @override
  String planningSectionalPlanTitle(Object tenant) {
    return '$tenant Registerprobenplan';
  }

  @override
  String get planningSendingTelegram => 'Plan wird per Telegram gesendet...';

  @override
  String get planningShareLink => 'Link teilen';

  @override
  String get planningShareWithMembers => 'Plan mit Mitgliedern teilen';

  @override
  String get planningSoprano => 'Sopran';

  @override
  String get planningStrings => 'Streicher';

  @override
  String get planningSubItemInfoPlaceholder => 'Info-Text (optional), z. B. Liedtitel';

  @override
  String get planningSubItemPlaceholder => 'Programmpunkt, z. B. Gruppenlied';

  @override
  String get planningTelegramImageShort => 'Per Telegram (Bild)';

  @override
  String get planningTelegramPdfShort => 'Per Telegram (PDF)';

  @override
  String get planningTemplateSaveFailed => 'Die Vorlage konnte nicht gespeichert werden.';

  @override
  String planningTemplateSaved(Object name) {
    return '„$name“ als Vorlage gespeichert';
  }

  @override
  String get planningTemplates => 'Vorlagen';

  @override
  String get planningTenor => 'Tenor';

  @override
  String get planningTimeMinutes => 'Zeit in Minuten';

  @override
  String get planningToday => '· heute';

  @override
  String get planningUnshare => 'Aufheben';

  @override
  String get planningUnshareConfirm => 'Freigabe aufheben?';

  @override
  String get planningUnshareMessage => 'Der öffentliche Link wird ungültig. Fortfahren?';

  @override
  String get planningUnshared => 'Freigabe aufgehoben';

  @override
  String get planningUpdate => 'Updaten';

  @override
  String get planningUpdateTemplate => 'Vorlage aktualisieren';

  @override
  String get planningWoodwinds => 'Holzbläser';

  @override
  String get plansAddFieldMin => 'Bitte mindestens ein Feld hinzufügen.';

  @override
  String get plansAddOrgFailed => 'Fehler beim Hinzufügen zur Organisation';

  @override
  String plansAddedToOrg(Object org) {
    return 'Plan zur Organisation \"$org\" hinzugefügt';
  }

  @override
  String get plansApplyTemplate => 'Vorlage anwenden';

  @override
  String get plansBranding => 'Branding';

  @override
  String plansCalendarLinkMessage(Object link) {
    return 'Kopiere den folgenden Link in deine Kalender-App:\n\n$link';
  }

  @override
  String get plansCopyLink => 'Link kopieren';

  @override
  String get plansDate => 'Datum';

  @override
  String get plansDeleteFailed => 'Fehler beim Löschen';

  @override
  String plansDeletePlanForever(Object title) {
    return '\"$title\" endgültig löschen?';
  }

  @override
  String get plansDetailedCalendar => 'Detailliert (je Programmpunkt)';

  @override
  String get plansDiscardNew => 'Aktuellen Plan verwerfen und einen neuen erstellen?';

  @override
  String get plansDurationMin => 'Dauer (min)';

  @override
  String get plansEditStartTime => 'Startzeit bearbeiten';

  @override
  String get plansEditTitle => 'Titel bearbeiten';

  @override
  String get plansEnterNotePlease => 'Bitte eine Notiz eingeben.';

  @override
  String get plansFillDurations => 'Bitte alle Dauern ausfüllen.';

  @override
  String get plansFlutterAddToOrg => 'Zur Organisation hinzufügen';

  @override
  String plansFlutterFieldsCount(Object count) {
    return '$count Felder';
  }

  @override
  String get plansFlutterHideTab => 'Tab ausblenden';

  @override
  String plansFlutterInOrg(Object name) {
    return 'In Organisation \"$name\"';
  }

  @override
  String get plansFlutterOrgPlansTitle => 'Organisationspläne';

  @override
  String get plansFlutterShowAsTab => 'Als Tab anzeigen';

  @override
  String get plansImageA4 => 'Bild (A4)';

  @override
  String get plansLinkCopied => 'Link kopiert';

  @override
  String get plansLinkCreated => 'Link erstellt und kopiert';

  @override
  String get plansLinkFailed => 'Fehler beim Erstellen des Links';

  @override
  String get plansLinkInvalid => 'Link ungültig oder abgelaufen.';

  @override
  String get plansManage => 'Verwalten';

  @override
  String get plansMyPlans => 'Meine Pläne';

  @override
  String get plansNewPlan => 'Neuer Plan';

  @override
  String get plansNoOrg => 'Diese Instanz ist keiner Organisation zugeordnet.';

  @override
  String get plansNoPlans => 'Keine Pläne vorhanden.';

  @override
  String get plansNoTemplate => 'Keine Vorlage ausgewählt.';

  @override
  String get plansNoUpcomingOrgPlans => 'Keine bevorstehenden Org-Pläne. Pläne können über die Ablaufplanung zur Organisation hinzugefügt werden.';

  @override
  String get plansNoUpcomingPlans => 'Keine bevorstehenden Org-Pläne vorhanden.';

  @override
  String get plansNotFound => 'Plan nicht gefunden. Der Link ist möglicherweise abgelaufen oder ungültig.';

  @override
  String get plansOpenGuide => 'Anleitung öffnen';

  @override
  String get plansOpenPlanning => 'Ablaufplanung öffnen';

  @override
  String get plansOrgPlan => 'Org-Plan';

  @override
  String get plansOrgPlans => 'Org-Pläne';

  @override
  String plansOrgSuffix(Object title) {
    return '$title (Org)';
  }

  @override
  String get plansOrgTemplates => '── Org-Vorlagen ──';

  @override
  String get plansPastPlans => 'Vergangene Pläne';

  @override
  String get plansPerformerOptional => 'Ausführender (optional)';

  @override
  String get plansPlan => 'Plan';

  @override
  String get plansPlanning => 'Ablaufplanung';

  @override
  String plansPoints(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '$count Punkt',
    );
    return '$_temp0';
  }

  @override
  String get plansPublicLink => 'Öffentlicher Link';

  @override
  String get plansPublicLinkActive => 'Öffentlicher Link aktiv. Alle Org-Pläne sind für jeden mit dem Link einsehbar.';

  @override
  String get plansRemoveOrgFailed => 'Fehler beim Entfernen aus der Organisation';

  @override
  String get plansRemovedFromOrg => 'Plan aus Organisation entfernt';

  @override
  String get plansReplaceWithTemplate => 'Aktuellen Ablauf durch die Vorlage ersetzen?';

  @override
  String get plansRestore => 'Wiederherstellen';

  @override
  String get plansRestoreTemplate => 'Vorlage wiederherstellen';

  @override
  String plansRestoreTemplateMessage(Object name) {
    return 'Alle Änderungen verwerfen und die Standardwerte der Vorlage „$name“ wiederherstellen?';
  }

  @override
  String get plansRevokeLink => 'Link widerrufen';

  @override
  String get plansRunSheet => 'Ablaufplan';

  @override
  String get plansSaveFailed => 'Fehler beim Speichern';

  @override
  String get plansSavePlanFailed => 'Fehler beim Speichern des Plans';

  @override
  String get plansShareExport => 'Teilen & Exportieren';

  @override
  String get plansSimpleCalendar => 'Einfach (1 Termin je Plan)';

  @override
  String get plansSubscribeCalendar => 'Kalender abonnieren';

  @override
  String get plansTemplate => 'Vorlage';

  @override
  String get plansTitle => 'Titel';

  @override
  String get protocolAdd => 'Hinzufügen';

  @override
  String get protocolAddPoint => 'Punkt hinzufügen';

  @override
  String get protocolAgenda => 'Tagesordnung';

  @override
  String get protocolAgendaItem => 'Tagesordnungspunkt';

  @override
  String get protocolAlwaysVisible => 'Immer sichtbar, unabhängig vom Punkt';

  @override
  String get protocolAutoSaved => 'Wird automatisch gespeichert';

  @override
  String protocolAutoSavedAt(Object time) {
    return 'Automatisch gespeichert · $time';
  }

  @override
  String get protocolChangesAutoSaved => 'Änderungen werden automatisch gespeichert';

  @override
  String get protocolCloseFailed => 'Nicht alle Themen konnten als erledigt markiert werden';

  @override
  String get protocolCloseTopics => 'Themen als erledigt markieren';

  @override
  String get protocolCreateFailed => 'Protokoll konnte nicht angelegt werden';

  @override
  String protocolDecidedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Themen',
      one: '$count Thema',
    );
    return '$_temp0 beschlossen';
  }

  @override
  String protocolDiscussedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Themen',
      one: '$count Thema',
    );
    return '$_temp0 besprochen';
  }

  @override
  String get protocolDragResize => 'Ziehen, um die Breite anzupassen (Doppelklick setzt zurück)';

  @override
  String protocolDueShort(Object date) {
    return 'fällig $date';
  }

  @override
  String get protocolDurationMinutes => 'Dauer in Minuten';

  @override
  String get protocolEarlierItem => 'Früherer Programmpunkt';

  @override
  String get protocolEditAfterPublish => 'Die Leitung kann das Protokoll auch nach der Freigabe noch bearbeiten. Änderungen werden mit Datum angezeigt.';

  @override
  String protocolExcusedCount(Object count) {
    return '$count entschuldigt · ';
  }

  @override
  String protocolExcusedList(Object count) {
    return 'Entschuldigt ($count)';
  }

  @override
  String protocolFileName(Object title, Object date) {
    return 'Protokoll $title $date';
  }

  @override
  String get protocolFlutterChooseLeft => 'Wähle links einen Punkt aus.';

  @override
  String get protocolFlutterDoneLower => 'erledigt';

  @override
  String get protocolFlutterKeepDraft => 'Als Entwurf lassen';

  @override
  String get protocolFlutterPlanEmptyShort => 'Der Ablaufplan ist noch leer.';

  @override
  String get protocolFlutterPublishNotify => 'Freigeben & benachrichtigen';

  @override
  String get protocolFlutterRepublishNotify => 'Erneut freigeben & benachrichtigen';

  @override
  String protocolForNames(Object names) {
    return 'für $names';
  }

  @override
  String get protocolFromAttendance => 'aus der Anwesenheit';

  @override
  String get protocolFurtherTasks => 'Weitere Aufgaben';

  @override
  String get protocolGeneral => 'Allgemein';

  @override
  String get protocolGeneralNotes => 'Allgemeine Notizen';

  @override
  String get protocolGeneralTask => 'Aufgabe zu den allgemeinen Notizen';

  @override
  String get protocolHasNotes => 'Enthält Notizen';

  @override
  String get protocolListFromAttendance => 'Die Liste kommt aus der Anwesenheit des Termins.';

  @override
  String get protocolLoadFailed => 'Protokoll konnte nicht geladen werden.';

  @override
  String get protocolMayRead => 'Lesen dürfen';

  @override
  String get protocolMoreNotes => 'Weitere Notizen';

  @override
  String get protocolMoreNotesHint => 'Notizen zu Punkten, die nicht mehr im Ablaufplan stehen.';

  @override
  String protocolMoreNotesTitle(Object title) {
    return 'Weitere Notizen · $title';
  }

  @override
  String get protocolMoreTasks => 'Weitere Aufgaben dieser Sitzung';

  @override
  String get protocolNextPoint => 'Nächster Punkt';

  @override
  String get protocolNoNotes => 'Keine Notizen';

  @override
  String get protocolNoTasksYet => 'Noch keine Aufgaben. Lege sie direkt bei einem Punkt an.';

  @override
  String get protocolNobodyPresent => 'Niemand als anwesend eingetragen';

  @override
  String get protocolNotInPlan => 'Dieser Punkt steht nicht mehr im Ablaufplan. Die Notizen bleiben erhalten.';

  @override
  String get protocolNotPublished => 'Dieses Protokoll ist noch nicht freigegeben.';

  @override
  String get protocolNotPublishedHint => 'Sobald die Leitung es freigibt, kannst du es hier lesen.';

  @override
  String get protocolNoted => 'Notiert';

  @override
  String get protocolNotes => 'Notizen';

  @override
  String get protocolNotesSaveFailed => 'Notizen konnten nicht gespeichert werden. Prüfe deine Verbindung.';

  @override
  String get protocolNotified => 'Benachrichtigt werden';

  @override
  String get protocolOpen => 'Offen';

  @override
  String protocolOthersList(Object count) {
    return 'Nicht da / offen ($count)';
  }

  @override
  String get protocolOutcome => 'Ergebnis';

  @override
  String get protocolOutcomeSaveFailed => 'Ergebnis konnte nicht gespeichert werden';

  @override
  String protocolPage(Object i, Object n) {
    return 'Seite $i von $n';
  }

  @override
  String get protocolParticipants => 'Teilnehmende';

  @override
  String get protocolPdfFailed => 'PDF konnte nicht erstellt werden';

  @override
  String get protocolPdfFailedNotify => 'PDF konnte nicht erstellt werden, die Benachrichtigung geht ohne PDF raus';

  @override
  String protocolPdfTitle(Object title) {
    return 'Protokoll · $title';
  }

  @override
  String get protocolPlanEmpty => 'Der Ablaufplan ist noch leer. Füge einen Punkt hinzu oder schreib in die Notizen.';

  @override
  String get protocolPoint => 'Punkt';

  @override
  String get protocolPointFailed => 'Punkt konnte nicht hinzugefügt werden';

  @override
  String get protocolPointNotes => 'Notizen zum Punkt';

  @override
  String protocolPostponedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Themen',
      one: '$count Thema',
    );
    return '$_temp0 vertagt';
  }

  @override
  String get protocolPresent => 'Anwesend';

  @override
  String protocolPresentCount(Object count) {
    return '$count anwesend';
  }

  @override
  String protocolPresentList(Object count) {
    return 'Anwesend ($count)';
  }

  @override
  String get protocolPublish => 'Protokoll freigeben';

  @override
  String get protocolPublishFailed => 'Protokoll konnte nicht freigegeben werden';

  @override
  String get protocolPublishShort => 'Freigeben';

  @override
  String get protocolPublished => 'Protokoll freigegeben';

  @override
  String protocolReadAll(Object type) {
    return 'alle Mitglieder (Termintyp „$type“ hat keine Gruppen)';
  }

  @override
  String protocolReadGroups(Object type) {
    return 'die Gruppen aus dem Termintyp „$type“';
  }

  @override
  String protocolRecipients(Object count) {
    return '$count Anwesende';
  }

  @override
  String get protocolRepublish => 'Erneut freigeben';

  @override
  String get protocolResizeAgenda => 'Breite der Tagesordnung anpassen';

  @override
  String get protocolResizeGeneral => 'Breite der allgemeinen Notizen anpassen';

  @override
  String protocolResponsible(Object name) {
    return 'Verantwortlich: $name';
  }

  @override
  String get protocolRetry => 'Erneut versuchen';

  @override
  String get protocolRunSheet => 'Ablaufplan';

  @override
  String protocolRunning(Object name, Object min) {
    return 'Läuft: $name · noch $min min';
  }

  @override
  String get protocolSaving => 'Speichert …';

  @override
  String get protocolSendPdf => 'Protokoll als PDF mitschicken';

  @override
  String protocolSessionTasks(Object count) {
    return 'Aufgaben dieser Sitzung · $count';
  }

  @override
  String get protocolSharePdf => 'Als PDF teilen';

  @override
  String get protocolShortcutNext => '⌘/Strg ↓';

  @override
  String get protocolSpontaneous => 'Spontaner Punkt';

  @override
  String get protocolSpontaneousHint => 'Wird als neues Thema angelegt und im Ablaufplan ergänzt.';

  @override
  String get protocolSuggestNext => ' · wird beim nächsten Termin vorgeschlagen';

  @override
  String get protocolSummary => 'Zusammenfassung';

  @override
  String protocolTaskCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '$count Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String protocolTaskOwners(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '$count Person',
    );
    return ' · $_temp0 mit Aufgaben';
  }

  @override
  String protocolTaskRef(Object title) {
    return 'Aufgabe: $title';
  }

  @override
  String get protocolTitle => 'Protokoll';

  @override
  String protocolTop(Object n) {
    return 'TOP $n';
  }

  @override
  String protocolTopicRef(Object title) {
    return 'Thema: $title';
  }

  @override
  String get protocolViaTelegram => 'Per Telegram als Dokument';

  @override
  String get protocolVisibility => 'Sichtbarkeit';

  @override
  String get protocolWholeMeeting => 'Gilt für die ganze Sitzung, unabhängig vom Punkt.';

  @override
  String protocolWithoutNotes(Object count) {
    return 'Noch ohne Notizen: $count';
  }

  @override
  String protocolWithoutOutcome(Object count) {
    return 'Ohne Ergebnis: $count';
  }

  @override
  String redesignAbsenceAffects(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Das betrifft $count Termine',
      one: 'Das betrifft 1 Termin',
      zero: 'In diesem Zeitraum hast du keine Termine.',
    );
    return '$_temp0';
  }

  @override
  String get redesignAbsenceChooseEnd => 'Tippe auf den letzten Tag.';

  @override
  String get redesignAbsenceChooseStart => 'Tippe auf den ersten Tag.';

  @override
  String get redesignAbsenceNextMonth => 'Nächster Monat';

  @override
  String get redesignAbsencePause => 'Pausieren';

  @override
  String get redesignAbsencePauseButton => 'Pausieren …';

  @override
  String get redesignAbsencePauseHint => 'Wenn du länger nicht kannst, kannst du dich pausieren. Die Leitung sieht dann, dass du gerade nicht dabei bist.';

  @override
  String get redesignAbsencePeriod => 'Zeitraum';

  @override
  String get redesignAbsencePrevMonth => 'Voriger Monat';

  @override
  String get redesignAbsenceRange => 'Zeitraum abwesend';

  @override
  String get redesignAbsenceReason => 'Grund';

  @override
  String get redesignAbsenceReasonHint => 'z. B. Urlaub';

  @override
  String get redesignAbsenceReset => 'Zeitraum zurücksetzen';

  @override
  String get redesignAbsenceSubmit => 'Abwesenheit eintragen';

  @override
  String get redesignAbsenceTitle => 'Abwesenheit';

  @override
  String get redesignAdminTitle => 'Verwaltung';

  @override
  String get redesignAppearanceAppIcon => 'App-Symbol';

  @override
  String get redesignAppearanceAppIconFollow => 'App-Symbol in Farbwelt';

  @override
  String get redesignAppearanceAppIconHint => 'Das Symbol auf dem Home-Bildschirm wechselt mit der Farbwelt.';

  @override
  String get redesignAppearanceAutoHint => 'Automatisch folgt der Einstellung deines Geräts.';

  @override
  String get redesignAppearanceBrightness => 'Hell oder dunkel';

  @override
  String get redesignAppearanceDeviceOnly => 'Diese Einstellungen gelten nur auf diesem Gerät.';

  @override
  String get redesignAppearanceModeAuto => 'Automatisch';

  @override
  String get redesignAppearanceModeDark => 'Dunkel';

  @override
  String get redesignAppearanceModeLight => 'Hell';

  @override
  String get redesignAppearancePreview => 'Vorschau der gewählten Farbwelt';

  @override
  String get redesignAppearancePreviewTitle => 'Probe';

  @override
  String get redesignAppearanceStageAlwaysDark => 'Bühne ist immer dunkel.';

  @override
  String get redesignAppearanceTitle => 'Darstellung';

  @override
  String get redesignAppearanceWorld => 'Farbwelt';

  @override
  String get redesignAppearanceWorldClear => 'Klar';

  @override
  String get redesignAppearanceWorldClearHint => 'Schwarz auf Weiß, höchster Kontrast';

  @override
  String get redesignAppearanceWorldConcertHall => 'Konzertsaal';

  @override
  String get redesignAppearanceWorldConcertHallHint => 'Warm, mit Serifen-Überschriften';

  @override
  String get redesignAppearanceWorldNightBlue => 'Nachtblau';

  @override
  String get redesignAppearanceWorldNightBlueHint => 'Kräftig und rund';

  @override
  String get redesignAppearanceWorldPetrol => 'Petrol';

  @override
  String get redesignAppearanceWorldPetrolHint => 'Ruhig und klar (Standard)';

  @override
  String get redesignAppearanceWorldStage => 'Bühne';

  @override
  String get redesignAppearanceWorldStageHint => 'Immer dunkel, für Abende und Proben';

  @override
  String get redesignApplicantOtherGroup => 'Andere Gruppe beitreten';

  @override
  String get redesignApplicantTitle => 'Bewerbung';

  @override
  String get redesignApplicantWaiting => 'Deine Anmeldung wird geprüft';

  @override
  String redesignApplicantWaitingFor(Object group) {
    return 'Deine Anmeldung bei $group wird geprüft';
  }

  @override
  String get redesignBulkActionArchive => 'Archivieren';

  @override
  String get redesignBulkActionGroup => 'Register';

  @override
  String get redesignBulkActionPause => 'Pausieren';

  @override
  String redesignBulkArchiveConfirm(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen archivieren?',
      one: '1 Person archivieren?',
    );
    return '$_temp0';
  }

  @override
  String get redesignBulkArchiveHint => 'Archivierte Mitglieder findest du unter Archiv.';

  @override
  String get redesignBulkClear => 'Auswahl aufheben';

  @override
  String redesignBulkDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen geändert',
      one: '1 Person geändert',
    );
    return '$_temp0';
  }

  @override
  String redesignBulkFailed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen fehlgeschlagen',
      one: '1 Änderung fehlgeschlagen',
    );
    return '$_temp0';
  }

  @override
  String get redesignBulkHint => 'Mitglieder antippen, dann unten eine Aktion wählen.';

  @override
  String get redesignBulkNoGroup => 'Ohne Register';

  @override
  String get redesignBulkPauseReason => 'Grund der Pause';

  @override
  String get redesignBulkPickGroup => 'Neues Register';

  @override
  String get redesignBulkSearch => 'Mitglied suchen';

  @override
  String redesignBulkSelectGroup(Object group) {
    return 'Alle in $group';
  }

  @override
  String redesignBulkSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '1 ausgewählt',
      zero: 'Keine Auswahl',
    );
    return '$_temp0';
  }

  @override
  String get redesignBulkTitle => 'Mitglieder bearbeiten';

  @override
  String get redesignCommonAll => 'Alle';

  @override
  String get redesignCommonCancel => 'Abbrechen';

  @override
  String get redesignCommonDone => 'Fertig';

  @override
  String get redesignCommonRetry => 'Erneut versuchen';

  @override
  String get redesignComposeBody => 'Text';

  @override
  String get redesignComposeGroups => 'Register wählen';

  @override
  String get redesignComposeHint => 'Die Mitteilung erscheint bei allen Empfängern unter Mitteilungen.';

  @override
  String get redesignComposeMissing => 'Betreff, Text und mindestens ein Versandweg fehlen noch.';

  @override
  String get redesignComposeSend => 'Senden';

  @override
  String get redesignComposeSubject => 'Betreff';

  @override
  String get redesignComposeTitle => 'Mitteilung schreiben';

  @override
  String get redesignComposeTo => 'An wen?';

  @override
  String get redesignCreateChooseType => 'Art wählen';

  @override
  String get redesignCreateDate => 'Datum';

  @override
  String redesignCreateDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateDeadline => 'Abmeldeschluss';

  @override
  String get redesignCreateDeadline24h => '24 Std. vorher';

  @override
  String get redesignCreateDeadline2d => '2 Tage vorher';

  @override
  String get redesignCreateDeadlineHint => 'Danach können sich Mitglieder nicht mehr selbst an- oder abmelden.';

  @override
  String get redesignCreateDeadlineNone => 'Keiner';

  @override
  String get redesignCreateDeadlineWeek => '1 Woche vorher';

  @override
  String get redesignCreateDiscard => 'Verwerfen';

  @override
  String get redesignCreateDiscardBody => 'Deine Eingaben gehen verloren.';

  @override
  String get redesignCreateDiscardTitle => 'Termin verwerfen?';

  @override
  String get redesignCreateDuration => 'Dauer';

  @override
  String redesignCreateDuty(Object weekday) {
    return 'Benötigt am $weekday';
  }

  @override
  String redesignCreateDutyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine',
      one: '1 Termin',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateEnd => 'Ende';

  @override
  String get redesignCreateFewer => 'Weniger';

  @override
  String get redesignCreateFewerDays => 'Einen Tag weniger';

  @override
  String redesignCreateHolidayHits(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine fallen in Ferien oder auf Feiertage',
      one: '1 Termin fällt in Ferien oder auf einen Feiertag',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateInvited => 'Wer ist eingeladen?';

  @override
  String redesignCreateInvitedAll(Object count) {
    return 'Alle · $count';
  }

  @override
  String redesignCreateInvitedGroups(Object groups, Object count) {
    return '$groups · $count';
  }

  @override
  String get redesignCreateInvitedHint => 'Festgelegt durch die Art';

  @override
  String get redesignCreateKeepEditing => 'Weiter bearbeiten';

  @override
  String get redesignCreateLaterHint => 'Infotext, Anhang, Checkliste und Ablauf bearbeitest du danach im Termin.';

  @override
  String get redesignCreateMore => 'Mehr';

  @override
  String get redesignCreateMoreDates => 'Weitere Daten';

  @override
  String get redesignCreateMoreDatesNone => 'Keine';

  @override
  String get redesignCreateMoreDays => 'Einen Tag mehr';

  @override
  String get redesignCreateNoPermission => 'Du darfst keine Termine anlegen.';

  @override
  String get redesignCreateNoTypes => 'Es gibt noch keine Termin-Art. Lege zuerst eine in den Einstellungen an.';

  @override
  String get redesignCreatePlace => 'Ort';

  @override
  String get redesignCreatePlaceHint => 'z. B. Probenraum, Musterstr. 1';

  @override
  String redesignCreateRepeatBiweekly(Object date) {
    return 'Alle 2 Wochen bis $date';
  }

  @override
  String get redesignCreateRepeatBiweeklyOption => 'Alle 2 Wochen';

  @override
  String redesignCreateRepeatCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine',
      one: '1 Termin',
    );
    return '$_temp0';
  }

  @override
  String redesignCreateRepeatCustom(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Tage',
      one: '1 weiterer Tag',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateRepeatCustomOption => 'Einzelne Tage';

  @override
  String get redesignCreateRepeatHoliday => 'Ferien oder Feiertag';

  @override
  String redesignCreateRepeatMax(Object count) {
    return 'Höchstens $count Termine auf einmal.';
  }

  @override
  String get redesignCreateRepeatOnce => 'Einmalig';

  @override
  String get redesignCreateRepeatPick => 'Tage im Kalender wählen';

  @override
  String get redesignCreateRepeatSkipHolidays => 'Ferien und Feiertage auslassen';

  @override
  String get redesignCreateRepeatUntil => 'Bis';

  @override
  String redesignCreateRepeatWeekly(Object weekday, Object date) {
    return 'Jeden $weekday bis $date';
  }

  @override
  String get redesignCreateRepeatWeeklyOption => 'Jede Woche';

  @override
  String get redesignCreateSongs => 'Werke';

  @override
  String redesignCreateSongsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Werke',
      one: '1 Werk',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateSongsNone => 'Keine';

  @override
  String get redesignCreateStart => 'Beginn';

  @override
  String get redesignCreateSubmit => 'Anlegen';

  @override
  String redesignCreateSubmitMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine anlegen',
      one: 'Termin anlegen',
    );
    return '$_temp0';
  }

  @override
  String redesignCreateSummaryBiweekly(Object weekday) {
    return 'alle 2 Wochen am $weekday';
  }

  @override
  String redesignCreateSummaryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Es werden $count Termine angelegt',
      one: 'Es wird 1 Termin angelegt',
    );
    return '$_temp0';
  }

  @override
  String redesignCreateSummaryRange(Object from, Object until) {
    return '$from bis $until';
  }

  @override
  String redesignCreateSummaryWeekly(Object weekday) {
    return 'jeden $weekday';
  }

  @override
  String get redesignCreateTemplate => 'Vorlage';

  @override
  String get redesignCreateTemplateHint => 'Füllt Art, Titel, Zeit und Ort vor. Alles bleibt änderbar.';

  @override
  String get redesignCreateTime => 'Zeit';

  @override
  String get redesignCreateTitle => 'Neuer Termin';

  @override
  String get redesignCreateTitleLabel => 'Titel';

  @override
  String get redesignCreateType => 'Art';

  @override
  String redesignEventAllDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen als anwesend',
      one: '1 Person als anwesend',
    );
    return '$_temp0';
  }

  @override
  String get redesignEventAllOpenPresent => 'Alle Offenen als anwesend';

  @override
  String get redesignEventAnswers => 'Rückmeldungen';

  @override
  String get redesignEventBusyLeave => 'Bitte warte, bis alles gespeichert ist.';

  @override
  String redesignEventCountAbsent(Object count) {
    return '$count fehlt';
  }

  @override
  String redesignEventCountExcused(Object count) {
    return '$count entsch.';
  }

  @override
  String redesignEventCountLate(Object count) {
    return '$count später';
  }

  @override
  String redesignEventCountNoAnswer(Object count) {
    return '$count ohne Antwort';
  }

  @override
  String redesignEventCountOpen(Object count) {
    return '$count offen';
  }

  @override
  String redesignEventCountPresent(Object count) {
    return '$count da';
  }

  @override
  String get redesignEventDelete => 'Termin löschen';

  @override
  String get redesignEventDeleted => 'Termin gelöscht';

  @override
  String get redesignEventDetails => 'Alle Details';

  @override
  String redesignEventInvited(Object count) {
    return '$count eingeladen';
  }

  @override
  String get redesignEventKeyboardHint => 'Tastatur: A anwesend · V verspätet · F fehlt · ↑↓ nächste Person · ⌘Z oder Strg+Z rückgängig';

  @override
  String get redesignEventMore => 'Alle Details und Bearbeiten';

  @override
  String get redesignEventMoreHint => 'Ablauf, Checkliste, Werke und Notizen';

  @override
  String redesignEventMoreStatus(Object name) {
    return 'Weitere Status und Notiz für $name';
  }

  @override
  String get redesignEventNeutralHint => 'zählt nicht';

  @override
  String get redesignEventNoMatch => 'Niemand passt zur Suche.';

  @override
  String get redesignEventNoPersons => 'Für diesen Termin sind noch keine Personen eingetragen.';

  @override
  String get redesignEventNotFound => 'Dieser Termin wurde nicht gefunden.';

  @override
  String get redesignEventNote => 'Notiz für diesen Termin';

  @override
  String get redesignEventNoteHint => 'z. B. Grund oder Uhrzeit';

  @override
  String get redesignEventPlan => 'Ablauf ansehen';

  @override
  String get redesignEventPlanHint => 'Ablaufplan, am Termin-Tag live';

  @override
  String redesignEventRegisterEmpty(Object group, Object count) {
    return '$group: 0 von $count da.';
  }

  @override
  String redesignEventRegisterNames(num count, Object names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names haben abgesagt.',
      one: '$names hat abgesagt.',
    );
    return '$_temp0';
  }

  @override
  String get redesignEventSaving => 'Wird gespeichert …';

  @override
  String get redesignEventSearch => 'Person suchen';

  @override
  String get redesignEventSearchClose => 'Suche schließen';

  @override
  String get redesignEventSearchHint => 'Name';

  @override
  String get redesignEventSignouts => 'Abmeldungen';

  @override
  String get redesignEventStatus => 'Status';

  @override
  String get redesignEventTabOverview => 'Überblick';

  @override
  String get redesignEventTabRecord => 'Anwesenheit';

  @override
  String redesignEventToastReset(Object name) {
    return '$name: zurückgesetzt';
  }

  @override
  String redesignEventToastSet(Object name, Object status) {
    return '$name: $status';
  }

  @override
  String get redesignEventUndo => 'Rückgängig';

  @override
  String get redesignEventUndone => 'Rückgängig gemacht';

  @override
  String get redesignEventsAbsent => 'Abwesend …';

  @override
  String get redesignEventsCreateFirst => 'Ersten Termin anlegen';

  @override
  String get redesignEventsEmpty => 'Noch keine Termine. Leg die erste Probe an.';

  @override
  String get redesignEventsLastWeek => 'Letzte 7 Tage';

  @override
  String get redesignEventsNew => 'Neuer Termin';

  @override
  String get redesignEventsNo => 'Abmelden';

  @override
  String get redesignEventsNoMatch => 'Keine Termine passen zur Suche.';

  @override
  String get redesignEventsNoPast => 'Noch keine vergangenen Termine.';

  @override
  String get redesignEventsPast => 'Vergangen';

  @override
  String redesignEventsPastAverage(Object percent) {
    return 'Vergangen · Ø $percent %';
  }

  @override
  String redesignEventsPastOwn(Object percent) {
    return 'Vergangen · $percent % da';
  }

  @override
  String redesignEventsPercentPresent(Object percent) {
    return '$percent % anwesend';
  }

  @override
  String get redesignEventsSearch => 'Termine durchsuchen';

  @override
  String get redesignEventsSearchClose => 'Suche schließen';

  @override
  String get redesignEventsSearchHint => 'Titel oder Ort';

  @override
  String get redesignEventsShowAll => 'Wieder alle Termine zeigen';

  @override
  String get redesignEventsUpcoming => 'Kommend';

  @override
  String redesignEventsWaiting(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine warten auf deine Antwort',
      one: '1 Termin wartet auf deine Antwort',
    );
    return '$_temp0';
  }

  @override
  String get redesignEventsYes => 'Dabei';

  @override
  String redesignFilesActions(Object name) {
    return 'Aktionen für $name';
  }

  @override
  String get redesignFilesColName => 'Name';

  @override
  String get redesignFilesColPart => 'Stimme';

  @override
  String get redesignFilesColType => 'Typ';

  @override
  String redesignFilesConflictMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Für $count Dateien gibt es schon eine Datei mit gleichem Namen oder für dieselbe Stimme:',
      one: 'Für 1 Datei gibt es schon eine Datei mit gleichem Namen oder für dieselbe Stimme:',
    );
    return '$_temp0';
  }

  @override
  String get redesignFilesConflictTitle => 'Schon vorhanden';

  @override
  String get redesignFilesDelete => 'Löschen';

  @override
  String redesignFilesDeletedMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien gelöscht',
      one: '1 Datei gelöscht',
    );
    return '$_temp0';
  }

  @override
  String redesignFilesDeletedOne(Object name) {
    return '„$name“ gelöscht';
  }

  @override
  String get redesignFilesDismiss => 'Ausblenden';

  @override
  String get redesignFilesDone => 'Fertig';

  @override
  String get redesignFilesDownload => 'Herunterladen';

  @override
  String get redesignFilesDownloadAll => 'Alle als ZIP';

  @override
  String get redesignFilesDownloadZip => 'Als ZIP laden';

  @override
  String get redesignFilesDropHint => 'Dateien hierher ziehen oder „Hochladen“ wählen.';

  @override
  String redesignFilesDropOverlay(Object name) {
    return 'Loslassen, um sie zu „$name“ hochzuladen';
  }

  @override
  String get redesignFilesFailed => 'Fehlgeschlagen';

  @override
  String get redesignFilesKeepBoth => 'Beide behalten';

  @override
  String get redesignFilesOpen => 'Öffnen';

  @override
  String get redesignFilesOtherCategory => 'Sonstige …';

  @override
  String get redesignFilesPickHint => 'Klicken, um Dateien auszuwählen.';

  @override
  String redesignFilesQueueDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien hochgeladen',
      one: '1 Datei hochgeladen',
    );
    return '$_temp0';
  }

  @override
  String redesignFilesQueueTitle(Object done, Object total) {
    return 'Hochladen: $done von $total';
  }

  @override
  String get redesignFilesRename => 'Umbenennen';

  @override
  String get redesignFilesReplace => 'Ersetzen';

  @override
  String get redesignFilesRestored => 'Wiederhergestellt';

  @override
  String redesignFilesSaveFailed(Object error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get redesignFilesSelectAll => 'Alle auswählen';

  @override
  String redesignFilesSelected(Object count) {
    return '$count ausgewählt';
  }

  @override
  String get redesignFilesShortcuts => 'Tastenkürzel';

  @override
  String redesignFilesShortcutsHelp(Object mod) {
    return '↑ ↓ auswählen · Umschalt+↑↓ mehrere · Enter öffnen · Leertaste Vorschau/Abspielen · Entf löschen · $mod+U hochladen · $mod+A alle · $mod+D herunterladen · $mod+Z rückgängig · F2 umbenennen';
  }

  @override
  String get redesignFilesTitle => 'Dateien';

  @override
  String get redesignFilesUpload => 'Hochladen';

  @override
  String get redesignFilesUploading => 'Lädt hoch …';

  @override
  String get redesignFilesWaiting => 'Wartet';

  @override
  String get redesignFilesZipPreparing => 'ZIP wird erstellt …';

  @override
  String get redesignGroupsLoadFailed => 'Deine Gruppen konnten nicht geladen werden.';

  @override
  String get redesignGroupsManage => 'Gruppen verwalten';

  @override
  String get redesignGroupsSwitchFailed => 'Wechsel fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String redesignGroupsSwitchHint(Object name) {
    return 'Gruppe: $name. Tippen zum Wechseln';
  }

  @override
  String get redesignGroupsTitle => 'Gruppe wechseln';

  @override
  String get redesignManageAnnouncementsHint => 'Gesendete Mitteilungen ansehen';

  @override
  String get redesignManageAreaCommunication => 'Kommunikation';

  @override
  String get redesignManageAreaData => 'Auswertung & Daten';

  @override
  String get redesignManageAreaEvents => 'Termine & Planung';

  @override
  String get redesignManageAreaGroup => 'Gruppe';

  @override
  String get redesignManageAreaMembers => 'Mitglieder, Register & Rollen';

  @override
  String get redesignManageAreaWorks => 'Werke & Dateien';

  @override
  String get redesignManageClassic => 'Alle Einstellungen (bisherige Ansicht)';

  @override
  String get redesignManageExtraFieldsHint => 'Eigene Felder für Personen und Werke';

  @override
  String redesignManageFooter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count bisherigen Einträge stecken in diesen Bereichen und sind über die Suche direkt erreichbar.',
      one: 'Der bisherige Eintrag steckt in diesen Bereichen und ist über die Suche direkt erreichbar.',
    );
    return '$_temp0';
  }

  @override
  String get redesignManageGeneralHint => 'Name, Saison, Gründe, Anmeldung';

  @override
  String get redesignManageGeneralTitle => 'Allgemeine Einstellungen';

  @override
  String get redesignManageMissingHint => 'Mitglieder mit E-Mail, aber ohne Zugang';

  @override
  String get redesignManageNoMatch => 'Keine Einstellung passt zur Suche.';

  @override
  String redesignManagePending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen warten auf Freigabe',
      one: '1 Person wartet auf Freigabe',
    );
    return '$_temp0';
  }

  @override
  String get redesignManagePendingTitle => 'Freigaben';

  @override
  String get redesignManageRecent => 'Zuletzt geöffnet';

  @override
  String get redesignManageSearch => 'Einstellung suchen';

  @override
  String get redesignManageSearchLabel => 'Verwaltung durchsuchen';

  @override
  String get redesignMeAbsence => 'Abwesenheit eintragen';

  @override
  String get redesignMeAccount => 'Konto';

  @override
  String get redesignMeAdmin => 'Verwaltung';

  @override
  String get redesignMeAdminHint => 'Mitglieder, Termintypen, Rechte und mehr';

  @override
  String get redesignMeAllSettings => 'Alle Einstellungen';

  @override
  String get redesignMeApp => 'App';

  @override
  String get redesignMeBeta => 'Neues Design (Beta)';

  @override
  String get redesignMeBetaHint => 'Nur auf diesem Gerät. Jederzeit wieder ausschaltbar.';

  @override
  String get redesignMeCalendar => 'Kalender abonnieren';

  @override
  String get redesignMeFeedback => 'Feedback geben';

  @override
  String get redesignMeForMe => 'Für mich';

  @override
  String get redesignMeGroups => 'Meine Gruppen';

  @override
  String redesignMeGroupsCount(Object count) {
    return '$count Gruppen';
  }

  @override
  String get redesignMeHelp => 'Hilfe';

  @override
  String get redesignMeLogout => 'Abmelden';

  @override
  String get redesignMeNotifications => 'Benachrichtigungen';

  @override
  String get redesignMeWhatsNew => 'Neu in dieser Version';

  @override
  String redesignMembersAbsentFrom(Object date) {
    return 'abwesend ab $date';
  }

  @override
  String redesignMembersAbsentUntil(Object date) {
    return 'abwesend bis $date';
  }

  @override
  String redesignMembersActive(Object count) {
    return 'Aktiv · $count';
  }

  @override
  String get redesignMembersAdd => 'Person hinzufügen';

  @override
  String redesignMembersAverage(Object percent) {
    return 'Ø $percent %';
  }

  @override
  String redesignMembersBirthdayIn(Object count) {
    return 'Geburtstag in $count Tagen';
  }

  @override
  String get redesignMembersBirthdayToday => 'Geburtstag heute';

  @override
  String get redesignMembersBirthdayTomorrow => 'Geburtstag morgen';

  @override
  String get redesignMembersEmpty => 'Noch keine Mitglieder.';

  @override
  String get redesignMembersEmptyPaused => 'Niemand ist pausiert.';

  @override
  String get redesignMembersEmptyPending => 'Niemand wartet auf Freigabe.';

  @override
  String get redesignMembersLeader => 'Stimmführung';

  @override
  String get redesignMembersLow => 'unter 50 %';

  @override
  String get redesignMembersNoMatch => 'Niemand passt zur Suche.';

  @override
  String redesignMembersPaused(Object count) {
    return 'Pausiert · $count';
  }

  @override
  String redesignMembersPausedUntil(Object date) {
    return 'pausiert bis $date';
  }

  @override
  String redesignMembersPending(Object count) {
    return 'Wartet · $count';
  }

  @override
  String get redesignMembersPendingHint => 'Tippe auf eine Person, um sie zu prüfen und freizugeben.';

  @override
  String redesignMembersPercent(Object percent) {
    return '$percent %';
  }

  @override
  String get redesignMembersSearch => 'Name, Instrument, Register';

  @override
  String get redesignMembersSearchLabel => 'Mitglieder suchen';

  @override
  String redesignMembersSection(Object title, Object count) {
    return '$title · $count';
  }

  @override
  String get redesignMembersStats => 'Auswertung';

  @override
  String get redesignNotifForMe => 'Für mich';

  @override
  String get redesignNotifGroups => 'Gruppen';

  @override
  String get redesignNotifGroupsHint => 'Jede Gruppe lässt sich einzeln stummschalten.';

  @override
  String get redesignNotifHow => 'Wie';

  @override
  String get redesignNotifLead => 'Als Leitung';

  @override
  String get redesignNotifTelegram => 'Telegram';

  @override
  String get redesignNotifTelegramConnect => 'Verbinden';

  @override
  String get redesignNotifTelegramConnected => 'Verbunden';

  @override
  String get redesignNotifTelegramDisconnect => 'Trennen';

  @override
  String get redesignOwnInfos => 'Infos zum Termin';

  @override
  String get redesignOwnMore => 'Mehr';

  @override
  String get redesignOwnNotFound => 'Dieser Termin ist nicht mehr in deiner Liste.';

  @override
  String get redesignOwnRoute => 'Route';

  @override
  String get redesignPersonAbsence => 'Abwesend';

  @override
  String redesignPersonAbsenceRange(Object from, Object until) {
    return '$from bis $until';
  }

  @override
  String get redesignPersonAllTermine => 'Alle Termine ansehen';

  @override
  String get redesignPersonArchive => 'Archivieren';

  @override
  String get redesignPersonAttendance => 'Anwesenheit';

  @override
  String get redesignPersonBirthday => 'Geburtstag';

  @override
  String get redesignPersonEdit => 'Bearbeiten';

  @override
  String get redesignPersonHistory => 'Verlauf';

  @override
  String redesignPersonInDays(Object count) {
    return 'in $count Tagen';
  }

  @override
  String get redesignPersonJoined => 'Dabei seit';

  @override
  String redesignPersonLastTermine(Object count) {
    return 'Letzte $count Termine, neuester rechts';
  }

  @override
  String get redesignPersonNoTermine => 'Noch keine vergangenen Termine.';

  @override
  String get redesignPersonNotFound => 'Diese Person gibt es hier nicht mehr.';

  @override
  String get redesignPersonNotes => 'Notiz';

  @override
  String redesignPersonOfTermine(Object attended, Object total) {
    return '$attended von $total Terminen';
  }

  @override
  String get redesignPersonOverall => 'Gesamt';

  @override
  String get redesignPersonPause => 'Pausieren';

  @override
  String get redesignPersonPaused => 'Pausiert';

  @override
  String get redesignPersonPausedOpen => 'ohne Enddatum';

  @override
  String get redesignPersonPending => 'Wartet auf Freigabe.';

  @override
  String redesignPersonPercent(Object percent) {
    return '$percent %';
  }

  @override
  String get redesignPersonResume => 'Wieder aktiv';

  @override
  String get redesignPersonReview => 'Prüfen und freigeben';

  @override
  String redesignPersonSince(Object year) {
    return 'seit $year';
  }

  @override
  String redesignPersonSinceDate(Object date) {
    return 'seit $date';
  }

  @override
  String get redesignPersonToday => 'heute';

  @override
  String get redesignPersonTomorrow => 'morgen';

  @override
  String get redesignPultAllOpen => 'Alle Offenen da';

  @override
  String get redesignPultBack => 'Termin';

  @override
  String get redesignPultDone => 'Fertig';

  @override
  String redesignPultGroupCount(Object present, Object total) {
    return '$present / $total da';
  }

  @override
  String get redesignPultHint => 'Antippen = da · nochmal antippen = zurück · gedrückt halten = weitere Status';

  @override
  String get redesignPultOpen => 'Pultmodus';

  @override
  String get redesignPultOpenHint => 'Große Kacheln zum Antippen, gut für das Tablet am Pult';

  @override
  String get redesignPultStatusOpen => 'offen';

  @override
  String redesignPultTitle(Object title) {
    return '$title · Pultmodus';
  }

  @override
  String get redesignSignoutCannot => 'Ich kann nicht';

  @override
  String get redesignSignoutLater => 'Ich komme später';

  @override
  String get redesignSignoutOther => 'Anderer Grund';

  @override
  String get redesignSignoutOtherHint => 'Kurz beschreiben (mindestens 5 Zeichen)';

  @override
  String get redesignSignoutPrivacy => 'Deinen Grund sieht nur die Leitung.';

  @override
  String get redesignSignoutReason => 'Grund';

  @override
  String get redesignSignoutSubmit => 'Abmelden';

  @override
  String get redesignSignoutSubmitLate => 'Verspätung melden';

  @override
  String get redesignSplitEventsEmpty => 'Wähle links einen Termin aus.';

  @override
  String get redesignSplitMembersEmpty => 'Wähle links eine Person aus.';

  @override
  String get redesignSplitWorksEmpty => 'Wähle links ein Werk aus.';

  @override
  String get redesignStatsAvg => 'Ø Anwesenheit';

  @override
  String redesignStatsBar(Object date, Object percent) {
    return '$date: $percent %';
  }

  @override
  String get redesignStatsEmpty => 'Im Zeitraum gibt es keine Termine.';

  @override
  String get redesignStatsEvents => 'Termine';

  @override
  String get redesignStatsLoadFailed => 'Auswertung konnte nicht geladen werden.';

  @override
  String redesignStatsLow(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen unter 50 %',
      one: '1 Person unter 50 %',
    );
    return '$_temp0';
  }

  @override
  String get redesignStatsMembers => 'Aktive';

  @override
  String get redesignStatsPerEvent => 'Anwesenheit je Termin';

  @override
  String redesignStatsPerEventHint(Object count) {
    return 'Die letzten $count Termine';
  }

  @override
  String get redesignStatsPerGroup => 'Je Register';

  @override
  String get redesignStatsRange12m => '12 Monate';

  @override
  String get redesignStatsRange3m => '3 Monate';

  @override
  String get redesignStatsRangeSeason => 'Saison';

  @override
  String get redesignStatsTitle => 'Auswertung';

  @override
  String get redesignStatusAbsent => 'Abwesend';

  @override
  String get redesignStatusExcused => 'Entschuldigt';

  @override
  String get redesignStatusLate => 'Verspätet';

  @override
  String get redesignStatusLater => 'Kommt später';

  @override
  String get redesignStatusOpen => 'Offen';

  @override
  String get redesignStatusYes => 'Zugesagt';

  @override
  String get redesignTabEvents => 'Termine';

  @override
  String get redesignTabMe => 'Ich';

  @override
  String get redesignTabMembers => 'Mitglieder';

  @override
  String get redesignTabToday => 'Heute';

  @override
  String get redesignTabWorks => 'Werke';

  @override
  String get redesignTodayAllEvents => 'Alle Termine';

  @override
  String get redesignTodayAnswerChildren => 'Zu- und absagen';

  @override
  String get redesignTodayAnswered => 'Alle geantwortet';

  @override
  String get redesignTodayAnsweredLater => 'Du hast gemeldet, dass du später kommst.';

  @override
  String get redesignTodayAnsweredNo => 'Du bist abgemeldet.';

  @override
  String get redesignTodayAnsweredYes => 'Schön, du bist dabei.';

  @override
  String get redesignTodayAttention => 'Braucht deine Aufmerksamkeit';

  @override
  String redesignTodayBirthday(Object name, Object day) {
    return 'Geburtstag: $name ($day)';
  }

  @override
  String redesignTodayBirthdayMore(Object name, Object day, Object count) {
    return 'Geburtstag: $name ($day) +$count';
  }

  @override
  String redesignTodayCountAbsent(Object count) {
    return '$count abwesend';
  }

  @override
  String redesignTodayCountExcused(Object count) {
    return '$count entschuldigt';
  }

  @override
  String redesignTodayCountLater(Object count) {
    return '$count später';
  }

  @override
  String redesignTodayCountOpen(Object count) {
    return '$count offen';
  }

  @override
  String redesignTodayCountYes(Object count) {
    return '$count zugesagt';
  }

  @override
  String redesignTodayCritical(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder fehlen oft',
      one: '$count Mitglied fehlt oft',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodayCriticalHint => 'Unter der Anwesenheitsgrenze';

  @override
  String get redesignTodayDayToday => 'Heute';

  @override
  String get redesignTodayDayTomorrow => 'Morgen';

  @override
  String get redesignTodayDutyQuestion => 'Du bist eingeteilt. Bestätigst du?';

  @override
  String redesignTodayGreeting(Object name) {
    return 'Hallo $name';
  }

  @override
  String redesignTodayInHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Std.',
      one: 'in $count Std.',
    );
    return '$_temp0';
  }

  @override
  String redesignTodayInMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Min.',
      one: 'in $count Min.',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodayLater => 'Ich komme später …';

  @override
  String get redesignTodayLoadFailed => 'Das konnte nicht geladen werden.';

  @override
  String get redesignTodayLoading => 'Wird geladen …';

  @override
  String get redesignTodayMore => 'Mehr zum Termin';

  @override
  String get redesignTodayMySection => 'Meine Stimme';

  @override
  String get redesignTodayMySectionHint => 'Anwesenheit deiner Stimmgruppe';

  @override
  String get redesignTodayNextEvent => 'Nächster Termin';

  @override
  String get redesignTodayNo => 'Kann nicht';

  @override
  String get redesignTodayNoAfterAll => 'Doch absagen';

  @override
  String get redesignTodayNoChildren => 'Es sind noch keine Kinder mit deinem Konto verknüpft.';

  @override
  String get redesignTodayNoDone => 'Abgemeldet';

  @override
  String get redesignTodayNoMember => 'Du bist in dieser Gruppe nicht als Mitglied eingetragen.';

  @override
  String get redesignTodayNoUpcoming => 'Gerade stehen keine Termine an.';

  @override
  String get redesignTodayNotPart => 'Du bist für diesen Termin nicht eingeteilt.';

  @override
  String get redesignTodayNothingElse => 'Danach ist noch nichts geplant.';

  @override
  String get redesignTodayNotifications => 'Benachrichtigungen';

  @override
  String redesignTodayNotificationsUnread(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Benachrichtigungen, $count ungelesen',
      one: 'Benachrichtigungen, $count ungelesen',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodayOtherReason => 'Anderer Grund …';

  @override
  String redesignTodayPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Anmeldungen',
      one: '$count neue Anmeldung',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodayPendingHint => 'Prüfen und freischalten';

  @override
  String get redesignTodayQuestion => 'Bist du dabei?';

  @override
  String get redesignTodayRecord => 'Anwesenheit erfassen';

  @override
  String get redesignTodayRunning => 'läuft';

  @override
  String redesignTodaySignouts(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Abmeldungen für den nächsten Termin',
      one: '$count Abmeldung für den nächsten Termin',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodaySignoutsHint => 'Gründe ansehen';

  @override
  String get redesignTodayThisWeek => 'Diese Woche';

  @override
  String get redesignTodayUpNext => 'Als Nächstes';

  @override
  String get redesignTodayWeekEmpty => 'Diese Woche kommt sonst nichts.';

  @override
  String get redesignTodayWhyNot => 'Warum kannst du nicht?';

  @override
  String get redesignTodayYes => 'Bin dabei';

  @override
  String get redesignTodayYesAfterAll => 'Doch dabei';

  @override
  String get redesignTodayYesDone => 'Zugesagt';

  @override
  String get redesignTodayYourAnswer => 'Deine Zusage';

  @override
  String get redesignWorkAllFiles => 'Alle Dateien';

  @override
  String get redesignWorkAllParts => 'Alle Stimmen';

  @override
  String get redesignWorkEdit => 'Bearbeiten';

  @override
  String redesignWorkFileCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return '$_temp0';
  }

  @override
  String get redesignWorkLastPlayed => 'Zuletzt gespielt';

  @override
  String get redesignWorkLastSung => 'Zuletzt gesungen';

  @override
  String get redesignWorkLink => 'Link';

  @override
  String get redesignWorkLyrics => 'Liedtext';

  @override
  String get redesignWorkNever => 'Noch nie';

  @override
  String get redesignWorkNoFiles => 'Zu diesem Werk gibt es noch keine Dateien.';

  @override
  String get redesignWorkNoPart => 'Für deine Stimme gibt es noch keine Noten.';

  @override
  String get redesignWorkNormalSpeed => 'Normal abspielen';

  @override
  String get redesignWorkNotFound => 'Dieses Werk gibt es hier nicht mehr.';

  @override
  String redesignWorkNumber(Object number) {
    return 'Nr. $number';
  }

  @override
  String get redesignWorkOpen => 'Öffnen';

  @override
  String get redesignWorkPause => 'Anhalten';

  @override
  String get redesignWorkPlanned => 'Geplant';

  @override
  String get redesignWorkPlay => 'Abspielen';

  @override
  String get redesignWorkRecording => 'Aufnahme';

  @override
  String redesignWorkRecordingFrom(Object date) {
    return 'Aufnahme vom $date';
  }

  @override
  String get redesignWorkScore => 'Partitur';

  @override
  String get redesignWorkShare => 'Teilen';

  @override
  String redesignWorkShareFile(Object name) {
    return '$name teilen';
  }

  @override
  String get redesignWorkSlower => 'Langsamer abspielen';

  @override
  String get redesignWorkYourPart => 'Deine Stimme';

  @override
  String get redesignWorksAdd => 'Werk hinzufügen';

  @override
  String redesignWorksAll(Object count) {
    return 'Alle · $count';
  }

  @override
  String get redesignWorksAudio => 'Audio';

  @override
  String get redesignWorksCurrent => 'Gerade geprobt';

  @override
  String get redesignWorksEmpty => 'Noch keine Werke.';

  @override
  String get redesignWorksFiles => 'Dateien';

  @override
  String get redesignWorksFilesLabel => 'Dateien der Gruppe';

  @override
  String get redesignWorksFilter => 'Filter & Ansicht';

  @override
  String get redesignWorksFilterActive => 'Filter aktiv';

  @override
  String get redesignWorksMore => 'Mehr';

  @override
  String get redesignWorksNoMatch => 'Kein Werk passt zur Suche.';

  @override
  String get redesignWorksPdf => 'PDF';

  @override
  String get redesignWorksResetFilter => 'Filter zurücksetzen';

  @override
  String get redesignWorksSearch => 'Titel, Komponist, Nummer';

  @override
  String get redesignWorksSearchLabel => 'Werke suchen';

  @override
  String get registerCreate => 'Instanz jetzt erstellen';

  @override
  String registerCreateFailed(Object error) {
    return 'Fehler beim Erstellen der Instanz: $error';
  }

  @override
  String get registerCreating => 'Instanz wird erstellt...';

  @override
  String get registerDeleteAccount => 'Konto löschen';

  @override
  String get registerDeleteConfirm => 'Endgültig löschen';

  @override
  String get registerDeleteDone => 'Dein Konto wurde gelöscht.';

  @override
  String registerDeleteFailed(Object error) {
    return 'Fehler beim Löschen: $error';
  }

  @override
  String get registerDeleteHeader => 'Konto wirklich löschen?';

  @override
  String get registerDeleteMessage => 'Dein Konto wird unwiderruflich entfernt. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get registerDeleteRunning => 'Konto wird gelöscht...';

  @override
  String get registerFillAll => 'Bitte fülle alle Felder aus, um fortzufahren.';

  @override
  String get registerFillAllToast => 'Bitte füllen Sie alle Felder aus.';

  @override
  String get registerFlutterMainGroupInfo => 'Was ist die Hauptgruppe?';

  @override
  String get registerFullName => 'Vollständiger Name';

  @override
  String get registerFullNameHelper => 'Der Name wird in der App angezeigt';

  @override
  String get registerGroupType => 'Gruppentyp';

  @override
  String get registerGroupTypeQuestion => 'Was beschreibt deine Gruppe am besten?';

  @override
  String get registerHelpChoir => 'Optimiert für Chöre mit Stimmgruppen (Sopran, Alt, Tenor, Bass).';

  @override
  String get registerHelpGeneral => 'Ideal für Vereine, Teams oder sonstige Gruppen.';

  @override
  String get registerHelpOrchestra => 'Optimiert für Orchester/Musikgruppen mit Instrumentengruppen.';

  @override
  String get registerIntroHtml => 'Eine <strong>Instanz</strong> ist dein eigener Bereich für dein Orchester, deinen Chor oder deine Gruppe. Hier verwaltest du Mitglieder, Termine und Anwesenheiten.';

  @override
  String get registerJoinHeading => 'Du möchtest einer bestehenden Instanz beitreten?';

  @override
  String get registerJoinText => 'Bitte deinen Verantwortlichen, dich per E-Mail einzuladen. Eine neue Instanz ist nur nötig, wenn du selbst Administrator sein möchtest.';

  @override
  String get registerLogout => 'Abmelden';

  @override
  String get registerMainGroupHelper => 'z.B. Leitung, Dirigenten, Vorstand';

  @override
  String get registerMainGroupInfoHtml => '<h3>Was ist die Hauptgruppe?</h3><p>Die Hauptgruppe ist eine besondere Gruppe für Personen mit Leitungsfunktion (z.B. Dirigenten, Chorleiter, Vorstand).</p><p><strong>Besonderheiten:</strong></p><ul><li>Kann nicht gelöscht werden</li><li>Mitglieder erhalten automatisch erweiterte Rechte</li><li>Ideal für Personen, die die Instanz verwalten</li></ul><p><em>Du kannst später weitere Gruppen (z.B. Sopran, Geigen) hinzufügen.</em></p>';

  @override
  String get registerMainGroupName => 'Name der Hauptgruppe';

  @override
  String get registerMissingMainGroup => 'Name der Hauptgruppe fehlt';

  @override
  String get registerMissingName => 'Name der Instanz fehlt';

  @override
  String get registerMissingShortName => 'Instanz-Kürzel fehlt';

  @override
  String get registerModalAcceptPrivacy => 'Datenschutzerklärung akzeptieren';

  @override
  String get registerModalAcceptPrivacyToast => 'Bitte stimme der Datenschutzerklärung zu';

  @override
  String get registerModalConfirm => 'Bestätigen';

  @override
  String get registerModalConfirmPassword => 'Passwort bestätigen';

  @override
  String get registerModalConfirmPasswordPlaceholder => 'Passwort erneut eingeben';

  @override
  String get registerModalEmailPlaceholder => 'deine@email.de';

  @override
  String get registerModalFailed => 'Fehler beim Registrieren';

  @override
  String get registerModalHintOtp => 'Nach der Registrierung senden wir dir einen 6-stelligen Code per E-Mail. Gib ihn hier ein, um deinen Account zu aktivieren.';

  @override
  String get registerModalHintPassword => 'Nach der Registrierung senden wir dir eine Bestätigungs-E-Mail. Bitte klicke auf den Link darin, um deinen Account zu aktivieren.';

  @override
  String get registerModalIntro => 'Lege einen Account an, um deine Anwesenheit zu verwalten oder eine neue Instanz für deine Gruppe, deinen Chor oder dein Orchester zu erstellen.';

  @override
  String get registerModalInvalidEmail => 'Ungültige E-Mail-Adresse';

  @override
  String get registerModalPasswordMismatch => 'Passwörter stimmen nicht überein';

  @override
  String get registerModalPasswordPlaceholder => 'Mindestens 6 Zeichen';

  @override
  String get registerModalPasswordTooShort => 'Passwort muss mindestens 6 Zeichen lang sein';

  @override
  String get registerModalPrivacyAfter => ' gelesen.';

  @override
  String get registerModalPrivacyBefore => 'Ich akzeptiere die Nutzungsbedingungen und habe die';

  @override
  String get registerModalPrivacyLink => 'Datenschutzerklärung';

  @override
  String get registerModalRunning => 'Registrierung läuft...';

  @override
  String get registerModalSubmitting => 'Wird registriert...';

  @override
  String get registerModalTitle => 'Registrieren';

  @override
  String get registerModalWelcome => 'Willkommen bei Attendix!';

  @override
  String get registerPlaceholderChoirMain => 'z.B. Chorleitung';

  @override
  String get registerPlaceholderChoirName => 'z.B. Gospelchor Harmonie';

  @override
  String get registerPlaceholderChoirShort => 'z.B. GCH';

  @override
  String get registerPlaceholderGeneralMain => 'z.B. Vorstand';

  @override
  String get registerPlaceholderGeneralName => 'z.B. Sportverein Musterstadt';

  @override
  String get registerPlaceholderGeneralShort => 'z.B. SVM';

  @override
  String get registerPlaceholderOrchestraMain => 'z.B. Dirigenten';

  @override
  String get registerPlaceholderOrchestraName => 'z.B. Stadtorchester Musterstadt';

  @override
  String get registerPlaceholderOrchestraShort => 'z.B. SOM';

  @override
  String get registerShortName => 'Instanz-Kürzel';

  @override
  String get registerShortNameHelper => 'Wird für kompakte Darstellungen verwendet';

  @override
  String get registerStep1 => 'Art der Gruppe wählen';

  @override
  String get registerStep2 => 'Name deiner Instanz';

  @override
  String get registerStep3 => 'Hauptgruppe festlegen';

  @override
  String get registerSummary => 'Zusammenfassung';

  @override
  String registerSummaryMainGroup(Object name) {
    return 'Hauptgruppe: $name';
  }

  @override
  String registerSummaryType(Object type) {
    return 'Typ: $type';
  }

  @override
  String get registerTitle => 'Neue Instanz anlegen';

  @override
  String get registerTypeChoir => 'Chor';

  @override
  String get registerTypeChoirOption => 'Chor / Gesangsgruppe';

  @override
  String get registerTypeGeneral => 'Allgemeine Gruppe';

  @override
  String get registerTypeOrchestra => 'Orchester';

  @override
  String get registerTypeOrchestraOption => 'Orchester / Musikgruppe';

  @override
  String get registerWelcome => 'Willkommen!';

  @override
  String get rolePermAbsencesHelper => 'Wenn aktiviert, können Personen mit dieser Rolle geplante Abwesenheiten für sich selbst eintragen.';

  @override
  String get rolePermAllGroups => 'Alle Gruppen pflegen';

  @override
  String get rolePermAllGroupsHelper => 'Wenn deaktiviert, können Personen mit dieser Rolle nur Anwesenheiten der ihnen zugeordneten Gruppe pflegen.';

  @override
  String get rolePermAllowPause => 'Eigene Pausierung erlauben';

  @override
  String get rolePermChecklistHelper => 'Wenn aktiviert, können Personen mit dieser Rolle die Checkliste in der Anwesenheitsansicht sehen.';

  @override
  String get rolePermCreateAttendance => 'Anwesenheiten erstellen';

  @override
  String get rolePermCreateHelper => 'Wenn deaktiviert, können Personen mit dieser Rolle keine neuen Anwesenheiten anlegen.';

  @override
  String get rolePermDiscard => 'Verwerfen';

  @override
  String get rolePermEnterAbsences => 'Geplante Abwesenheiten eintragen';

  @override
  String get rolePermFiles => 'Dateiablage';

  @override
  String get rolePermFilesForAll => 'Dateiablage für alle Mitglieder';

  @override
  String get rolePermFilesHelper => 'Admins, Verantwortliche und Helfer sehen die Dateiablage immer. Wenn aktiviert, können auch alle anderen Mitglieder außer Bewerber sie lesen. Hochladen bleibt Admins und Verantwortlichen vorbehalten.';

  @override
  String rolePermFlutterLoadFailed(Object error) {
    return 'Fehler beim Laden der Rollenberechtigungen\n$error';
  }

  @override
  String get rolePermNotesHelper => 'Wenn aktiviert, können Personen mit dieser Rolle die Notizen der Mitglieder in der Anwesenheitsansicht sehen.';

  @override
  String get rolePermPauseHelper => 'Wenn aktiviert, können Spieler sich selbst pausieren und reaktivieren.';

  @override
  String get rolePermSaveFailed => 'Fehler beim Speichern der Rollenberechtigungen';

  @override
  String get rolePermSaved => 'Rollenberechtigungen gespeichert';

  @override
  String get rolePermSeeChecklist => 'Checkliste sehen';

  @override
  String get rolePermSeeNotes => 'Spielernotizen sehen';

  @override
  String get rolePermTitle => 'Rollen & Berechtigungen';

  @override
  String get rolePermUnsaved => 'Ungespeicherte Änderungen';

  @override
  String get rolePermUnsavedMessage => 'Du hast ungespeicherte Änderungen. Möchtest du sie speichern bevor du die Seite verlässt?';

  @override
  String get rolesAdministrator => 'Administrator';

  @override
  String get rolesApplicant => 'Bewerber';

  @override
  String get rolesHelper => 'Helfer';

  @override
  String get rolesMember => 'Mitglied';

  @override
  String get rolesParent => 'Elternteil';

  @override
  String get rolesParents => 'Eltern';

  @override
  String get rolesResponsible => 'Verantwortlicher';

  @override
  String get rolesViewer => 'Beobachter';

  @override
  String get rolesVoiceLeader => 'Stimmführer';

  @override
  String get rolesVoiceLeaderHelper => 'Stimmführer-Helfer';

  @override
  String get selfServiceAllEvents => 'Alle Termine';

  @override
  String get selfServiceAllKidsSignInOut => 'Alle Kinder an- bzw. abmelden';

  @override
  String get selfServiceAttachment => 'Anhang';

  @override
  String get selfServiceByInstance => 'Nach Instanz';

  @override
  String get selfServiceChronological => 'Chronologisch';

  @override
  String selfServiceDeadline(Object date) {
    return 'Anmeldefrist: $date';
  }

  @override
  String get selfServiceFlutterChild => 'Kind';

  @override
  String get selfServiceFlutterNoKids => 'Keine Kinder gefunden';

  @override
  String get selfServiceFlutterNoKidsHint => 'Es wurden keine Kinder mit Ihrem\nEltern-Account verknüpft.';

  @override
  String get selfServiceFlutterNoValidEntries => 'Keine gültigen Einträge gefunden';

  @override
  String selfServiceFlutterSignInUntil(Object date) {
    return 'Anmelden bis $date Uhr';
  }

  @override
  String selfServiceFlutterSwitchFailed(Object error) {
    return 'Fehler beim Wechseln: $error';
  }

  @override
  String get selfServiceLoadingEvents => 'Termine werden geladen...';

  @override
  String get selfServiceNoEvents => 'Keine Termine gefunden';

  @override
  String get selfServiceNoUpcoming => 'Keine anstehenden Termine';

  @override
  String get selfServiceParentsThanksLate => 'Vielen Dank für die Info und Gottes Segen!';

  @override
  String get selfServiceParentsThanksSignout => 'Vielen Dank für die rechtzeitige Abmeldung und Gottes Segen!';

  @override
  String get selfServiceShalom => 'Shalom!';

  @override
  String get selfServiceShowCurrentSongs => 'Aktuelle Werke anzeigen';

  @override
  String get selfServiceThanksForSignIn => 'Danke für die Anmeldung 🙂';

  @override
  String selfServiceYouManageKids(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kinder',
      one: '$count Kind',
    );
    return 'Du verwaltest $_temp0:';
  }

  @override
  String get settingsAccountsCreated => 'Die Accounts wurden erfolgreich angelegt';

  @override
  String get settingsAdHocPlanning => 'Ad-Hoc Ablaufplanung';

  @override
  String get settingsAddAdmin => 'Admin hinzufügen';

  @override
  String get settingsAddParent => 'Elternteil hinzufügen';

  @override
  String get settingsAddViewer => 'Beobachter hinzufügen';

  @override
  String get settingsAdminAdded => 'Der Admin wurde erfolgreich hinzugefügt.';

  @override
  String get settingsAdminRemoved => 'Der Admin wurde erfolgreich entfernt.';

  @override
  String get settingsAdmins => 'Administratoren';

  @override
  String get settingsAdminsHint => 'Administratoren haben alle Rechte in der Instanz und können auch die Instanz löschen.';

  @override
  String get settingsAnalyticsData => 'Auswertung & Daten';

  @override
  String get settingsAnnouncements => 'Mitteilungen';

  @override
  String get settingsAnonymous => 'Anonym';

  @override
  String get settingsAppStore => 'Im App Store laden';

  @override
  String get settingsArchive => 'Archiv';

  @override
  String get settingsAsApp => '📱 Attendix als App';

  @override
  String get settingsAsAppText => 'Attendix gibt es jetzt als native App mit Push-Benachrichtigungen und schnellerem Zugriff.';

  @override
  String settingsCalendarMessage(Object link) {
    return 'Kopiere den folgenden Link in deine Kalender-App, um die Termine zu abonnieren:\n\n$link';
  }

  @override
  String get settingsCannotDeleteTenant => 'Du kannst diese Instanz nicht löschen.';

  @override
  String get settingsCannotRemoveSelf => 'Du kannst dich nicht selbst entfernen.';

  @override
  String get settingsCertificates => 'Urkunden generieren';

  @override
  String get settingsCertificatesFailed => 'Fehler beim Erstellen der Urkunden.';

  @override
  String get settingsCertificatesFor => 'Für welche Gruppen sollen Urkunden erstellt werden?';

  @override
  String get settingsChange => 'Ändern';

  @override
  String get settingsChangePassword => 'Passwort ändern';

  @override
  String get settingsCommunication => 'Kommunikation';

  @override
  String get settingsConfigureDashboard => 'Dashboard konfigurieren';

  @override
  String get settingsContactOnly => 'Dient nur zur Kontaktaufnahme bei Rückfragen';

  @override
  String get settingsContactTelegram => 'Per Telegram kontaktieren';

  @override
  String get settingsContinue => 'Fortfahren';

  @override
  String get settingsCopyLink => 'Link kopieren';

  @override
  String get settingsCreateAccounts => 'Accounts anlegen';

  @override
  String settingsCreateAccountsFailed(Object error) {
    return 'Fehler beim Erstellen der Accounts: $error';
  }

  @override
  String settingsCreateAccountsMessage(Object names) {
    return 'Folgende Accounts werden angelegt: $names';
  }

  @override
  String get settingsCreateMissing => 'Fehlende Accounts anlegen';

  @override
  String get settingsCreatingCertificates => 'Urkunden werden erstellt...';

  @override
  String get settingsCurrent => 'Aktuell';

  @override
  String get settingsDeleteAccount => 'Konto löschen';

  @override
  String get settingsDeleteTenant => 'Instanz löschen?';

  @override
  String settingsDeleteTenantMessage(Object name) {
    return 'Möchtest du die Instanz „$name“ wirklich löschen? Dies kann nicht rückgängig gemacht werden! Wenn du die Instanz wirklich löschen willst, dann gebe den Namen der Instanz ein:';
  }

  @override
  String get settingsEmailAddress => 'E-Mail-Adresse';

  @override
  String get settingsEnableTenantSelect => 'Instanzauswahl aktivieren';

  @override
  String get settingsExport => 'Export';

  @override
  String get settingsExtraFields => 'Zusatzfelder';

  @override
  String settingsFavoriteRemoved(Object name) {
    return 'Die Instanz „$name“ wurde als Favorit entfernt.';
  }

  @override
  String settingsFavoriteSet(Object name) {
    return 'Die Instanz „$name“ wurde als Favorit gesetzt.';
  }

  @override
  String get settingsFeedback => 'Feedback';

  @override
  String settingsFeedbackFailed(Object error) {
    return 'Fehler beim Senden des Feedbacks: $error';
  }

  @override
  String get settingsFeedbackPh => 'Dein Feedback eingeben...';

  @override
  String get settingsFeedbackSent => 'Dein Feedback wurde erfolgreich gesendet. Vielen Dank!';

  @override
  String get settingsFileStorage => 'Dateiablage';

  @override
  String get settingsFiles => 'Dateien';

  @override
  String get settingsFlutterAddFailed => 'Fehler beim Hinzufügen';

  @override
  String get settingsFlutterAdminAddedNotNotified => 'Der Admin wurde hinzugefügt, konnte aber nicht benachrichtigt werden.';

  @override
  String get settingsFlutterApplicantText => 'Ein Administrator wird deine Registrierung prüfen.';

  @override
  String get settingsFlutterApplicantTitle => 'Mitgliedschaft wird geprüft';

  @override
  String get settingsFlutterArchiveHint => 'Hier erscheinen archivierte Mitglieder';

  @override
  String get settingsFlutterBatchAllHaveAccount => 'Alle Spieler mit E-Mail haben bereits einen Account.';

  @override
  String settingsFlutterBatchCreateButton(Object count) {
    return 'Accounts für $count Spieler erstellen';
  }

  @override
  String get settingsFlutterBatchEligible => 'Account erstellbar (mit E-Mail)';

  @override
  String settingsFlutterBatchEligibleList(Object count) {
    return 'Spieler ohne Account ($count)';
  }

  @override
  String settingsFlutterBatchFailed(Object count) {
    return '$count fehlgeschlagen';
  }

  @override
  String get settingsFlutterBatchNoEmail => 'Ohne E-Mail (manuell nötig)';

  @override
  String settingsFlutterBatchProcessed(Object processed, Object total) {
    return '$processed / $total verarbeitet';
  }

  @override
  String settingsFlutterBatchSucceeded(Object count) {
    return '$count erfolgreich';
  }

  @override
  String get settingsFlutterBatchTitle => 'Accounts erstellen';

  @override
  String get settingsFlutterBatchWithAccount => 'Mit Account';

  @override
  String get settingsFlutterCalendarIntro => 'Kopiere den folgenden Link in deine Kalender-App, um die Termine zu abonnieren:';

  @override
  String get settingsFlutterChangeEmail => 'E-Mail ändern';

  @override
  String settingsFlutterChangeEmailFailed(Object error) {
    return 'Fehler beim Ändern der E-Mail-Adresse: $error';
  }

  @override
  String get settingsFlutterConfirmEmailChange => 'Bitte bestätige die Änderung über den Link in der E-Mail an deine neue Adresse.';

  @override
  String get settingsFlutterCopyLinkFailed => 'Link konnte nicht kopiert werden';

  @override
  String settingsFlutterCreateFailed(Object error) {
    return 'Fehler beim Erstellen: $error';
  }

  @override
  String settingsFlutterCurrentEmail(Object email) {
    return 'Aktuell: $email';
  }

  @override
  String get settingsFlutterEmailRequired => 'E-Mail ist erforderlich';

  @override
  String settingsFlutterErrorDetail(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get settingsFlutterFirstNameRequired => 'Vorname ist erforderlich';

  @override
  String get settingsFlutterInvalidEmail => 'Bitte gib eine gültige E-Mail-Adresse ein.';

  @override
  String get settingsFlutterLastNameRequired => 'Nachname ist erforderlich';

  @override
  String settingsFlutterLoadFailed(Object error) {
    return 'Fehler beim Laden: $error';
  }

  @override
  String get settingsFlutterNewEmailPh => 'Neue E-Mail-Adresse...';

  @override
  String get settingsFlutterNoProfile => 'Kein Profil gefunden';

  @override
  String get settingsFlutterParentRemoved => 'Elternteil entfernt';

  @override
  String get settingsFlutterPendingApprove => 'Genehmigen';

  @override
  String settingsFlutterPendingApproveMessage(Object name) {
    return 'Möchtest du $name als Mitglied freischalten?';
  }

  @override
  String get settingsFlutterPendingApproveTitle => 'Registrierung genehmigen?';

  @override
  String settingsFlutterPendingApproved(Object name) {
    return '$name wurde freigeschaltet';
  }

  @override
  String settingsFlutterPendingDeclineMessage(Object name) {
    return 'Möchtest du die Registrierung von $name ablehnen? Der Eintrag wird gelöscht.';
  }

  @override
  String get settingsFlutterPendingDeclineTitle => 'Registrierung ablehnen?';

  @override
  String get settingsFlutterPendingDeclined => 'Registrierung abgelehnt';

  @override
  String get settingsFlutterPendingEmpty => 'Keine ausstehenden Registrierungen';

  @override
  String get settingsFlutterPendingEmptyHint => 'Neue Registrierungen erscheinen hier automatisch';

  @override
  String get settingsFlutterPendingInvalidId => 'Ungültige Spieler-ID';

  @override
  String get settingsFlutterPwaAndroidStep1 => 'Tippe auf das Menü (⋮)';

  @override
  String get settingsFlutterPwaAndroidStep2 => '\"App installieren\" oder \"Zum Startbildschirm\"';

  @override
  String get settingsFlutterPwaIosStep1 => 'Tippe auf das Teilen-Symbol';

  @override
  String get settingsFlutterPwaIosStep2 => '\"Zum Home-Bildschirm\"';

  @override
  String get settingsFlutterPwaIosStep3 => '\"Hinzufügen\"';

  @override
  String get settingsFlutterPwaText => 'Für ein besseres Erlebnis kannst du diese App installieren:';

  @override
  String get settingsFlutterPwaTitle => 'App installieren';

  @override
  String settingsFlutterReactivateMessage(Object name) {
    return 'Möchtest du $name wieder aktivieren?';
  }

  @override
  String settingsFlutterReactivated(Object name) {
    return '$name wurde reaktiviert';
  }

  @override
  String get settingsFlutterSameEmail => 'Das ist bereits deine E-Mail-Adresse.';

  @override
  String get settingsFlutterUserMgmtAdd => 'Benutzer hinzufügen';

  @override
  String get settingsFlutterUserMgmtAddFailed => 'Fehler beim Hinzufügen des Benutzers';

  @override
  String get settingsFlutterUserMgmtAdded => 'Benutzer hinzugefügt';

  @override
  String get settingsFlutterUserMgmtEmailPh => 'email@beispiel.de';

  @override
  String get settingsFlutterUserMgmtLastAdmin => 'Der letzte Administrator kann nicht herabgestuft werden. Bitte füge zuerst einen weiteren Admin hinzu.';

  @override
  String get settingsFlutterUserMgmtNoAdmins => 'Keine Administratoren';

  @override
  String get settingsFlutterUserMgmtNoAdminsHint => 'Füge Admins über den + Button hinzu';

  @override
  String get settingsFlutterUserMgmtNoParents => 'Keine Eltern';

  @override
  String get settingsFlutterUserMgmtNoParentsHint => 'Eltern können ihre Kinder an-/abmelden';

  @override
  String get settingsFlutterUserMgmtNoRole => 'Keine Rolle';

  @override
  String get settingsFlutterUserMgmtNoUsers => 'Keine Benutzer vorhanden';

  @override
  String get settingsFlutterUserMgmtNoViewers => 'Keine Betrachter';

  @override
  String get settingsFlutterUserMgmtNoViewersHint => 'Betrachter können Anwesenheit sehen, aber nicht bearbeiten';

  @override
  String get settingsFlutterUserMgmtPlayers => 'Spieler';

  @override
  String get settingsFlutterUserMgmtResponsibles => 'Verantwortliche';

  @override
  String get settingsFlutterUserMgmtRoleChangeFailed => 'Fehler beim Ändern der Rolle';

  @override
  String settingsFlutterUserMgmtRoleChanged(Object role) {
    return 'Rolle geändert zu $role';
  }

  @override
  String get settingsFlutterUserMgmtSelfDemoteConfirm => 'Ja, Rolle ändern';

  @override
  String get settingsFlutterUserMgmtSelfDemoteMessage => 'Du bist dabei, deine eigene Admin-Rolle zu entfernen. Du verlierst dadurch den Zugang zur Benutzerverwaltung. Möchtest du fortfahren?';

  @override
  String get settingsFlutterUserMgmtSelfDemoteTitle => 'Eigene Rolle ändern?';

  @override
  String get settingsFlutterUserMgmtTabAdmins => 'Admins';

  @override
  String get settingsFlutterUserMgmtTabAll => 'Alle Benutzer';

  @override
  String get settingsFlutterUserMgmtTitle => 'Benutzerverwaltung';

  @override
  String get settingsFlutterUsers => 'Benutzer';

  @override
  String get settingsFlutterViewerRemoved => 'Beobachter entfernt';

  @override
  String get settingsGenerate => 'Generieren';

  @override
  String get settingsGiveFeedback => 'Feedback geben';

  @override
  String get settingsGooglePlay => 'Bei Google Play laden';

  @override
  String get settingsGroups => 'Gruppen';

  @override
  String get settingsHelp => 'Hilfe';

  @override
  String get settingsHelpFeedback => 'Hilfe & Feedback';

  @override
  String get settingsHelpQuestion => 'Hilfe/Frage';

  @override
  String get settingsHideCancelled => 'Abgesagte Termine ausblenden';

  @override
  String get settingsImageTooBig => 'Das Bild darf maximal 2MB groß sein.';

  @override
  String get settingsInstallUpdate => 'Update installieren';

  @override
  String get settingsInvite => 'Einladen';

  @override
  String get settingsLanguageHint => 'Gilt für die App sowie für Push-Nachrichten, Telegram und E-Mails an dich.';

  @override
  String get settingsLanguageTitle => 'Sprache';

  @override
  String settingsLeftOn(Object date) {
    return 'Ausgetreten: $date';
  }

  @override
  String get settingsLinkCopied => 'Der Link wurde in die Zwischenablage kopiert';

  @override
  String get settingsLogout => 'Ausloggen';

  @override
  String get settingsMessageAll => 'Nachricht an alle senden';

  @override
  String get settingsMobile => 'Handynummer';

  @override
  String get settingsMyData => 'Meine Stammdaten';

  @override
  String get settingsMyVoice => 'Meine Stimme';

  @override
  String get settingsNew => 'NEU';

  @override
  String get settingsNewPasswordPh => 'Neues Passwort eingeben...';

  @override
  String get settingsNoArchived => 'Keine archivierten Personen';

  @override
  String get settingsNoChurch => 'Keine Gemeinde gefunden.';

  @override
  String get settingsNoPersonsInGroups => 'Keine Personen in den gewählten Gruppen gefunden.';

  @override
  String get settingsNotLinked => 'Nicht verknüpft';

  @override
  String get settingsNotListed => 'Nicht gelistet';

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsOpenGuide => 'Anleitung öffnen';

  @override
  String get settingsOr => 'oder';

  @override
  String get settingsOrganisation => 'Organisation';

  @override
  String get settingsParents => 'Eltern';

  @override
  String get settingsParentsHint => 'Eltern können die Anwesenheiten ihrer Kinder einsehen und Abwesenheiten pflegen.';

  @override
  String get settingsPassPhoto => 'Passbild';

  @override
  String get settingsPasswordChanged => 'Das Passwort wurde erfolgreich geändert';

  @override
  String get settingsPasswordFailed => 'Fehler beim Ändern deines Passworts. Bitte versuche es später erneut.';

  @override
  String get settingsPasswordTooShort => 'Das Passwort muss mindestens 6 Zeichen lang sein.';

  @override
  String get settingsPasswordsMismatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String settingsPendingCount(Object count) {
    return '$count ausstehende Registrierung(en)';
  }

  @override
  String get settingsPendingPersons => 'Ausstehende Personen';

  @override
  String get settingsPhonePh => 'Handynummer eingeben...';

  @override
  String get settingsPhotoChangeFailed => 'Fehler beim ändern des Passbildes, versuche es später erneut';

  @override
  String get settingsPhotoChanged => 'Das Passbild wurde erfolgreich geändert.';

  @override
  String get settingsPhotoRemoveFailed => 'Fehler beim Entfernen des Passbildes, versuche es später erneut';

  @override
  String get settingsPhotoRemoved => 'Das Passbild wurde erfolgreich entfernt';

  @override
  String get settingsPlanning => 'Planung';

  @override
  String get settingsPleaseSelect => 'Bitte auswählen';

  @override
  String get settingsProfilePicture => 'Profilbild';

  @override
  String get settingsProfileUpdated => 'Die Profildaten wurden erfolgreich aktualisiert.';

  @override
  String settingsQuestionFailed(Object error) {
    return 'Fehler beim Senden der Anfrage: $error';
  }

  @override
  String get settingsQuestionSent => 'Deine Anfrage wurde erfolgreich gesendet. Wir melden uns so schnell wie möglich bei dir.';

  @override
  String get settingsRatingRequired => 'Bitte gib eine Bewertung ab.';

  @override
  String get settingsRemoveAdmin => 'Admin entfernen?';

  @override
  String settingsRemoveMessage(Object name) {
    return 'Möchtest du $name wirklich entfernen?';
  }

  @override
  String get settingsRemoveParent => 'Elternteil entfernen?';

  @override
  String get settingsRemovePhoto => 'Passbild entfernen';

  @override
  String get settingsRemovePhotoConfirm => 'Möchtest du dein Passbild wirklich entfernen?';

  @override
  String get settingsRemoveViewer => 'Beobachter entfernen?';

  @override
  String get settingsRemovingTenant => 'Instanz wird entfernt...';

  @override
  String get settingsRepeatPasswordPh => 'Passwort wiederholen...';

  @override
  String get settingsReplacePhoto => 'Passbild ersetzen';

  @override
  String get settingsRolesPerms => 'Rollen & Berechtigungen';

  @override
  String get settingsRunSheets => 'Ablaufpläne';

  @override
  String get settingsSearchChurch => 'Gemeinde suchen';

  @override
  String get settingsSelectGroups => 'Gruppen auswählen';

  @override
  String get settingsSelectOneGroup => 'Bitte mindestens eine Gruppe auswählen.';

  @override
  String get settingsSettings => 'Einstellungen';

  @override
  String get settingsSongs => 'Werke';

  @override
  String get settingsSongsRehearsals => 'Werke & Proben';

  @override
  String get settingsSubmit => 'Absenden';

  @override
  String get settingsSubscribeCalendar => 'Kalender abonnieren';

  @override
  String get settingsSwitchTenant => 'Instanz wechseln';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsTeachers => 'Lehrer';

  @override
  String get settingsTemplatesFields => 'Planvorlagen & Felder';

  @override
  String get settingsTenantAdmin => 'Instanz-Verwaltung';

  @override
  String get settingsTenantNamePh => 'Name der Instanz eingeben...';

  @override
  String get settingsTenantSelectHelper => 'Wenn diese Option aktiv ist, wirst du vor dem Öffnen der App immer gefragt, welche Instanz du öffnen möchtest.';

  @override
  String settingsTenantsCount(Object count) {
    return 'Instanzen ($count)';
  }

  @override
  String get settingsUserCreated => 'Der Benutzer wurde erfolgreich angelegt.';

  @override
  String get settingsUsersRoles => 'Benutzer & Rollen';

  @override
  String get settingsViewPhoto => 'Passbild ansehen';

  @override
  String get settingsViewers => 'Beobachter';

  @override
  String get settingsViewersHint => 'Beobachter haben nur Leserechte auf Anwesenheitsübersicht und Personendaten.';

  @override
  String get settingsVoiceLeader => 'Stimmführer';

  @override
  String get settingsWaitingApproval => 'Personen warten auf Genehmigung';

  @override
  String get settingsWhatsNew => 'Was ist neu?';

  @override
  String get settingsWrongName => 'Der eingegebene Name ist nicht korrekt.';

  @override
  String get settingsYourFeedback => 'Dein Feedback';

  @override
  String get settingsYourMobileOptional => 'Deine Handynummer (optional)';

  @override
  String get settingsYourQuestion => 'Deine Frage';

  @override
  String get settingsYourQuestionPh => 'Deine Frage eingeben...';

  @override
  String get settingsYourRating => 'Deine Bewertung';

  @override
  String get shiftsChooseTarget => 'Wähle die Ziel-Instanz, in die der Schichtplan kopiert werden soll.';

  @override
  String get shiftsComputed => 'Berechnete Schichten';

  @override
  String shiftsComputedLine(Object start, Object end, Object hours) {
    return '$start - $end, $hours Stunden';
  }

  @override
  String shiftsCopied(Object tenant) {
    return 'Schichtplan nach „$tenant“ kopiert.';
  }

  @override
  String shiftsCopiedAssigned(Object tenant, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '$count Person',
    );
    return 'Schichtplan nach „$tenant“ kopiert und $_temp0 zugewiesen.';
  }

  @override
  String shiftsCopiedNoMatch(Object tenant) {
    return 'Schichtplan nach „$tenant“ kopiert. Keine passenden Personen in Ziel-Instanz gefunden.';
  }

  @override
  String get shiftsCopyAssignments => 'Zuweisungen kopieren?';

  @override
  String shiftsCopyAssignmentsMessage(num count, Object tenant) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '$count Person',
    );
    return 'Der Schichtplan ist $_temp0 zugewiesen. Sollen diese Zuweisungen auch in „$tenant“ übernommen werden?';
  }

  @override
  String get shiftsCopyFailed => 'Fehler beim Kopieren des Schichtplans.';

  @override
  String get shiftsCopyFromOther => 'Schichtplan aus anderer Instanz übernehmen';

  @override
  String get shiftsCopyToTenant => 'In Instanz kopieren';

  @override
  String get shiftsCopying => 'Schichtplan wird kopiert...';

  @override
  String get shiftsCreate => 'Schichtplan erstellen';

  @override
  String get shiftsDecimalHelper => 'Wenn die Schichtdauer keine ganze Zahl ist, bitte Dezimalstellen mit Punkt angeben. (z.B. 8.5 für 8 1/2 Stunden)';

  @override
  String get shiftsDefinition => 'Definition';

  @override
  String get shiftsDelete => 'Schichtplan löschen';

  @override
  String get shiftsDeleteFailed => 'Fehler beim Löschen des Schichtplans';

  @override
  String get shiftsDeleteMessage => 'Möchtest du den Schichtplan wirklich löschen? Alle zugehörigen Schichten werden ebenfalls gelöscht. Personen, die diesem Schichtplan zugewiesen sind, verlieren ihre Zuordnung. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get shiftsDeleted => 'Schichtplan gelöscht';

  @override
  String get shiftsDeleting => 'Schichtplan wird gelöscht...';

  @override
  String get shiftsDurationHours => 'Dauer (in Stunden)';

  @override
  String get shiftsEdit => 'Schichtplan anpassen';

  @override
  String get shiftsEditIntro => 'Füge hier die verschiedenen Schichten hinzu, aus denen sich der Schichtplan zusammensetzt. Jede Schicht entspricht einem Tag, an dem eine Person Schicht hat. Der Schichtplan beginnt wieder von vorne, wenn alle Schichten durchlaufen sind.';

  @override
  String get shiftsEnterName => 'Bitte gib einen Namen für den Schichtplan ein.';

  @override
  String get shiftsExample => 'Beispiel-Rechnung';

  @override
  String get shiftsFixedIntro => 'Lege feste Schichten fest, die regelmäßig wiederkehren. Falls keine Schichten festgelegt sind, kann mein Zuweisen der Schicht einer Person, das Anfangsdatum festgelegt werden.';

  @override
  String get shiftsFixedOptional => 'Feste Schichten (optional)';

  @override
  String get shiftsFlutterAddSegment => 'Segment hinzufügen';

  @override
  String get shiftsFlutterAddSegmentsHint => 'Füge Segmente hinzu, um die Vorschau zu sehen';

  @override
  String get shiftsFlutterAddShift => 'Schicht hinzufügen';

  @override
  String shiftsFlutterAssigningPeople(Object count) {
    return 'Weise $count Personen zu...';
  }

  @override
  String get shiftsFlutterCopyAssignments => 'Zuweisungen kopieren';

  @override
  String shiftsFlutterCopyAssignmentsHint(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen nutzen',
      one: '$count Person nutzt',
    );
    return '$_temp0 diesen Schichtplan. Versuche passende Personen in der Ziel-Instanz zuzuweisen.';
  }

  @override
  String shiftsFlutterCopyFailedWith(Object error) {
    return 'Fehler beim Kopieren: $error';
  }

  @override
  String shiftsFlutterCopyInfo(Object name) {
    return 'Der Schichtplan \"$name\" wird in die ausgewählte Instanz kopiert. Die Definition und feste Schichten werden übernommen.';
  }

  @override
  String get shiftsFlutterCopyInfoAssignments => 'Zuweisungen werden anhand der App-ID (appId) der Personen gemappt.';

  @override
  String get shiftsFlutterCopyingShort => 'Wird kopiert...';

  @override
  String shiftsFlutterCreateFailed(Object error) {
    return 'Fehler beim Erstellen: $error';
  }

  @override
  String shiftsFlutterCreated(Object name) {
    return 'Schichtplan \"$name\" erstellt';
  }

  @override
  String get shiftsFlutterCreatingPlan => 'Erstelle Schichtplan...';

  @override
  String shiftsFlutterCycle(Object count) {
    return 'Zyklus: $count Tage';
  }

  @override
  String shiftsFlutterCycleDays(Object count) {
    return '$count-Tage-Zyklus';
  }

  @override
  String shiftsFlutterDayN(Object n) {
    return 'Tag $n';
  }

  @override
  String get shiftsFlutterDeleteConfirm => 'Möchtest du diesen Schichtplan wirklich löschen?';

  @override
  String shiftsFlutterDeleteConfirmUsed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder nutzen diesen Schichtplan.',
      one: '$count Mitglied nutzen diesen Schichtplan.',
    );
    return '$_temp0 Möchtest du ihn trotzdem löschen?';
  }

  @override
  String get shiftsFlutterDescriptionHint => 'z.B. Früh, Spät, Nacht';

  @override
  String get shiftsFlutterDurationHint => 'z.B. 8.0';

  @override
  String get shiftsFlutterEditSegment => 'Segment bearbeiten';

  @override
  String shiftsFlutterErrorWith(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get shiftsFlutterFirstSegment => 'Erstes Segment';

  @override
  String get shiftsFlutterFixedHint => 'Feste Schichten definieren konkrete Startdaten für den Schichtzyklus.';

  @override
  String get shiftsFlutterFixedShifts => 'Feste Schichten';

  @override
  String get shiftsFlutterFreeHint => 'Mitarbeiter ist an diesem Tag frei';

  @override
  String get shiftsFlutterInfoText => 'Schichtpläne ermöglichen automatische Entschuldigungen basierend auf Arbeitsschichten. Weise einem Mitglied einen Schichtplan zu, um Konflikte mit Terminen automatisch zu erkennen.';

  @override
  String get shiftsFlutterInfoTitle => 'Automatische Entschuldigungen';

  @override
  String get shiftsFlutterLabelHint => 'z.B. Frühdienst';

  @override
  String get shiftsFlutterNameHint => 'z.B. 3-Schicht-System';

  @override
  String shiftsFlutterNext30From(Object date) {
    return 'Nächste 30 Tage ab $date';
  }

  @override
  String get shiftsFlutterNext30Today => 'Nächste 30 Tage ab heute';

  @override
  String get shiftsFlutterNoDefinition => 'Keine Definition';

  @override
  String get shiftsFlutterNoDefinitionYet => 'Keine Definition vorhanden';

  @override
  String get shiftsFlutterNoFixed => 'Keine festen Schichten';

  @override
  String get shiftsFlutterNoSegments => 'Keine Schicht-Segmente definiert';

  @override
  String get shiftsFlutterNotFound => 'Schichtplan nicht gefunden';

  @override
  String get shiftsFlutterNote => 'Hinweis';

  @override
  String get shiftsFlutterOneDay => '1 Tag';

  @override
  String get shiftsFlutterPlan => 'Schichtplan';

  @override
  String get shiftsFlutterPreview => 'Vorschau';

  @override
  String shiftsFlutterPreviewOf(Object name) {
    return 'Vorschau: $name';
  }

  @override
  String shiftsFlutterRepeatTimes(Object count) {
    return '${count}x wiederholen';
  }

  @override
  String get shiftsFlutterRepetitionsHint => 'Anzahl aufeinanderfolgender Tage';

  @override
  String get shiftsFlutterSearchingPeople => 'Suche passende Personen in Ziel-Instanz...';

  @override
  String shiftsFlutterSegments(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Segmente',
      one: '$count Segment',
    );
    return '$_temp0';
  }

  @override
  String shiftsFlutterShiftsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schichten',
      one: '$count Schicht',
    );
    return '$_temp0';
  }

  @override
  String get shiftsFlutterStart => 'Start';

  @override
  String shiftsFlutterStartDateToday(Object date) {
    return 'Startdatum: Heute ($date)';
  }

  @override
  String shiftsFlutterStartDateWith(Object date, Object name) {
    return 'Startdatum: $date ($name)';
  }

  @override
  String get shiftsFlutterTargetTenant => 'Ziel-Instanz';

  @override
  String shiftsFlutterUsage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder nutzen diesen Schichtplan',
      one: '$count Mitglied nutzen diesen Schichtplan',
    );
    return '$_temp0';
  }

  @override
  String get shiftsFlutterWillCopy => 'Wird kopiert:';

  @override
  String get shiftsFree => 'Frei';

  @override
  String get shiftsImportant => 'WICHTIG: Die Anwesenheiten der Personen werden immer nach dem Anlegen einer neuen Anwesenheit und beim Zuweisen eines Schichtplans einer Person aktualisiert.';

  @override
  String get shiftsIntro => 'Pflege Schichtpläne um automatisiert Personen bei Anwesenheiten zu entschuldigen wenn diese aufgrund von Schichten nicht verfügbar sind. Du kannst verschiedene Schichtpläne anlegen und diese dann den Personen zuweisen. Personen werden nur dann als \"entschuldigt\" markiert, wenn sie einer Schicht zugewiesen sind und die Schicht zur Zeit des Termins stattfindet. Die Notiz \"Schichtbedingt\" wird dann automatisch bei der Anwesenheit hinzugefügt.';

  @override
  String get shiftsLabel => 'Bezeichnung';

  @override
  String get shiftsNoOtherTenants => 'Keine anderen Instanzen verfügbar.';

  @override
  String get shiftsNoShifts => 'Keine Schichten hinzugefügt.';

  @override
  String get shiftsNone => 'Keine Schichtpläne vorhanden.';

  @override
  String get shiftsOnlyPlan => 'Nur Schichtplan';

  @override
  String get shiftsPlans => 'Schichtpläne';

  @override
  String get shiftsRepetitions => 'Wiederholungen';

  @override
  String get shiftsRepetitionsHelper => 'Anzahl der Wiederholungen dieser Schicht im Plan.';

  @override
  String get shiftsSaveFailed => 'Fehler beim Speichern des Schichtplans';

  @override
  String get shiftsSaved => 'Schichtplan gespeichert';

  @override
  String shiftsSection(Object n) {
    return 'Abschnitt $n';
  }

  @override
  String get shiftsSelectTenant => 'Bitte wähle eine Instanz aus.';

  @override
  String get shiftsStartDate => 'Anfangsdatum';

  @override
  String get shiftsStartTime => 'Startzeit';

  @override
  String get shiftsWarning => 'ACHTUNG: Das Ändern der Schichtdefinition kann zu Inkonsistenzen führen. Falls der Schichtplan bereits einer Person zugewiesen wurde, können feste Schichten nicht mehr geändert oder entfernt werden! Lege stattdessen einen neuen Schichtplan an.';

  @override
  String get shiftsWithAssignments => 'Mit Zuweisungen';

  @override
  String get signoutAbsenceDeleted => 'Abwesenheit gelöscht';

  @override
  String get signoutAbsenceEntered => 'Abwesenheit eingetragen';

  @override
  String signoutAbsenceEnteredCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine',
      one: '$count Termin',
    );
    return 'Abwesenheit eingetragen ($_temp0 entschuldigt)';
  }

  @override
  String get signoutAbsenceTileSub => 'melden';

  @override
  String get signoutAbsenceTileTitle => 'Abwesenheit';

  @override
  String get signoutAccept => 'Zusagen';

  @override
  String signoutAllCount(Object count) {
    return 'Alle $count';
  }

  @override
  String get signoutAllDutiesFilled => 'Gerade sind alle Dienste besetzt. Danke!';

  @override
  String get signoutAttendance => 'Anwesenheit';

  @override
  String signoutAttendancePercent(Object perc) {
    return '$perc% Anwesenheit';
  }

  @override
  String get signoutCannot => 'Kann nicht';

  @override
  String get signoutCannotAfterAll => 'Kann doch nicht';

  @override
  String get signoutChooseEnd => 'Endtag wählen';

  @override
  String signoutChooseLyricsFor(Object song) {
    return 'Liedtext für $song auswählen';
  }

  @override
  String signoutChooseScoresFor(Object song) {
    return 'Noten für $song auswählen';
  }

  @override
  String get signoutChooseStart => 'Starttag wählen';

  @override
  String signoutConductor(Object name) {
    return 'Dirigent: $name';
  }

  @override
  String get signoutConfirmPause => 'Pausieren bestätigen';

  @override
  String get signoutConfirmed => 'bestätigt';

  @override
  String get signoutCurrent => 'Aktuell';

  @override
  String get signoutCurrentSongs => 'Aktuelle Werke';

  @override
  String signoutDeadline(Object date) {
    return 'Anmeldefrist: $date Uhr';
  }

  @override
  String get signoutDeadlinePassed => 'Anmeldefrist abgelaufen';

  @override
  String get signoutDecline => 'Absagen';

  @override
  String get signoutDeleteAbsence => 'Abwesenheit löschen';

  @override
  String get signoutDeleteAbsenceMessage => 'Soll die Abwesenheit gelöscht werden? Bereits entschuldigte Termine in diesem Zeitraum werden auf den Standardstatus des jeweiligen Termintyps zurückgesetzt.';

  @override
  String get signoutDescription => 'Beschreibung';

  @override
  String get signoutDownloadRecording => 'Aufnahme herunterladen';

  @override
  String get signoutDownloadScores => 'Noten downloaden';

  @override
  String signoutDutiesThisMonth(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dienste',
      one: 'Dienst',
    );
    return '$_temp0 diesen Monat';
  }

  @override
  String get signoutDuty => 'Dienst';

  @override
  String get signoutDutyConfirmed => 'Danke, dein Dienst ist bestätigt 🙂';

  @override
  String get signoutDutyFull => 'Jemand war schneller, der Dienst ist schon voll.';

  @override
  String get signoutDutyNotAllowed => 'Du kannst diesen Dienst nicht übernehmen.';

  @override
  String signoutDutyOccupied(Object occupied, Object required) {
    return '$occupied von $required besetzt';
  }

  @override
  String get signoutDutySignedUp => 'Danke, du bist eingetragen 🙂';

  @override
  String get signoutEditNote => 'Notiz anpassen';

  @override
  String get signoutEditRegistrationFields => 'Anmeldefelder anpassen';

  @override
  String get signoutEndPause => 'Pausierung beenden';

  @override
  String get signoutEndPauseMessage => 'Möchtest du deine Pausierung wirklich beenden und wieder aktiv werden?';

  @override
  String get signoutEnterAbsence => 'Abwesenheit eintragen';

  @override
  String get signoutEnterLate => 'Verspätung eintragen';

  @override
  String get signoutEnterNote => 'Gib hier deine Notiz ein';

  @override
  String get signoutFiles => 'Dateien';

  @override
  String signoutFillField(Object field) {
    return 'Bitte \"$field\" ausfüllen';
  }

  @override
  String get signoutFillRequired => 'Bitte fülle alle Pflichtfelder aus';

  @override
  String get signoutFlutterAbsenceSaveFailed => 'Abwesenheit konnte nicht gespeichert werden';

  @override
  String signoutFlutterError(Object error) {
    return 'Fehler: $error';
  }

  @override
  String signoutFlutterEventsCount(Object count) {
    return '$count Termine';
  }

  @override
  String get signoutFlutterFieldsSaveFailed => 'Anmeldefelder konnten nicht gespeichert werden.';

  @override
  String get signoutFlutterFileDownloadFailed => 'Datei konnte nicht heruntergeladen werden';

  @override
  String get signoutFlutterFileOpenFailed => 'Datei konnte nicht geöffnet werden';

  @override
  String signoutFlutterFilesSkipped(Object count) {
    return '$count Datei(en) konnten nicht eingebunden werden.';
  }

  @override
  String get signoutFlutterLinkOpenFailed => 'Link konnte nicht geöffnet werden';

  @override
  String get signoutFlutterNoCurrentSongs => 'Keine aktuellen Werke';

  @override
  String get signoutFlutterNoPerson => 'Für dein Konto wurde in dieser Instanz keine Person gefunden.';

  @override
  String get signoutFlutterNoPrintableScores => 'Keine druckbaren Noten gefunden.';

  @override
  String get signoutFlutterNoteSaveFailed => 'Notiz konnte nicht gespeichert werden.';

  @override
  String get signoutFlutterPrintAllScores => 'Alle Noten drucken';

  @override
  String signoutFlutterShowAll(Object count) {
    return 'Alle $count anzeigen';
  }

  @override
  String get signoutFlutterShowLess => 'Weniger anzeigen';

  @override
  String get signoutFlutterSigninFailed => 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get signoutFlutterSignoutFailed => 'Abmeldung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get signoutFlutterSwitchTenantFailed => 'Instanz konnte nicht gewechselt werden';

  @override
  String get signoutGiveReason => 'Bitte gib einen Grund an!';

  @override
  String get signoutGladYouCome => 'Schön, dass du dabei bist 🙂';

  @override
  String signoutGreeting(Object name) {
    return 'Shalom $name!';
  }

  @override
  String get signoutIllTakeIt => 'Ich übernehme';

  @override
  String get signoutInfos => 'Infos';

  @override
  String get signoutLastEventsStatus => 'Status der letzten Termine';

  @override
  String get signoutLateButton => 'Verspätung';

  @override
  String signoutLateCount(Object count) {
    return '$count× zu spät';
  }

  @override
  String get signoutLegend => 'Legende';

  @override
  String get signoutLegendAccepted => 'Zugesagt';

  @override
  String get signoutLegendAcceptedPresent => 'Zugesagt / Anwesend';

  @override
  String get signoutLegendLate => 'Verspätet';

  @override
  String get signoutLegendLateReported => 'Verspätung gemeldet';

  @override
  String get signoutLegendLateReportedExcused => 'Verspätung gemeldet (entschuldigt)';

  @override
  String get signoutListenRecording => 'Aufnahme anhören';

  @override
  String get signoutLongAbsenceHint => 'Für längere Abwesenheiten empfiehlt sich die Pausieren-Funktion, damit du nicht in neuen Terminen erscheinst.';

  @override
  String get signoutMoreEvents => 'Weitere Termine';

  @override
  String get signoutMoreOptions => 'Weitere Optionen';

  @override
  String get signoutMyDuties => 'Meine Dienste';

  @override
  String get signoutNextDuty => 'Nächster Dienst';

  @override
  String get signoutNoActions => 'Für diesen Termin sind keine Aktionen verfügbar.';

  @override
  String get signoutNoEndDate => 'Kein Enddatum gewählt';

  @override
  String get signoutNoScoresForInstrument => 'Für dein Instrument sind leider keine Noten verfügbar.';

  @override
  String get signoutNoScoresFound => 'Keine Noten für dein Instrument gefunden.';

  @override
  String get signoutNoSongActions => 'Für dieses Werk sind keine Aktionen verfügbar.';

  @override
  String signoutNoteChip(Object note) {
    return 'Notiz: $note';
  }

  @override
  String get signoutNoteForSignin => 'Notiz für Anmeldung';

  @override
  String get signoutNoteUpdated => 'Notiz erfolgreich aktualisiert.';

  @override
  String get signoutOpenAttachment => 'Anhang öffnen';

  @override
  String get signoutOpenDuties => 'Offene Dienste';

  @override
  String get signoutOpenFiles => 'Dateiablage öffnen';

  @override
  String get signoutOpenInTeam => 'offen im Team';

  @override
  String get signoutOpenNavigation => 'Navigation öffnen';

  @override
  String get signoutOpenScoreLink => 'Notenlink öffnen';

  @override
  String get signoutPast => 'Vergangen';

  @override
  String get signoutPause => 'Pausieren';

  @override
  String get signoutPauseReasonPlaceholder => 'Warum möchtest du pausieren?';

  @override
  String get signoutPaused => 'Pausiert';

  @override
  String get signoutPausedUntil => 'Pausiert bis (optional)';

  @override
  String get signoutPlannedAbsences => 'Geplante Abwesenheiten';

  @override
  String get signoutPleaseConfirm => 'Bitte bestätigen';

  @override
  String get signoutPrintScores => 'Noten drucken';

  @override
  String signoutPrintScoresFor(Object song) {
    return 'Noten für $song drucken';
  }

  @override
  String get signoutReactivate => 'Reaktivieren';

  @override
  String get signoutReasonPlaceholder => 'z.B. Urlaub, Krankheit...';

  @override
  String get signoutReasonRequired => 'Grund *';

  @override
  String get signoutRegistrationFieldsSaved => 'Anmeldefelder gespeichert.';

  @override
  String get signoutRegistrationSubmitted => 'Deine Registrierung wurde erfolgreich übermittelt. Du wirst benachrichtigt, sobald diese bearbeitet wurde.';

  @override
  String get signoutRegularlyUnavailable => 'Regelmäßig verhindert';

  @override
  String get signoutRegularlyUnavailableHint => 'z. B. jeden Mittwoch wegen der Kinderstunde';

  @override
  String get signoutReportAbsence => 'Abwesenheit melden';

  @override
  String get signoutRoute => 'Route';

  @override
  String get signoutRunSheet => 'Ablaufplan';

  @override
  String get signoutShowDescription => 'Beschreibung anzeigen';

  @override
  String get signoutShowRunSheet => 'Ablaufplan anzeigen';

  @override
  String get signoutShowScores => 'Noten anzeigen';

  @override
  String get signoutSignIn => 'Anmelden';

  @override
  String get signoutSignInWithNote => 'Anmelden mit Notiz';

  @override
  String get signoutSignOut => 'Abmelden';

  @override
  String get signoutThanksLate => 'Vielen Dank für die Info und Gottes Segen dir!';

  @override
  String get signoutThanksSignout => 'Vielen Dank für deine rechtzeitige Abmeldung und Gottes Segen dir.';

  @override
  String get signoutToConfirm => 'zu bestätigen';

  @override
  String get signoutUndoSignout => 'Abmeldung zurücknehmen';

  @override
  String get signoutUpcoming => 'Anstehend';

  @override
  String get signoutUrgent => 'Dringend';

  @override
  String get signoutViewLyrics => 'Liedtext ansehen';

  @override
  String signoutWithTeam(Object names) {
    return ' · mit $names';
  }

  @override
  String get signoutYou => 'Du';

  @override
  String get signoutYouAreAssigned => 'Du bist eingeteilt';

  @override
  String get signoutYourDutyRoster => 'Dein Dienstplan';

  @override
  String get songsAddCategory => 'Kategorie hinzufügen';

  @override
  String get songsAddSong => 'Werk hinzufügen';

  @override
  String get songsAddWithoutReplace => 'Ohne Ersetzen hinzufügen';

  @override
  String get songsAllSongs => 'Alle Werke';

  @override
  String get songsCatalogPdf => 'Werkverzeichnis als PDF';

  @override
  String songsCatalogTitle(Object tenant) {
    return '$tenant Werkverzeichnis';
  }

  @override
  String get songsCategories => 'Kategorien';

  @override
  String get songsCategoryAdded => 'Kategorie hinzugefügt';

  @override
  String get songsCategoryDeleted => 'Kategorie gelöscht';

  @override
  String get songsCategoryName => 'Name der Kategorie';

  @override
  String get songsCategoryNameEmpty => 'Der Name der Kategorie darf nicht leer sein';

  @override
  String get songsCategorySaved => 'Kategorie gespeichert';

  @override
  String get songsChangeCategory => 'Kategorie ändern';

  @override
  String get songsChoir => 'Chor';

  @override
  String get songsChoirOrchShort => 'Chor/Orch.';

  @override
  String get songsChoirOrchestra => 'Chor & Orchester';

  @override
  String get songsChooseGroup => 'Gruppe wählen';

  @override
  String get songsChooseGroupPlease => 'Bitte eine Gruppe auswählen.';

  @override
  String get songsChooseGroups => 'Gruppen wählen';

  @override
  String get songsConductors => 'Dirigenten';

  @override
  String get songsCopied => 'Werk wurde erfolgreich kopiert';

  @override
  String get songsCopiesPerGroup => 'Wie viele Ausdrucke pro Gruppe?';

  @override
  String get songsCopy => 'Kopieren';

  @override
  String songsCopyFailed(Object error) {
    return 'Fehler beim Kopieren des Werks: $error';
  }

  @override
  String songsCopyInfo(Object name) {
    return 'Das Werk \"$name\" wird in die ausgewählte Instanz kopiert. Alle Dateien werden ebenfalls kopiert. Die Kategorie wird nicht übernommen. Instrumentenzuordnungen werden automatisch anhand des Namens gemappt.';
  }

  @override
  String get songsCopyLink => 'Link kopieren';

  @override
  String get songsCopySong => 'Werk kopieren';

  @override
  String get songsCopyToOther => 'Werk in andere Instanz kopieren';

  @override
  String get songsCopying => 'Werk wird kopiert...';

  @override
  String songsCopyingFile(Object current, Object total) {
    return 'Datei $current von $total wird kopiert...';
  }

  @override
  String get songsCreatingPdf => 'PDF wird erstellt...';

  @override
  String get songsCurrent => 'Aktuelle Werke';

  @override
  String get songsDeleteAll => 'Alle Dateien löschen';

  @override
  String get songsDeleteAllConfirm => 'Möchten Sie wirklich alle Dateien dieses Werks löschen?';

  @override
  String get songsDeleteCategory => 'Kategorie löschen';

  @override
  String get songsDeleteCategoryMessage => 'Möchten Sie diese Kategorie wirklich löschen? Alle Werke in dieser Kategorie werden keiner neuen Kategorie zugewiesen.';

  @override
  String get songsDeleteConfirm => 'Soll das Werk wirklich gelöscht werden?';

  @override
  String get songsDeleteFile => 'Datei löschen';

  @override
  String songsDeleteFileConfirm(Object name) {
    return 'Möchten Sie die Datei \"$name\" wirklich löschen?';
  }

  @override
  String get songsDeleteSong => 'Werk löschen';

  @override
  String songsDeleteSyncedMessage(Object names) {
    return 'Die Werke werden mit $names geteilt. Das Werk wird dort ebenfalls gelöscht, inklusive der Historie aller beteiligten Instanzen. Soll das Werk wirklich gelöscht werden?';
  }

  @override
  String get songsDeleting => 'Werk wird gelöscht...';

  @override
  String get songsDeletingFiles => 'Dateien werden gelöscht...';

  @override
  String get songsDifficulty => 'Schwierigkeitsgrad';

  @override
  String get songsDifficulty123 => 'Schwierigkeit (1/2/3)';

  @override
  String get songsDifficultyShort => 'Schwierigkeit';

  @override
  String get songsDontClose => 'Bitte das Fenster nicht schließen, bis der Upload abgeschlossen ist.';

  @override
  String get songsDownloadAll => 'Alle Dateien herunterladen';

  @override
  String get songsDownloadFile => 'Datei herunterladen';

  @override
  String get songsDownloadRecording => 'Aufnahme herunterladen';

  @override
  String get songsDownloadingFiles => 'Dateien werden heruntergeladen...';

  @override
  String get songsDropHere => 'Dateien hierher ziehen oder tippen zum Auswählen';

  @override
  String get songsEasy => '1 - Leicht';

  @override
  String get songsEditCategory => 'Kategorie bearbeiten';

  @override
  String get songsEditSong => 'Werk bearbeiten';

  @override
  String get songsEnterCategory => 'Kategorie eingeben...';

  @override
  String get songsEvery2 => 'Jede 2. Person';

  @override
  String get songsEvery3 => 'Jede 3. Person';

  @override
  String get songsEvery4 => 'Jede 4. Person';

  @override
  String get songsFileActions => 'Datei Aktionen';

  @override
  String songsFileTooLarge(Object name) {
    return 'Die Datei $name überschreitet die maximale Größe von 20MB.';
  }

  @override
  String get songsFiles => 'Dateien';

  @override
  String songsFlutterCopiesCount(Object count) {
    return '$count Kopien';
  }

  @override
  String get songsFlutterCopiesPerInstrument => 'Kopien pro Instrument:';

  @override
  String get songsFlutterCreateFailed => 'Werk konnte nicht erstellt werden';

  @override
  String get songsFlutterCreatingInTarget => 'Erstelle Werk in Ziel-Instanz...';

  @override
  String get songsFlutterDeleteFailed => 'Werk konnte nicht gelöscht werden';

  @override
  String get songsFlutterDetectNone => 'Nicht erkannt – bitte zuordnen';

  @override
  String get songsFlutterDetectUnsure => 'Unsicher erkannt – bitte prüfen';

  @override
  String get songsFlutterDownloadFileFailed => 'Datei konnte nicht heruntergeladen werden';

  @override
  String songsFlutterErrorWith(Object error) {
    return 'Fehler: $error';
  }

  @override
  String songsFlutterFileDownloadFailed(Object name) {
    return 'Datei konnte nicht heruntergeladen werden: $name';
  }

  @override
  String songsFlutterFilesSkipped(Object count) {
    return '$count Datei(en) konnten nicht eingebunden werden.';
  }

  @override
  String songsFlutterFilesWillBeCopied(Object count) {
    return '$count Dateien werden kopiert:';
  }

  @override
  String get songsFlutterFilterAndView => 'Filter & Ansicht';

  @override
  String get songsFlutterFirstPage => 'Erste Seite';

  @override
  String get songsFlutterFullscreen => 'Vollbild';

  @override
  String get songsFlutterHideTab => 'Tab ausblenden';

  @override
  String get songsFlutterInvalidId => 'Ungültige Werk-ID';

  @override
  String get songsFlutterLastPage => 'Letzte Seite';

  @override
  String get songsFlutterLearnFailed => 'Die Begriffe konnten nicht gemerkt werden';

  @override
  String songsFlutterLearnTerm(Object term, Object group) {
    return '„$term“ künftig als $group erkennen';
  }

  @override
  String songsFlutterListAnd(Object rest, Object last) {
    return '$rest und $last';
  }

  @override
  String get songsFlutterLoadingTargetGroups => 'Lade Ziel-Instrumente...';

  @override
  String get songsFlutterMenu => 'Menü';

  @override
  String get songsFlutterNextPage => 'Nächste Seite';

  @override
  String get songsFlutterNoPlayers => 'Keine Spieler gefunden';

  @override
  String get songsFlutterNoSongs => 'Keine Werke vorhanden';

  @override
  String get songsFlutterNotFound => 'Werk nicht gefunden';

  @override
  String get songsFlutterOneEach => 'Je 1';

  @override
  String get songsFlutterOpenFileFailed => 'Konnte Datei nicht öffnen';

  @override
  String songsFlutterPdfCreateFailed(Object error) {
    return 'Fehler beim Erstellen der PDF: $error';
  }

  @override
  String get songsFlutterPdfLoadFailed => 'PDF konnte nicht geladen werden';

  @override
  String get songsFlutterPdfLoading => 'PDF wird geladen...';

  @override
  String get songsFlutterPdfPagedMode => 'Seitenweise blättern';

  @override
  String get songsFlutterPdfScrollMode => 'Durchgehend scrollen';

  @override
  String get songsFlutterPreviousPage => 'Vorherige Seite';

  @override
  String songsFlutterPrintFailed(Object error) {
    return 'Fehler beim Drucken: $error';
  }

  @override
  String get songsFlutterPrintFileFailed => 'Datei konnte nicht gedruckt werden';

  @override
  String get songsFlutterPrintJobSent => 'Druckauftrag gesendet';

  @override
  String get songsFlutterPrinting => 'Wird gedruckt...';

  @override
  String get songsFlutterReorderCategoriesHint => 'Ziehe Kategorien um sie neu zu sortieren';

  @override
  String get songsFlutterReviewHint => 'Bei diesen Dateien ist die Stimme nicht eindeutig. Bitte prüfe die Zuordnung vor dem Hochladen.';

  @override
  String get songsFlutterReviewTitle => 'Zuordnung prüfen';

  @override
  String get songsFlutterReviewUpload => 'Hochladen';

  @override
  String get songsFlutterShowAsTab => 'Als Tab anzeigen';

  @override
  String get songsFlutterSong => 'Werk';

  @override
  String get songsFlutterTelegramSent => 'Datei per Telegram gesendet';

  @override
  String songsFlutterUploadFailedWith(Object error) {
    return 'Fehler beim Hochladen: $error';
  }

  @override
  String get songsFlutterVisionReading => 'Erste Seite wird gelesen …';

  @override
  String songsFlutterVisionSure(Object label) {
    return 'Auf Seite 1 erkannt: $label';
  }

  @override
  String get songsFlutterVisionUnsure => 'Auf Seite 1 vermutet – bitte prüfen';

  @override
  String get songsFreeText => 'Freitext';

  @override
  String get songsGroup => 'Gruppe';

  @override
  String get songsGroupDirectory => 'Gruppenverzeichnis';

  @override
  String get songsHard => '3 - Schwer';

  @override
  String songsHistoryCount(Object count) {
    return 'Historie (${count}x)';
  }

  @override
  String get songsImportIntro => 'Importiere Werke aus einer Excel- (.xlsx/.xls) oder CSV-Datei. Die erste Zeile muss Spaltenüberschriften enthalten. Am einfachsten ist es, die Vorlage herunterzuladen und auszufüllen.';

  @override
  String get songsImportSongs => 'Werke importieren';

  @override
  String get songsImportantInfo => 'Wichtige Infos';

  @override
  String songsImportedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Werke importiert.',
      one: '$count Werk importiert.',
    );
    return '$_temp0';
  }

  @override
  String get songsInstrument => 'Instrument';

  @override
  String get songsInstrumentation => 'Besetzung';

  @override
  String get songsInvalidLink => 'Der angegebene Link ist nicht valide';

  @override
  String get songsInvalidShareLink => 'Ungültiger Freigabe-Link.';

  @override
  String get songsLastPlayed => 'Zuletzt gespielt';

  @override
  String songsLastPlayedOn(Object date, Object conductor) {
    return 'Zuletzt gespielt am $date | $conductor';
  }

  @override
  String get songsLastSung => 'Zuletzt gesungen';

  @override
  String songsLastSungOn(Object date, Object conductor) {
    return 'Zuletzt gesungen am $date | $conductor';
  }

  @override
  String get songsLink => 'Link';

  @override
  String get songsLinkCopied => 'Der Link wurde in die Zwischenablage kopiert';

  @override
  String get songsLyrics => 'Liedtext';

  @override
  String get songsLyricsWarning => 'Warnung: Liedtext-Format';

  @override
  String songsLyricsWarningMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien wurden',
      one: '$count Datei wurde',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sind aber keine PDF-Dateien',
      one: 'ist aber keine PDF-Datei',
    );
    return '$_temp0 als \"Liedtext\" kategorisiert, $_temp1. Die Spieler und Sänger können diese Dateien daher nicht in ihrer Übersicht bei den aktuellen Werken sehen.';
  }

  @override
  String get songsMapNumberName => 'Bitte Spalten für Nummer und Name zuordnen.';

  @override
  String get songsMappingIntro => 'Ordne die Spalten deiner Datei den Werkfeldern zu. Nummer und Name sind erforderlich.';

  @override
  String get songsMedium => '2 - Mittel';

  @override
  String get songsMissingInstruments => 'Fehlende Instrumente';

  @override
  String get songsName => 'Name';

  @override
  String get songsNameAsc => 'Name ↑';

  @override
  String get songsNameDesc => 'Name ↓';

  @override
  String get songsNoCategories => 'Es wurden noch keine Kategorien angelegt.';

  @override
  String get songsNoCategory => 'Keine Kategorie';

  @override
  String get songsNoFiles => 'Keine Dateien vorhanden.';

  @override
  String get songsNoGroupPdfs => 'Keine Gruppen-PDFs zum Drucken gefunden';

  @override
  String get songsNoGroupsWithPeople => 'Keine Gruppen mit zugewiesenen Personen gefunden';

  @override
  String get songsNoScoresCurrent => 'Keine Noten für diese Gruppe in den aktuellen Werken gefunden.';

  @override
  String get songsNoScoresGroup => 'Keine Noten für diese Gruppe vorhanden.';

  @override
  String get songsNotDefined => 'Nicht definiert';

  @override
  String get songsNotImported => 'Nicht importierte Werke';

  @override
  String get songsNotPlayedYet => 'Noch nicht gespielt · ';

  @override
  String get songsNotSungYet => 'Noch nicht gesungen · ';

  @override
  String get songsNothingToImport => 'Keine importierbaren Werke.';

  @override
  String get songsNumber => 'Nummer';

  @override
  String get songsNumberAsc => 'Nummer ↑';

  @override
  String get songsNumberDesc => 'Nummer ↓';

  @override
  String get songsNumberShort => 'Nr.';

  @override
  String get songsNumberTaken => 'Die Liednummer ist bereits vergeben';

  @override
  String get songsOnlyGroupsWithFiles => 'Es werden nur Gruppen angezeigt, für die Dateien vorhanden sind.';

  @override
  String get songsOpenExternalLink => 'Externen Noten-Link öffnen';

  @override
  String get songsOpenFile => 'Datei öffnen';

  @override
  String get songsOrchestra => 'Orchester';

  @override
  String get songsOther => 'Sonstige';

  @override
  String get songsOtherFreeText => 'Sonstige (Freitext)';

  @override
  String get songsPerGroup => '1 pro Gruppe';

  @override
  String get songsPerPerson => 'Alle Personen (1 pro Person)';

  @override
  String songsPlannedOn(Object date) {
    return 'Geplant am $date';
  }

  @override
  String get songsPlayRecording => 'Aufnahme abspielen';

  @override
  String get songsPrefix => 'Präfix';

  @override
  String get songsPrefixHelper => 'Bspw. um Weihnachtslieder kennzeichnen zu können (z.B. W für Weihnachten -> W1)';

  @override
  String get songsPrefixOptional => 'Präfix (optional)';

  @override
  String get songsPrint => 'Drucken';

  @override
  String get songsPrintFile => 'Datei drucken';

  @override
  String get songsPrintGroupPdfs => 'Gruppen-PDFs drucken';

  @override
  String get songsPrintOptions => 'Druckoptionen';

  @override
  String songsPrintPrepared(Object summary) {
    return 'Druck vorbereitet: $summary';
  }

  @override
  String get songsPrintScores => 'Noten drucken';

  @override
  String get songsRecording => 'Aufnahme';

  @override
  String get songsReplaceAndAdd => 'Ersetzen & Hinzufügen';

  @override
  String songsReplaces(Object name) {
    return 'Ersetzt: $name';
  }

  @override
  String get songsSendTelegram => 'Per Telegram senden';

  @override
  String get songsSendingFile => 'Datei wird versendet...';

  @override
  String get songsShowCurrent => 'Aktuelle Werke anzeigen';

  @override
  String get songsSolo => 'Solo';

  @override
  String get songsSongCategories => 'Werk-Kategorien';

  @override
  String songsSongsCount(Object count) {
    return 'Werke ($count)';
  }

  @override
  String get songsSourceInstance => 'der Quellinstanz';

  @override
  String get songsUnknownCategory => 'Unbekannte Kategorie';

  @override
  String get songsUpload => 'Hochladen';

  @override
  String get songsUploadAnyway => 'Trotzdem hochladen';

  @override
  String songsUploadDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien erfolgreich hochgeladen.',
      one: '$count Datei erfolgreich hochgeladen.',
    );
    return '$_temp0';
  }

  @override
  String get songsUploadFile => 'Datei hochladen';

  @override
  String get songsUploadFiles => 'Dateien hochladen';

  @override
  String get songsUploadInfo => '- Die Besetzung wird nach dem Hochladen automatisch anhand der ausgewählten Instrumente aktualisiert.<br>- Füge den Instrumenten Synonyme hinzu (<a href=\"/tabs/settings/instruments\">Gruppeneinstellungen</a>), um die automatische Zuordnung der Dateien zu verbessern.<br>- Beim Hochladen mehrerer Dateien kann es je nach Dateigröße und Internetverbindung einige Zeit dauern, bis alle Dateien vollständig hochgeladen sind. Bitte schließen Sie das Fenster nicht, bis der Upload abgeschlossen ist.';

  @override
  String songsUploadPartialFail(Object failed, Object total) {
    return '$failed von $total Datei(en) konnten nicht hochgeladen werden.';
  }

  @override
  String songsUploadProgress(Object done, Object total) {
    return '$done von $total Dateien hochgeladen';
  }

  @override
  String get songsUploading => 'Datei wird hochgeladen...';

  @override
  String get songsWhichReplace => 'Welche Dateien sollen ersetzt werden?';

  @override
  String get songsWithSolo => 'Mit Solo';

  @override
  String get songsWithSoloSinging => 'Mit Solo-Gesang';

  @override
  String get statsActiveMembers => 'Aktive Mitglieder';

  @override
  String get statsAgeChart => 'Altersverteilung 🎂';

  @override
  String get statsAgeDistribution => '🎂 Altersverteilung';

  @override
  String statsAllCount(Object count) {
    return 'Alle ($count)';
  }

  @override
  String get statsAttendancePercent => 'Anwesenheit %';

  @override
  String get statsAvgAgeChart => 'Durchschnittsalter pro Instrument';

  @override
  String get statsAvgAgeInstrument => '📊 Durchschnittsalter pro Instrument';

  @override
  String get statsAvgAttendance => 'Ø Anwesenheit';

  @override
  String get statsBest => 'Beste Anwesenheit';

  @override
  String get statsCount => 'Anzahl';

  @override
  String get statsEventsInPeriod => 'Termine im Zeitraum';

  @override
  String get statsFilterTenants => 'Instanzen filtern';

  @override
  String statsFlutterAbsencesCount(Object count) {
    return '$count Fehlzeiten';
  }

  @override
  String get statsFlutterNoBirthdays => 'Keine Geburtsdaten vorhanden';

  @override
  String get statsFlutterNoData => 'Keine Daten verfügbar';

  @override
  String get statsFlutterNoDataInPeriod => 'Keine Daten im ausgewählten Zeitraum';

  @override
  String get statsFlutterNoUnexcused => 'Keine unentschuldigten Abwesenheiten';

  @override
  String statsFlutterOrganisation(Object name) {
    return 'Organisation: $name';
  }

  @override
  String statsFlutterSelectedOf(Object selected, Object total) {
    return '$selected von $total ausgewählt';
  }

  @override
  String statsFlutterTenantsCount(Object count) {
    return '$count Instanzen';
  }

  @override
  String get statsHistoryChart => 'Anwesenheitsverlauf (letzte 20 Termine)';

  @override
  String get statsInstrumentChart => 'Anwesenheitsquote nach Instrument';

  @override
  String get statsLeft => 'Ausgetreten';

  @override
  String get statsMembers => '👥 Mitglieder';

  @override
  String get statsOrgTenants => 'Instanzen der Organisation';

  @override
  String get statsOverview => '📊 Anwesenheits-Übersicht';

  @override
  String get statsPausing => 'Pausierend';

  @override
  String get statsPerInstrument => '🎻 Anwesenheit pro Instrument';

  @override
  String get statsPeriod => '📅 Zeitraum';

  @override
  String get statsPersonCount => 'Anzahl Personen';

  @override
  String get statsPersonsAllTenants => 'Personen über alle Instanzen';

  @override
  String statsPersonsCount(Object count) {
    return 'Personen ($count)';
  }

  @override
  String statsPieLabel(Object label, Object perc) {
    return '$label ($perc%)';
  }

  @override
  String get statsStatusChart => 'Statusverteilung (in %)';

  @override
  String get statsStatusDistribution => '📉 Statusverteilung';

  @override
  String get statsTenants => 'Instanzen';

  @override
  String get statsTitle => 'Statistiken';

  @override
  String get statsTop20 => '🏆 Top 20 Anwesenheit';

  @override
  String get statsTop20Chart => 'Top 20 - Anwesenheits-Elite 🏆';

  @override
  String get statsTrend => '📈 Anwesenheits-Trend';

  @override
  String get statsUnexcused => '⚠️ Unentschuldigte Abwesenheiten';

  @override
  String get statsUnexcusedAbsences => 'Unentschuldigte Abwesenheiten';

  @override
  String get statsUnexcusedChart => 'Unentschuldigte Fehlzeiten';

  @override
  String get statsWorst => 'Schlechteste Anwesenheit';

  @override
  String get statsYears => 'Jahre';

  @override
  String get svcActivate => 'Aktivieren';

  @override
  String get svcAddAttendanceFailed => 'Fehler beim Hinzufügen der Anwesenheit';

  @override
  String get svcAddCategoryFailed => 'Fehler beim Hinzufügen der Kategorie';

  @override
  String get svcAddGroupCategoryFailed => 'Fehler beim hinzufügen der Gruppenkategorie';

  @override
  String get svcAddPersonAttendancesFailed => 'Fehler beim Hinzufügen der Person-Anwesenheiten';

  @override
  String get svcAddShiftFailed => 'Fehler beim Hinzufügen der Schicht';

  @override
  String get svcAddSongCategoryFailed => 'Fehler beim hinzufügen der Werkkategorie';

  @override
  String get svcAddSongHistoryFailed => 'Fehler beim Hinzufügen der Lieder zur Historie';

  @override
  String get svcAddTypeFailed => 'Fehler beim Hinzufügen des Anwesenheitstyps';

  @override
  String get svcAddUserToTenantFailed => 'Fehler beim Hinzufügen des Benutzers zum Mandanten';

  @override
  String get svcApplyToPlannedFailed => 'Fehler beim Übernehmen in geplante Termine';

  @override
  String get svcAssignFailed => 'Fehler beim Einteilen';

  @override
  String get svcCheckShiftUsageFailed => 'Fehler beim Überprüfen der Schichtverwendung';

  @override
  String get svcCleanupAttendancesFailed => 'Fehler beim Bereinigen der Person-Anwesenheiten';

  @override
  String get svcConfirmFailed => 'Fehler beim Bestätigen';

  @override
  String get svcCreateChurchFailed => 'Fehler beim Erstellen der Kirche';

  @override
  String get svcCreateOrgFailed => 'Fehler beim Erstellen der Organisation';

  @override
  String get svcCreatePublicLinkFailed => 'Fehler beim Erstellen des öffentlichen Links';

  @override
  String get svcCreateTenantFailed => 'Fehler beim Erstellen des Mandanten';

  @override
  String get svcDeleteAbsenceFailed => 'Fehler beim Löschen der Abwesenheit';

  @override
  String get svcDeleteCategoryFailed => 'Fehler beim Löschen der Kategorie';

  @override
  String get svcDeleteChurchFailed => 'Fehler beim Löschen der Gemeinde';

  @override
  String get svcDeleteEntryFailed => 'Fehler beim Löschen des Eintrags';

  @override
  String get svcDeleteFailed => 'Fehler beim Löschen';

  @override
  String get svcDeletePersonAttendanceFailed => 'Fehler beim Löschen der Person-Anwesenheit';

  @override
  String get svcDeletePersonAttendancesFailed => 'Fehler beim Löschen der Person-Anwesenheiten';

  @override
  String get svcDeleteSharedFieldValuesFailed => 'Fehler beim Löschen der gemeinsamen Zusatzfeldwerte';

  @override
  String get svcDeleteShiftFailed => 'Fehler beim Löschen der Schicht';

  @override
  String get svcDeleteSongFailed => 'Fehler beim Löschen des Werks';

  @override
  String get svcDeleteTenantFailed => 'Fehler beim Löschen des Mandanten';

  @override
  String get svcDeleteTypeFailed => 'Fehler beim Löschen des Anwesenheitstyps';

  @override
  String get svcFileLoading => 'Datei wird geladen...';

  @override
  String get svcFolderIntoItself => 'Ordner kann nicht in sich selbst verschoben werden.';

  @override
  String get svcInvalidFileName => 'Ungültiger Dateiname.';

  @override
  String get svcInvalidFolderName => 'Ungültiger Ordnername.';

  @override
  String get svcInvalidName => 'Ungültiger Name.';

  @override
  String get svcLater => 'Später';

  @override
  String get svcLinkFailed => 'Verknüpfung fehlgeschlagen';

  @override
  String get svcLinkOrgFailed => 'Fehler beim Verknüpfen der Organisation';

  @override
  String get svcLinkPeopleFailed => 'Fehler beim Verknüpfen der Personen';

  @override
  String get svcLoadAbsencesFailed => 'Fehler beim Laden der Abwesenheiten';

  @override
  String get svcLoadAdminsFailed => 'Fehler beim Laden der Admins';

  @override
  String get svcLoadAttendancesFailed => 'Fehler beim Laden der Anwesenheiten';

  @override
  String get svcLoadAvailabilityFailed => 'Fehler beim Laden der Verfügbarkeit';

  @override
  String get svcLoadCategoriesFailed => 'Fehler beim Laden der Kategorien';

  @override
  String get svcLoadChurchesFailed => 'Fehler beim Laden der Kirchen';

  @override
  String get svcLoadGroupMembersFailed => 'Fehler beim Laden der Gruppenmitglieder';

  @override
  String get svcLoadMainGroupPeopleFailed => 'Fehler beim Laden der Hauptgruppen-Personen';

  @override
  String get svcLoadOrgFailed => 'Fehler beim Laden der Organisation';

  @override
  String get svcLoadOrgPlansFailed => 'Fehler beim Laden der Organisationspläne';

  @override
  String get svcLoadOrgsFailed => 'Fehler beim Laden der Organisationen';

  @override
  String get svcLoadParentsFailed => 'Fehler beim Laden der Elternteile';

  @override
  String get svcLoadPersonAttendancesFailed => 'Fehler beim Laden der Person-Anwesenheiten';

  @override
  String get svcLoadPlayersFailed => 'Fehler beim Laden der Spieler';

  @override
  String get svcLoadRolePermissionsFailed => 'Fehler beim Laden der Rollenberechtigungen';

  @override
  String get svcLoadSharedFieldsFailed => 'Fehler beim Laden der gemeinsamen Zusatzfelder';

  @override
  String get svcLoadShiftPeopleFailed => 'Fehler beim Laden der Personen mit Schicht';

  @override
  String get svcLoadShiftsFailed => 'Fehler beim Laden der Schichten';

  @override
  String get svcLoadTenantFailed => 'Fehler beim Laden des Mandanten';

  @override
  String get svcLoadTenantFailed2 => 'Fehler beim Laden des Tenants';

  @override
  String get svcLoadTypesFailed => 'Fehler beim Laden der Anwesenheitstypen';

  @override
  String get svcLoadUsersFailed => 'Fehler beim Laden der Benutzer';

  @override
  String get svcLoadViewersFailed => 'Fehler beim Laden der Beobachter';

  @override
  String get svcMergeScoresFailed => 'Fehler beim Zusammenführen der Noten.';

  @override
  String get svcMergingPdfs => 'PDFs werden zusammengeführt...';

  @override
  String get svcMessageSent => 'Nachricht wurde erfolgreich gesendet!';

  @override
  String get svcNoDeletePermission => 'Keine Berechtigung zum Löschen';

  @override
  String get svcNoPlayerFound => 'Es konnte kein Spieler gefunden werden.';

  @override
  String get svcNoPrintableScores => 'Keine druckbaren Noten (PDF/Bild) gefunden.';

  @override
  String get svcNotification => 'Benachrichtigung';

  @override
  String get svcOfflineSaved => 'Offline-Änderungen gespeichert';

  @override
  String get svcOnlyOneMainGroup => 'Es kann nur eine Hauptgruppe existieren';

  @override
  String get svcOrgNotFound => 'Organisation nicht gefunden';

  @override
  String get svcPdfDownloaded => 'PDF heruntergeladen - bitte manuell drucken';

  @override
  String get svcPushPrompt => 'Möchtest du Push-Benachrichtigungen aktivieren? Du wirst über Termine, Checklisten und wichtige Ereignisse informiert.';

  @override
  String get svcPushTitle => 'Push-Benachrichtigungen';

  @override
  String get svcRemoveOrgFailed => 'Fehler beim Entfernen der Organisation';

  @override
  String get svcRenameOrgFailed => 'Fehler beim Umbenennen der Organisation';

  @override
  String get svcRevokePublicLinkFailed => 'Fehler beim Widerrufen des öffentlichen Links';

  @override
  String get svcSaveAbsenceFailed => 'Fehler beim Speichern der Abwesenheit';

  @override
  String get svcSaveBrandingFailed => 'Fehler beim Speichern des Brandings';

  @override
  String get svcSaveDefaultFieldsFailed => 'Fehler beim Speichern der Standardfelder';

  @override
  String get svcSaveFailed => 'Fehler beim Speichern';

  @override
  String get svcSaveOrgFieldsFailed => 'Fehler beim Speichern der Organisations-Zusatzfelder';

  @override
  String get svcSavePlanTemplatesFailed => 'Fehler beim Speichern der Planvorlagen';

  @override
  String get svcSaveSharedFieldsFailed => 'Fehler beim Speichern der gemeinsamen Zusatzfelder';

  @override
  String get svcScores => 'Noten';

  @override
  String get svcSearchTargetPeopleFailed => 'Fehler beim Suchen der Personen in Ziel-Instanz';

  @override
  String get svcSendFeedbackFailed => 'Fehler beim Senden des Feedbacks';

  @override
  String get svcSendMessageFailed => 'Fehler beim Senden der Nachricht, versuche es später erneut!';

  @override
  String get svcSendQuestionFailed => 'Fehler beim Senden der Frage';

  @override
  String get svcShow => 'Anzeigen';

  @override
  String get svcSignUpFailed => 'Fehler beim Eintragen';

  @override
  String get svcSignedUrlFailed => 'Signed URL konnte nicht erzeugt werden.';

  @override
  String get svcTransferAbsencesFailed => 'Fehler beim Übertragen der Abwesenheiten';

  @override
  String get svcTransferPersonAttendancesFailed => 'Fehler beim Übertragen der Person-Anwesenheiten';

  @override
  String get svcUnassignFailed => 'Fehler beim Austragen';

  @override
  String get svcUpdateAttendanceFailed => 'Fehler beim updaten der Anwesenheit';

  @override
  String get svcUpdateCategoryFailed => 'Fehler beim Aktualisieren der Kategorie';

  @override
  String get svcUpdateCategoryOrderFailed => 'Fehler beim Aktualisieren der Kategoriereihenfolge';

  @override
  String get svcUpdateChurchFailed => 'Fehler beim Aktualisieren der Gemeinde';

  @override
  String get svcUpdateConfigFailed => 'Fehler beim Updaten der Konfiguration, bitte versuche es später erneut.';

  @override
  String get svcUpdateEntryFailed => 'Fehler beim Updaten des Eintrags';

  @override
  String get svcUpdateExtraFieldsFailed => 'Fehler beim updaten der Zusatzfelder';

  @override
  String get svcUpdateFieldFailed => 'Fehler beim updaten des Feldes';

  @override
  String get svcUpdateGroupFailed => 'Fehler beim updaten des Instruments';

  @override
  String get svcUpdateRolePermissionFailed => 'Fehler beim Aktualisieren der Rollenberechtigung';

  @override
  String get svcUpdateSettingsFailed => 'Fehler beim Aktualisieren der Einstellungen';

  @override
  String get svcUpdateShiftFailed => 'Fehler beim Aktualisieren der Schicht';

  @override
  String get svcUpdateTenantDataFailed => 'Fehler beim Aktualisieren der Mandantendaten';

  @override
  String get svcUpdateTenantUserFailed => 'Fehler beim Aktualisieren des Mandantenbenutzers';

  @override
  String get svcUpdateTypeFailed => 'Fehler beim Aktualisieren des Anwesenheitstyps';

  @override
  String get tabsDashboard => 'Dashboard';

  @override
  String get tabsEvents => 'Termine';

  @override
  String get tabsMembers => 'Mitglieder';

  @override
  String get tabsMore => 'Mehr';

  @override
  String get tabsMyEvents => 'Meine Termine';

  @override
  String get tabsOrg => 'Org';

  @override
  String get tabsOverview => 'Übersicht';

  @override
  String get tabsPeople => 'Personen';

  @override
  String get tabsSongs => 'Werke';

  @override
  String tasksAssignedTo(Object name) {
    return 'Zugewiesen an $name';
  }

  @override
  String get tasksAssignedToYou => 'Dir zugewiesen';

  @override
  String get tasksCreated => 'Aufgabe angelegt';

  @override
  String get tasksDeleteConfirm => 'Aufgabe löschen?';

  @override
  String get tasksDeleteFailed => 'Löschen fehlgeschlagen';

  @override
  String get tasksDeleteMessage => 'Die Aufgabe wird endgültig entfernt.';

  @override
  String get tasksDeleted => 'Aufgabe gelöscht';

  @override
  String get tasksDescription => 'Beschreibung';

  @override
  String get tasksDescriptionOptional => 'Beschreibung (optional)';

  @override
  String get tasksDetails => 'Details';

  @override
  String get tasksDone => 'Erledigt';

  @override
  String get tasksDoneThanks => 'Erledigt – danke!';

  @override
  String tasksDueLabel(Object label) {
    return 'Fällig $label';
  }

  @override
  String get tasksDueOn => 'Fällig am';

  @override
  String get tasksEnterTitle => 'Bitte einen Titel eingeben';

  @override
  String tasksEventFrom(Object type, Object date) {
    return '$type vom $date';
  }

  @override
  String get tasksFlutterAllTasks => 'Alle Aufgaben';

  @override
  String get tasksFlutterEditTask => 'Aufgabe bearbeiten';

  @override
  String get tasksFlutterNewTask => 'Neue Aufgabe';

  @override
  String get tasksFlutterNoDate => 'Kein Datum';

  @override
  String get tasksFlutterReopen => 'Wieder öffnen';

  @override
  String tasksFlutterShowAllCount(Object count) {
    return 'Alle anzeigen ($count)';
  }

  @override
  String get tasksInProgress => 'In Arbeit';

  @override
  String get tasksMarkDone => 'Als erledigt markieren';

  @override
  String get tasksMyTasks => 'Meine Aufgaben';

  @override
  String get tasksNoDue => 'Ohne Fälligkeit';

  @override
  String get tasksNoPersonFound => 'Keine Person gefunden';

  @override
  String get tasksNobody => 'Niemand';

  @override
  String get tasksNotAssigned => 'Noch niemandem zugewiesen';

  @override
  String get tasksNotAvailable => 'Diese Aufgabe gibt es nicht mehr oder du kannst sie nicht sehen.';

  @override
  String tasksNotify(Object name) {
    return '$name benachrichtigen';
  }

  @override
  String get tasksNotifyHint => 'Sofort per Push oder Telegram';

  @override
  String tasksOpenCount(Object count) {
    return '$count offen';
  }

  @override
  String get tasksOrigin => 'Herkunft';

  @override
  String tasksOverdueCount(Object count) {
    return '$count überfällig';
  }

  @override
  String tasksOverdueLabel(Object label) {
    return 'Überfällig $label';
  }

  @override
  String get tasksOverdueSuffix => '· überfällig';

  @override
  String get tasksPerson => 'Person';

  @override
  String get tasksPriority => 'Priorität';

  @override
  String get tasksProtocol => 'Protokoll';

  @override
  String get tasksReminderOther => 'Die verantwortliche Person bekommt 2 Tage vor Fälligkeit eine Erinnerung und noch eine, falls die Aufgabe überfällig wird.';

  @override
  String get tasksReminderSelf => 'Du bekommst 2 Tage vor Fälligkeit eine Erinnerung und noch eine, falls die Aufgabe überfällig wird.';

  @override
  String get tasksResponsible => 'Verantwortlich';

  @override
  String get tasksSaveFailed => 'Aufgabe konnte nicht gespeichert werden';

  @override
  String get tasksSaved => 'Gespeichert';

  @override
  String get tasksSearchPerson => 'Person suchen';

  @override
  String get tasksStatusCompleted => 'Erledigt';

  @override
  String get tasksStatusFailed => 'Status konnte nicht geändert werden';

  @override
  String get tasksStatusInProgress => 'In Arbeit';

  @override
  String get tasksStatusOpen => 'Offen';

  @override
  String get tasksTask => 'Aufgabe';

  @override
  String get tasksTitle => 'Titel';

  @override
  String get tasksTopic => 'Thema';

  @override
  String get tasksWhatToDo => 'Was ist zu tun?';

  @override
  String get tasksWhoWhen => 'Wer & bis wann';

  @override
  String get teachersAdd => 'Lehrer hinzufügen';

  @override
  String get teachersContact => 'Kontakt';

  @override
  String get teachersEdit => 'Lehrer bearbeiten';

  @override
  String get teachersFillAll => 'Bitte fülle alle Felder aus...';

  @override
  String get teachersFlutterDelete => 'Lehrer löschen';

  @override
  String teachersFlutterDeleteConfirm(Object name) {
    return 'Möchtest du \"$name\" wirklich löschen?';
  }

  @override
  String get teachersFlutterDeleted => 'Lehrer gelöscht';

  @override
  String get teachersFlutterLoadFailed => 'Lehrer konnten nicht geladen werden';

  @override
  String get teachersInstruments => 'Instrumente';

  @override
  String teachersPlayerCount(num count) {
    return '$count Spieler';
  }

  @override
  String get teachersPlayers => 'Spieler';

  @override
  String get teachersPrivate => 'Privatlehrer';

  @override
  String get teachersTitle => 'Lehrer';

  @override
  String get teachersUpdate => 'Lehrer updaten';

  @override
  String get teachersUpdated => 'Lehrer erfolgreich geupdated!';

  @override
  String get teamOrgAcceptSuggestion => 'Vorschlag übernehmen';

  @override
  String get teamOrgAcceptedByLeaders => 'Von der Leitung übernommen';

  @override
  String get teamOrgAddTopics => 'Themen aufnehmen';

  @override
  String teamOrgAllCount(Object count) {
    return 'Alle · $count';
  }

  @override
  String get teamOrgAllDecided => 'Alle Vorschläge sind entschieden.';

  @override
  String get teamOrgChange => 'Ändern';

  @override
  String get teamOrgChangeDate => 'Datum dieses Termins ändern';

  @override
  String get teamOrgChosenEvent => 'Gewählter Termin';

  @override
  String get teamOrgCreateEvent => 'Termin anlegen';

  @override
  String get teamOrgCreateTask => 'Aufgabe anlegen';

  @override
  String get teamOrgCreateTopic => 'Thema anlegen';

  @override
  String teamOrgDaysAgo(Object count) {
    return 'vor $count Tagen';
  }

  @override
  String get teamOrgDecisionFailed => 'Entscheidung konnte nicht gespeichert werden';

  @override
  String get teamOrgDescPlaceholder => 'Worum geht es? (optional)';

  @override
  String get teamOrgDoneDisappear => 'Erledigte Aufgaben verschwinden nach 30 Tagen aus der Liste.';

  @override
  String get teamOrgDraft => 'Entwurf';

  @override
  String teamOrgEditedOn(Object text, Object date) {
    return '$text · geändert am $date';
  }

  @override
  String get teamOrgEmptyAll => 'Noch keine Aufgaben. Leg die erste mit + an oder direkt aus einem Protokoll.';

  @override
  String get teamOrgEmptyMine => 'Du hast keine Aufgaben. Alles erledigt!';

  @override
  String get teamOrgEmptyMineAssigned => 'Dir sind gerade keine Aufgaben zugewiesen. Genieß die Ruhe!';

  @override
  String get teamOrgEmptyPerson => 'Hier ist nichts offen.';

  @override
  String get teamOrgFilter => 'Filter';

  @override
  String get teamOrgFlutterAnd => 'und';

  @override
  String teamOrgFlutterCreateType(Object name) {
    return '$name anlegen';
  }

  @override
  String get teamOrgFlutterMember => 'Mitglied';

  @override
  String teamOrgFlutterNewSuggestions(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Vorschläge',
      one: '$count neuer Vorschlag',
    );
    return '$_temp0';
  }

  @override
  String get teamOrgGroupNone => 'Ohne Datum';

  @override
  String get teamOrgGroupOverdue => 'Überfällig';

  @override
  String get teamOrgGroupWeek => 'Diese Woche';

  @override
  String get teamOrgLeadersPlan => 'Themen und Tagesordnungen plant die Leitung. Du gehörst zu keiner Gruppe mit Protokoll & Tagesordnung.';

  @override
  String teamOrgMineCount(Object count) {
    return 'Meine · $count';
  }

  @override
  String teamOrgMinutes(Object min) {
    return '$min min';
  }

  @override
  String get teamOrgMySuggestions => 'Meine Vorschläge';

  @override
  String get teamOrgNextEvent => 'Nächster Termin';

  @override
  String get teamOrgNoHits => 'Keine Treffer';

  @override
  String get teamOrgNoOpenTopics => 'Keine offenen Themen. Lege mit + ein neues an.';

  @override
  String get teamOrgNoProtocolEvent => 'Kein Termin mit Protokoll & Tagesordnung geplant.';

  @override
  String teamOrgNoProtocolMatch(Object search) {
    return 'Kein Protokoll passt zu „$search“.';
  }

  @override
  String get teamOrgNoProtocols => 'Noch keine Protokolle';

  @override
  String get teamOrgNoProtocolsHint => 'Ein Protokoll schreibst du direkt im Termin: Öffne den Termin und tippe auf „Protokoll“.';

  @override
  String get teamOrgNoPublished => 'Noch keine Protokolle freigegeben';

  @override
  String get teamOrgNoPublishedHint => 'Sobald die Leitung ein Protokoll freigibt, findest du es hier.';

  @override
  String get teamOrgNoTopsYet => 'Noch keine Themen auf der Tagesordnung.';

  @override
  String get teamOrgNobodyAssigned => 'Niemand zugewiesen';

  @override
  String get teamOrgNobodyResponsible => 'Noch niemand verantwortlich';

  @override
  String get teamOrgNothingSuggested => 'Du hast noch nichts vorgeschlagen.';

  @override
  String teamOrgOpenCount(Object count) {
    return '$count offen';
  }

  @override
  String get teamOrgOpenTopic => 'Thema öffnen';

  @override
  String get teamOrgOutcomeDecided => 'Beschlossen';

  @override
  String get teamOrgOutcomeDiscussed => 'Besprochen';

  @override
  String teamOrgPersonInformed(Object name) {
    return '$name wird informiert. Eine kurze Begründung hilft.';
  }

  @override
  String get teamOrgPlanForWhich => 'Für welchen Termin planen?';

  @override
  String get teamOrgPlannedLower => 'eingeplant';

  @override
  String get teamOrgPostponedLower => 'vertagt';

  @override
  String get teamOrgProposal => 'Vorschlag';

  @override
  String get teamOrgPublished => 'Freigegeben';

  @override
  String teamOrgPublishedOn(Object date) {
    return 'Freigegeben am $date';
  }

  @override
  String get teamOrgReasonOptional => 'Begründung (optional)';

  @override
  String get teamOrgReject => 'Ablehnen';

  @override
  String get teamOrgRejectSuggestion => 'Vorschlag ablehnen';

  @override
  String get teamOrgRemoveFailed => 'Thema konnte nicht entfernt werden';

  @override
  String get teamOrgRemoveFromEvent => 'Aus diesem Termin entfernen';

  @override
  String get teamOrgRemovedStays => 'Aus dem Termin entfernt, bleibt im Themenspeicher';

  @override
  String get teamOrgReview => 'Prüfen';

  @override
  String get teamOrgSearchProtocols => 'Termin oder Datum suchen';

  @override
  String get teamOrgSendSuggestion => 'Vorschlag senden';

  @override
  String teamOrgShowDone(Object count) {
    return 'Erledigte anzeigen ($count)';
  }

  @override
  String get teamOrgShowOlderDone => 'Ältere erledigte anzeigen';

  @override
  String teamOrgSince(Object date) {
    return 'seit $date';
  }

  @override
  String get teamOrgSubmittedByMembers => 'Von Mitgliedern eingereicht';

  @override
  String teamOrgSubmittedOn(Object date) {
    return 'Eingereicht am $date';
  }

  @override
  String get teamOrgSuggestHint => 'Du hast ein Anliegen für die nächste Sitzung? Die Leitung entscheidet, ob es auf die Tagesordnung kommt.';

  @override
  String get teamOrgSuggestTopic => 'Thema vorschlagen';

  @override
  String get teamOrgSuggestionAccepted => 'Übernommen';

  @override
  String get teamOrgSuggestionFailed => 'Vorschlag konnte nicht gesendet werden';

  @override
  String get teamOrgSuggestionRejected => 'Abgelehnt';

  @override
  String get teamOrgSuggestionSent => 'Vorschlag gesendet';

  @override
  String get teamOrgSuggestionWaiting => 'Wartet';

  @override
  String get teamOrgSuggestions => 'Vorschläge';

  @override
  String get teamOrgSuggestionsHint => 'Übernommene Vorschläge landen im Themenspeicher. Wer vorgeschlagen hat, wird über deine Entscheidung informiert.';

  @override
  String get teamOrgTabProtocols => 'Protokolle';

  @override
  String get teamOrgTabTasks => 'Aufgaben';

  @override
  String get teamOrgTabTopics => 'Themen';

  @override
  String get teamOrgTasksLoadFailed => 'Aufgaben konnten nicht geladen werden';

  @override
  String get teamOrgThePerson => 'Die Person';

  @override
  String get teamOrgTitle => 'Teamorganisation';

  @override
  String get teamOrgTitlePlaceholder => 'z. B. Neue Notenpulte';

  @override
  String get teamOrgToday => 'heute';

  @override
  String get teamOrgTodayCap => 'Heute';

  @override
  String get teamOrgTomorrow => 'Morgen';

  @override
  String teamOrgTopName(Object n, Object name) {
    return 'TOP $n · $name';
  }

  @override
  String get teamOrgWhichPriority => 'Mit welcher Priorität kommt das Thema in den Themenspeicher?';

  @override
  String get teamOrgYesterday => 'gestern';

  @override
  String get teamsChoose => 'Wähle aus, welche Attendix-Instanz in diesem Kanal angezeigt werden soll.';

  @override
  String get teamsNoAccount => 'Kein Attendix-Konto gefunden. Bitte melde dich zuerst im Attendix-Tab an.';

  @override
  String get teamsOnlyInTeams => 'Diese Seite wird nur innerhalb von Microsoft Teams verwendet.';

  @override
  String get teamsSaveFailed => 'Konfiguration konnte nicht gespeichert werden';

  @override
  String get teamsSetup => 'Attendix-Tab einrichten';

  @override
  String get tenantRegisterAcceptTerms => 'Nutzungsbedingungen und Datenschutzerklärung akzeptieren';

  @override
  String get tenantRegisterAcceptTermsToast => 'Bitte akzeptiere die Nutzungsbedingungen und Datenschutzerklärung.';

  @override
  String get tenantRegisterAccount => 'Account';

  @override
  String get tenantRegisterAlreadyRegistered => 'Sie sind bereits in dieser Instanz registriert.';

  @override
  String get tenantRegisterBirthDate => 'Geburtsdatum';

  @override
  String get tenantRegisterBirthDateRequired => 'Bitte geben Sie ein gültiges Geburtsdatum an.';

  @override
  String get tenantRegisterChoosePicture => 'Wähle ein Passbild aus (max. 15 MB)';

  @override
  String get tenantRegisterChurchNamePlaceholder => 'Name deiner Gemeinde';

  @override
  String get tenantRegisterChurchNameRequired => 'Bitte geben Sie den Namen Ihrer Gemeinde ein.';

  @override
  String get tenantRegisterChurchNotListed => 'Gemeinde nicht gelistet? Bitte Namen eingeben';

  @override
  String get tenantRegisterChurchRequired => 'Bitte wählen Sie eine Gemeinde aus.';

  @override
  String get tenantRegisterConfirmCode => 'Code bestätigen';

  @override
  String get tenantRegisterEmailAddress => 'E-Mail Adresse';

  @override
  String tenantRegisterFailed(Object error) {
    return 'Fehler bei der Registrierung: $error';
  }

  @override
  String tenantRegisterFieldAccept(Object field) {
    return 'Sie müssen dem Feld \"$field\" zustimmen, um fortzufahren.';
  }

  @override
  String tenantRegisterFieldDate(Object field) {
    return 'Bitte geben Sie ein gültiges Datum für das Feld \"$field\" ein.';
  }

  @override
  String tenantRegisterFieldNumber(Object field) {
    return 'Bitte geben Sie eine gültige Zahl für das Feld \"$field\" ein.';
  }

  @override
  String tenantRegisterFieldRequired(Object field) {
    return 'Bitte füllen Sie das Feld \"$field\" aus.';
  }

  @override
  String tenantRegisterFieldValue(Object field) {
    return 'Bitte geben Sie einen gültigen Wert für das Feld \"$field\" ein.';
  }

  @override
  String get tenantRegisterFinish => 'Registrierung abschließen';

  @override
  String get tenantRegisterFirstName => 'Vorname';

  @override
  String get tenantRegisterFlutterCreateChurchFailed => 'Fehler beim Erstellen der Gemeinde.';

  @override
  String get tenantRegisterFlutterGroupRequired => 'Gruppe ist erforderlich';

  @override
  String get tenantRegisterFlutterInvalidLink => 'Ungültiger Registrierungslink.';

  @override
  String get tenantRegisterFlutterLoadChurchesFailed => 'Fehler beim Laden der Gemeinden';

  @override
  String tenantRegisterFlutterLoadError(Object error) {
    return 'Fehler beim Laden: $error';
  }

  @override
  String get tenantRegisterFlutterLoadGroupsFailed => 'Fehler beim Laden der Gruppen';

  @override
  String get tenantRegisterFlutterMaxSize => 'Max. 15 MB';

  @override
  String get tenantRegisterFlutterMinFiveChars => 'Mindestens 5 Zeichen';

  @override
  String get tenantRegisterFlutterRegisterFailedRetry => 'Fehler beim Registrieren. Bitte versuche es erneut.';

  @override
  String get tenantRegisterFlutterRegistrationAt => 'Registrierung bei';

  @override
  String get tenantRegisterFlutterSignInExisting => 'Melde dich mit deinem bestehenden Account an.';

  @override
  String get tenantRegisterFlutterTermsAccept => ' akzeptieren';

  @override
  String get tenantRegisterFlutterTermsLink => 'Nutzungsbedingungen und Datenschutzerklärung';

  @override
  String get tenantRegisterFlutterToLogin => 'Zur Anmeldung';

  @override
  String get tenantRegisterHaveAccount => 'Account bereits vorhanden? Hier klicken';

  @override
  String get tenantRegisterIntro => 'Registriere dich über dieses Formular für die oben genannte Instanz.';

  @override
  String get tenantRegisterInvalidLink => 'Ungültiger Freigabe-Link.';

  @override
  String get tenantRegisterLastName => 'Nachname';

  @override
  String get tenantRegisterMoreInfo => 'Weitere Informationen';

  @override
  String get tenantRegisterNameRequired => 'Bitte geben Sie Ihren Vor- und Nachnamen an.';

  @override
  String get tenantRegisterNoChurchFound => 'Keine Gemeinde gefunden.';

  @override
  String get tenantRegisterNoGroups => 'Registrierung aktuell nicht möglich: Der Administrator hat noch keine Gruppen angelegt. Bitte versuche es später erneut.';

  @override
  String get tenantRegisterNoGroupsToast => 'Registrierung nicht möglich: Es sind keine Gruppen verfügbar.';

  @override
  String get tenantRegisterNotListed => 'Nicht gelistet';

  @override
  String get tenantRegisterNotes => 'Bemerkungen (optional)';

  @override
  String get tenantRegisterPasswordMismatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String get tenantRegisterPasswordTooShort => 'Das Passwort muss mindestens 6 Zeichen lang sein.';

  @override
  String get tenantRegisterPersonalData => 'Persönliche Daten';

  @override
  String get tenantRegisterPhone => 'Handynummer';

  @override
  String get tenantRegisterPhoneRequired => 'Bitte geben Sie eine gültige Telefonnummer an.';

  @override
  String get tenantRegisterPictureFailed => 'Fehler beim ändern des Passbildes, versuche es später erneut';

  @override
  String get tenantRegisterPictureRequired => 'Bitte wählen Sie ein Passbild aus.';

  @override
  String get tenantRegisterPictureTooLarge => 'Das ausgewählte Bild ist zu groß. Bitte wähle ein Bild unter 15 MB.';

  @override
  String get tenantRegisterPleaseChoose => 'Bitte auswählen';

  @override
  String get tenantRegisterReplacePicture => 'Passbild ersetzen';

  @override
  String get tenantRegisterSearchChurch => 'Gemeinde suchen';

  @override
  String tenantRegisterSignedInAs(Object email) {
    return 'Du bist angemeldet als $email.';
  }

  @override
  String get tenantRegisterSuccessHeader => 'Registrierung erfolgreich';

  @override
  String get tenantRegisterSuccessJoined => 'Deine Registrierung war erfolgreich! Du bist nun teil der Instanz.';

  @override
  String get tenantRegisterSuccessNewConfirm => 'Dein Konto wurde erstellt. Um dich anmelden zu können, bestätige bitte deine E-Mail. Falls keine E-Mail ankommt, überprüfe bitte deinen Spam-Ordner. Im Anschluss kannst du dich anmelden.';

  @override
  String get tenantRegisterSuccessNewPending => 'Dein Konto wurde erstellt und wartet auf die Genehmigung durch einen Administrator. Bitte bestätige deine E-Mail, um dich anmelden zu können. Falls keine E-Mail ankommt, überprüfe bitte deinen Spam-Ordner.';

  @override
  String get tenantRegisterSuccessPending => 'Deine Registrierung war erfolgreich! Bitte warte auf die Genehmigung durch einen Administrator.';

  @override
  String get tenantRegisterTitle => 'Registrierung';

  @override
  String get tenantSelectFlutterCreatedAt => 'Erstellt am';

  @override
  String get tenantSelectFlutterDangerZone => 'Gefahrenzone';

  @override
  String get tenantSelectFlutterDeleteAllData => 'Alle Daten dieser Instanz werden unwiderruflich gelöscht.';

  @override
  String get tenantSelectFlutterDeleteTenant => 'Instanz löschen';

  @override
  String get tenantSelectFlutterDeleteTenantHint => 'Diese Gruppe unwiderruflich löschen';

  @override
  String get tenantSelectFlutterDeleted => 'Instanz gelöscht';

  @override
  String get tenantSelectFlutterDetailsLoadFailed => 'Fehler beim Laden der Instanz-Details';

  @override
  String get tenantSelectFlutterDetailsTitle => 'Instanz-Details';

  @override
  String get tenantSelectFlutterEmptyText => 'Du bist noch keiner Instanz zugeordnet. Bitte wende dich an einen Administrator oder lege eine neue Instanz an.';

  @override
  String get tenantSelectFlutterEmptyTitle => 'Keine Instanzen';

  @override
  String get tenantSelectFlutterEnterNameToConfirm => 'Bitte gib den Namen der Instanz ein, um das Löschen zu bestätigen:';

  @override
  String get tenantSelectFlutterInfo => 'Informationen';

  @override
  String get tenantSelectFlutterLoadFailed => 'Fehler beim Laden';

  @override
  String get tenantSelectFlutterNewTenant => 'Neue Instanz';

  @override
  String get tenantSelectFlutterNoRole => 'Keine Rolle';

  @override
  String get tenantSelectFlutterNotFound => 'Instanz nicht gefunden';

  @override
  String get tenantSelectFlutterRegion => 'Region';

  @override
  String get tenantSelectFlutterTenantSelection => 'Instanzauswahl';

  @override
  String get tenantSelectFlutterYourRole => 'Deine Rolle';

  @override
  String get termsAcceptAfter => 'gelesen.';

  @override
  String get termsAcceptAria => 'Nutzungsbedingungen und Datenschutzerklärung akzeptieren';

  @override
  String get termsAcceptBefore => 'Ich akzeptiere die Nutzungsbedingungen und habe die';

  @override
  String get termsAcceptContinue => 'Akzeptieren und fortfahren';

  @override
  String get termsBeforeStart => 'Kurz bevor es losgeht';

  @override
  String get termsIntro => 'Um Attendix nutzen zu können, benötigen wir einmalig deine Zustimmung zu unseren Nutzungsbedingungen und der Datenschutzerklärung.';

  @override
  String get termsPleaseAccept => 'Bitte akzeptiere die Nutzungsbedingungen und Datenschutzerklärung.';

  @override
  String get termsPrivacy => 'Datenschutzerklärung';

  @override
  String get termsRead => 'Datenschutzerklärung & Impressum lesen';

  @override
  String get termsSafe => 'Deine Daten sind sicher';

  @override
  String get termsSafeText => 'Wir speichern nur die Daten, die für den Betrieb der App notwendig sind, und geben sie nicht an Dritte weiter.';

  @override
  String get termsSaveFailed => 'Fehler beim Speichern. Bitte versuche es erneut.';

  @override
  String get termsSessionExpired => 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';

  @override
  String get termsTitle => 'Datenschutz & Nutzung';

  @override
  String get termsUsage => 'Wofür werden deine Daten genutzt?';

  @override
  String get termsUsageText => 'Ausschließlich zur Verwaltung deiner Anwesenheit und zur Kommunikation innerhalb deiner Gruppe oder deines Chores.';

  @override
  String get typeSettingsActive => 'Aktiv';

  @override
  String get typeSettingsActiveHelper => 'Wenn du diese Option deaktivierst, wird der Anwesenheitstyp beim Anlegen einer Anwesenheit nicht mehr als Option angezeigt.';

  @override
  String get typeSettingsActiveReminders => 'Aktive Erinnerungen';

  @override
  String get typeSettingsAddField => 'Feld hinzufügen';

  @override
  String get typeSettingsAddNoteField => 'Notizfeld hinzufügen';

  @override
  String get typeSettingsAddReminder => 'Erinnerung hinzufügen';

  @override
  String get typeSettingsAddTodo => 'To-Do hinzufügen';

  @override
  String get typeSettingsAfter1Day => 'nach 1 Tag';

  @override
  String get typeSettingsAfter2Days => 'nach 2 Tagen';

  @override
  String get typeSettingsAfter3Days => 'nach 3 Tagen';

  @override
  String get typeSettingsAfter7Days => 'nach 7 Tagen';

  @override
  String get typeSettingsAgenda => 'Tagesordnung';

  @override
  String get typeSettingsAgendaExists => 'Ein Tagesordnungs-Platzhalter ist bereits vorhanden';

  @override
  String get typeSettingsAgendaPlaceholder => 'Tagesordnung Platzhalter';

  @override
  String get typeSettingsAllDay => 'Ganztägig';

  @override
  String get typeSettingsAllDayHelper => 'Wenn du diese Option aktivierst, wird bei einer Anwesenheit von diesem Typ keine Uhrzeit festgelegt aber eine Dauer angegeben.';

  @override
  String get typeSettingsAppearance => 'Darstellung';

  @override
  String get typeSettingsAttendanceTypes => 'Anwesenheitstypen';

  @override
  String get typeSettingsAvailableStatus => 'Verfügbare Anwesenheitsstatus';

  @override
  String get typeSettingsChecklist => 'Checkliste';

  @override
  String get typeSettingsChecklistHelper => 'Aktiviere die Checkliste, um To-Dos für diesen Anwesenheitstyp zu definieren. Diese werden automatisch bei neuen Terminen übernommen.';

  @override
  String get typeSettingsCircleHint => 'Den Personenkreis legst du wie gewohnt über relevante Gruppen oder unter „Filter“ mit einem Zusatzfeld fest (z. B. Ja/Nein-Feld „Tontechnik“). Dienste zählen in die Anwesenheitsquote, aber nur für eingeteilte Personen.';

  @override
  String get typeSettingsColor => 'Farbe';

  @override
  String get typeSettingsColorHint => 'Die Farbe ist nur für den Kalender relevant (beim Anlegen einer Anwesenheit).';

  @override
  String get typeSettingsConfigureReminders => 'Erinnerungen konfigurieren';

  @override
  String get typeSettingsCountForAvg => 'Für Ø berücksichtigen';

  @override
  String get typeSettingsCountForAvgHelper => 'Wenn diese Option aktiviert ist, wird dieser Typ beim Anwesenheitsdurchschnitt berücksichtigt.';

  @override
  String get typeSettingsCreateFailed => 'Fehler beim Erstellen des Anwesenheitstyps';

  @override
  String get typeSettingsCreated => 'Anwesenheitstyp erfolgreich erstellt';

  @override
  String get typeSettingsCustom => 'Benutzerdefiniert';

  @override
  String get typeSettingsCustomDots => 'Benutzerdefiniert...';

  @override
  String typeSettingsDaysBeforeN(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage vorher',
      one: '$count Tag vorher',
    );
    return '$_temp0';
  }

  @override
  String get typeSettingsDeadline => 'Deadline';

  @override
  String get typeSettingsDefaultDays => 'Standarddauer (in Tagen)';

  @override
  String get typeSettingsDefaultStatus => 'Standard Anwesenheitsstatus';

  @override
  String get typeSettingsDeleteFailed => 'Fehler beim Löschen des Anwesenheitstyps';

  @override
  String get typeSettingsDeleteType => 'Anwesenheitstyp löschen';

  @override
  String typeSettingsDeleteTypeMessage(Object name) {
    return 'Möchtest du den Anwesenheitstyp „$name“ wirklich löschen? Alle Anwesenheiten dieses Typs werden ebenfalls gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get typeSettingsDeleted => 'Anwesenheitstyp erfolgreich gelöscht';

  @override
  String get typeSettingsDiscardChanges => 'Änderungen verwerfen?';

  @override
  String get typeSettingsDiscardMessage => 'Du hast bereits Daten eingegeben. Möchtest du diese wirklich verwerfen?';

  @override
  String get typeSettingsDutyHelper => 'Für Dienste wie Tontechnik: Pro Termin wird eine feste Zahl Personen eingeteilt. Nur Eingeteilte sind erwartet, alle anderen aus dem Personenkreis sind Springer.';

  @override
  String get typeSettingsDutyMode => 'Dienst-Modus';

  @override
  String get typeSettingsDutyRoster => 'Dienstplan';

  @override
  String get typeSettingsDutyViewActive => 'Dienstplan-Ansicht ist aktiv';

  @override
  String get typeSettingsEditField => 'Feld bearbeiten';

  @override
  String get typeSettingsEditTodo => 'To-Do bearbeiten';

  @override
  String get typeSettingsEnableChecklist => 'Checkliste aktivieren';

  @override
  String get typeSettingsEnableLocation => 'Ort / Navigation aktivieren';

  @override
  String get typeSettingsEnd => 'Ende';

  @override
  String get typeSettingsEnterFieldLabel => 'Bitte eine Feldbezeichnung eingeben';

  @override
  String get typeSettingsEnterItem => 'Bitte einen Programmpunkt eingeben.';

  @override
  String get typeSettingsEnterName => 'Bitte einen Namen für den Anwesenheitstyp eingeben.';

  @override
  String get typeSettingsEnterTodo => 'Bitte einen Text für das To-Do eingeben';

  @override
  String get typeSettingsEventReminder => 'Terminerinnerung';

  @override
  String get typeSettingsEventReminderHelper => 'Wenn diese Option aktiviert ist, Erinnerungen angelegt wurden und die Benachrichtigungen aktiviert sind, erhalten Personen eine Terminerinnerung.';

  @override
  String get typeSettingsEventReminders => 'Terminerinnerungen';

  @override
  String get typeSettingsExtraFilter => 'Zusatzfeld-Filter';

  @override
  String get typeSettingsExtraFilterHelper => 'Nur Personen mit dem ausgewählten Zusatzfeld-Wert werden beim Anlegen einer Anwesenheit von diesem Typ berücksichtigt.';

  @override
  String get typeSettingsFieldLabel => 'Feldbezeichnung';

  @override
  String get typeSettingsFieldLabelPh => 'z.B. Instrument mitbringen?';

  @override
  String get typeSettingsFilter => 'Filter';

  @override
  String get typeSettingsFlutterAllGroupsHint => 'Leer = gilt für alle Gruppen';

  @override
  String get typeSettingsFlutterCreateType => 'Typ erstellen';

  @override
  String typeSettingsFlutterCreatedNamed(Object name) {
    return 'Anwesenheitstyp \"$name\" erstellt';
  }

  @override
  String get typeSettingsFlutterDeadlineLabel => 'Frist (Stunden vorher, optional)';

  @override
  String get typeSettingsFlutterDeadlinePh => 'z.B. 24 für 1 Tag';

  @override
  String get typeSettingsFlutterDurationMinutes => 'Dauer (Minuten)';

  @override
  String get typeSettingsFlutterDurationPh => 'z.B. 10';

  @override
  String get typeSettingsFlutterExtraField => 'Zusatzfeld';

  @override
  String get typeSettingsFlutterExtraFilterHint => 'Nur Spieler mit diesem Zusatzfeld-Wert einbeziehen';

  @override
  String get typeSettingsFlutterFieldNamePh => 'z.B. Einspielen, Pause';

  @override
  String get typeSettingsFlutterHidden => 'Ausgeblendet';

  @override
  String typeSettingsFlutterMinutes(Object minutes) {
    return '$minutes Min.';
  }

  @override
  String get typeSettingsFlutterNamePh => 'z.B. Probe, Konzert, Generalprobe';

  @override
  String get typeSettingsFlutterNamePhShort => 'z.B. Probe, Konzert';

  @override
  String get typeSettingsFlutterNewField => 'Neues Feld';

  @override
  String get typeSettingsFlutterNewType => 'Neuer Anwesenheitstyp';

  @override
  String get typeSettingsFlutterNoTypes => 'Keine Anwesenheitstypen vorhanden';

  @override
  String get typeSettingsFlutterNotFound => 'Typ nicht gefunden';

  @override
  String get typeSettingsFlutterPlanHeadingPh => 'z.B. Probenplan';

  @override
  String get typeSettingsFlutterReorder => 'Reihenfolge ändern';

  @override
  String get typeSettingsFlutterSaveOrderFailed => 'Fehler beim Speichern. Bitte erneut versuchen.';

  @override
  String get typeSettingsFlutterTodoPh => 'z.B. Noten vorbereiten';

  @override
  String typeSettingsFlutterTotalMinutes(Object minutes) {
    return 'Gesamt: $minutes Min.';
  }

  @override
  String get typeSettingsFlutterTypeTitle => 'Anwesenheitstyp';

  @override
  String typeSettingsFlutterUsageWarning(Object count) {
    return 'Wird in $count Termin(en) verwendet. Änderungen wirken sich auf bestehende Einträge aus.';
  }

  @override
  String get typeSettingsFlutterWithProgramme => 'Mit Programm';

  @override
  String get typeSettingsFreeTextPh => 'Freitext eingeben...';

  @override
  String get typeSettingsH12 => '12 h vorher';

  @override
  String get typeSettingsH24 => '24 h vorher';

  @override
  String get typeSettingsH48 => '48 h vorher';

  @override
  String get typeSettingsH6 => '6 h vorher';

  @override
  String get typeSettingsH72 => '72 h vorher';

  @override
  String get typeSettingsHideName => 'Name verbergen';

  @override
  String get typeSettingsHideNameHelper => 'Wenn du diese Option aktivierst, wird der Name dieses Anwesenheitstyps in der Liste verborgen. Nur die Zusatzinfo (falls vorhanden) wird angezeigt.';

  @override
  String get typeSettingsHighlight => 'Hervorheben';

  @override
  String get typeSettingsHighlightHelper => 'Wenn du diese Option aktivierst, wird dieser Anwesenheitstyp in der Liste als Fett dargestellt.';

  @override
  String get typeSettingsHoursBefore => 'Stunden vor Termin';

  @override
  String typeSettingsHoursBeforeN(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden vorher',
      one: '$count Stunde vorher',
    );
    return '$_temp0';
  }

  @override
  String typeSettingsHoursBeforeStart(Object count) {
    return '$count Stunde(n) vor Terminbeginn';
  }

  @override
  String get typeSettingsHoursPlaceholder => 'z.B. 12 für 12 Stunden vorher';

  @override
  String get typeSettingsHowEvery5 => 'Erinnerungen werden <strong>alle 5 Minuten</strong> geprüft und versendet.';

  @override
  String get typeSettingsHowMax => 'Maximal <strong>3 Erinnerungen</strong> pro Termintyp möglich.';

  @override
  String get typeSettingsHowRemaining => 'Die Erinnerung wird versendet, sobald die <strong>verbleibende Zeit</strong> dem konfigurierten Wert entspricht.';

  @override
  String get typeSettingsHowReminders => 'So funktionieren Erinnerungen';

  @override
  String get typeSettingsInfo => 'Info';

  @override
  String get typeSettingsInfoOptional => 'Info-Text (optional)';

  @override
  String get typeSettingsInfoOptionalDots => 'Info-Text (optional)...';

  @override
  String get typeSettingsInsertPlaceholder => 'Platzhalter einfügen';

  @override
  String get typeSettingsLearnMore => 'Mehr erfahren';

  @override
  String get typeSettingsLocationHelper => 'Wenn aktiviert, kann bei Terminen dieses Typs ein Ort hinterlegt werden. Dieser wird dann als Navigationslink in Google Maps oder Apple Karten angezeigt.';

  @override
  String get typeSettingsManageSongs => 'Werke verwalten';

  @override
  String get typeSettingsMax3 => 'Maximal 3 Erinnerungen pro Typ möglich';

  @override
  String get typeSettingsMaxReached => 'Maximum von 3 Erinnerungen erreicht. Entferne eine bestehende Erinnerung, um eine neue hinzuzufügen.';

  @override
  String get typeSettingsMinPh => 'min';

  @override
  String get typeSettingsMulti => 'Mehrfachauswahl';

  @override
  String get typeSettingsName => 'Name';

  @override
  String get typeSettingsNeededPeople => 'Benötigte Personen';

  @override
  String get typeSettingsNewTodo => 'Neues To-Do';

  @override
  String get typeSettingsNoDeadline => 'Keine Deadline';

  @override
  String get typeSettingsNoFilter => 'Kein Filter';

  @override
  String get typeSettingsNoReminders => 'Keine Erinnerungen konfiguriert';

  @override
  String get typeSettingsNoRemindersYet => 'Noch keine Erinnerungen konfiguriert';

  @override
  String get typeSettingsNoSignupFields => 'Keine Anmeldefelder konfiguriert';

  @override
  String get typeSettingsNoTodos => 'Noch keine To-Dos angelegt';

  @override
  String get typeSettingsNormalView => 'Nein, normale Ansicht';

  @override
  String get typeSettingsNote => 'Notiz';

  @override
  String get typeSettingsNotePh => 'Notiz eingeben...';

  @override
  String get typeSettingsNotifyGroup => 'Gruppe bei Ausfall benachrichtigen';

  @override
  String get typeSettingsNotifyGroupHelper => 'Sagt eine eingeteilte Person ab und der Dienst ist unterbesetzt, bekommen alle aus dem Personenkreis eine Nachricht.';

  @override
  String get typeSettingsOff => 'Aus';

  @override
  String get typeSettingsOption => 'Option';

  @override
  String get typeSettingsOptions => 'Optionen';

  @override
  String get typeSettingsOptionsComma => 'Optionen (kommagetrennt)';

  @override
  String get typeSettingsOptionsPh => 'Option A, Option B, Option C';

  @override
  String get typeSettingsOrderSaved => 'Reihenfolge gespeichert';

  @override
  String get typeSettingsOrgPlanDefault => 'Ablaufplan ist standardmäßig ein Organisationsplan';

  @override
  String get typeSettingsPerformer => 'Ausführender';

  @override
  String get typeSettingsPerformerPh => 'Ausführenden eingeben...';

  @override
  String get typeSettingsPlaceholderHint => 'Der Platzhalter „Tagesordnung“ im Standard-Ablaufplan legt fest, wo Themen eingefügt werden. Ohne Platzhalter landen sie am Ende.';

  @override
  String get typeSettingsPlanHeading => 'Ablaufplan Überschrift';

  @override
  String get typeSettingsPositiveInt => 'Bitte geben Sie eine positive Ganzzahl ein';

  @override
  String get typeSettingsPostponedHelper => 'Beim nächsten Termin dieses Typs stehen vertagte Themen beim Aufnehmen ganz oben.';

  @override
  String get typeSettingsProgrammeItem => 'Programmpunkt';

  @override
  String get typeSettingsProgrammeItemPh => 'Programmpunkt eingeben...';

  @override
  String get typeSettingsProtocolAgenda => 'Protokoll & Tagesordnung';

  @override
  String get typeSettingsProtocolHelper => 'Termine dieses Typs bekommen eine Tagesordnung im Ablaufplan und ein Protokoll. Wer dazugehört, regeln die relevanten Gruppen.';

  @override
  String get typeSettingsQuickSelect => 'Schnellauswahl';

  @override
  String get typeSettingsRelevantGroups => 'Relevante Gruppen';

  @override
  String get typeSettingsRelevantGroupsHelper => 'Nur die relevanten Gruppen werden beim Anlegen einer Anwesenheit von diesem Typ berücksichtigt. Wenn keine Gruppe ausgewählt ist, werden alle Gruppen berücksichtigt.';

  @override
  String get typeSettingsRemindUnconfirmed => 'Erinnern, wenn unbestätigt';

  @override
  String get typeSettingsReminderExists => 'Diese Erinnerung existiert bereits';

  @override
  String get typeSettingsReminders => 'Erinnerungen';

  @override
  String typeSettingsRemindersActive(Object count) {
    return '$count Erinnerung(en) aktiv';
  }

  @override
  String get typeSettingsRunSheet => 'Ablaufplan';

  @override
  String get typeSettingsSameTime => 'Zur gleichen Zeit';

  @override
  String get typeSettingsSavingOrder => 'Speichere Reihenfolge...';

  @override
  String get typeSettingsSelectFieldType => 'Bitte einen Feldtyp auswählen';

  @override
  String get typeSettingsSelfAssign => 'Selbst eintragen erlaubt';

  @override
  String get typeSettingsSelfAssignHelper => 'Personen aus dem Personenkreis können offene Dienste selbst übernehmen.';

  @override
  String get typeSettingsSignupFields => 'Anmeldefelder';

  @override
  String get typeSettingsSingle => 'Einzelauswahl';

  @override
  String get typeSettingsSongPlaceholder => 'Werk Platzhalter';

  @override
  String typeSettingsSongPlaceholderN(Object n) {
    return 'Werk Platzhalter $n';
  }

  @override
  String get typeSettingsSongsHelper => 'Wenn du diese Option aktivierst, dann kannst du beim Anlegen einer Anwesenheit von diesem Typ, Werke hinzufügen, die für die kommenden Proben relevant sind und automatisch im Probenplan berücksichtigt werden.';

  @override
  String get typeSettingsStart => 'Beginn';

  @override
  String get typeSettingsStartAllDay => 'Startzeit für den Ablaufplan bei ganztägigen Terminen';

  @override
  String get typeSettingsStartShort => 'Start';

  @override
  String get typeSettingsSuggestPostponed => 'Vertagte Themen vorschlagen';

  @override
  String get typeSettingsTenantNameBefore => 'Instanz-Name vor Werken';

  @override
  String get typeSettingsTenantNameHelper => 'Falls aktiviert, wird der Instanz-Name vor jedem Werk im Ablaufplan angezeigt.';

  @override
  String get typeSettingsText => 'Text';

  @override
  String get typeSettingsTimesHint => 'Die Zeiten können nachträglich individuell in jeder Anwesenheit angepasst werden';

  @override
  String get typeSettingsTitleHelper => 'Dieser Titel wird beim Exportieren eines Ablaufplans angezeigt. Falls eine Typ-Info vorhanden ist, wird diese in Klammern dahinter angezeigt. (z.B. Probenplan (Kantateprobe))';

  @override
  String get typeSettingsTodoPlaceholder => 'To-Do Text eingeben...';

  @override
  String get typeSettingsTodoTextPh => 'To-Do Text...';

  @override
  String get typeSettingsTopicMinutes => 'Standarddauer pro Thema (Min.)';

  @override
  String get typeSettingsTopicsHere => 'Hier werden Themen eingefügt';

  @override
  String get typeSettingsTwoOptions => 'Bitte mindestens 2 Optionen angeben';

  @override
  String get typeSettingsTwoStatus => 'Bitte mindestens zwei verfügbare Anwesenheitsstatus auswählen.';

  @override
  String get typeSettingsType => 'Typ';

  @override
  String get typeSettingsTypes => 'Typen';

  @override
  String get typeSettingsTypesIntro => 'Pflege deine eigenen Typen für Anwesenheiten. So kannst du individuelle Bezeichnungen, einen Standard-Status, Probenvorlagen und Start- bzw. Endzeiten hinterlegen und auch Anwesenheiten nur für bestimmte Gruppen konfigurieren.';

  @override
  String get typeSettingsUpdate => 'Updaten';

  @override
  String get typeSettingsUpdateFailed => 'Fehler beim Aktualisieren des Anwesenheitstyps';

  @override
  String get typeSettingsUpdated => 'Anwesenheitstyp erfolgreich aktualisiert';

  @override
  String get typeSettingsUrgentHelper => 'Einmaliger dringender Push an alle aus dem Personenkreis und die Leitung.';

  @override
  String get typeSettingsUrgentIfOpen => 'Dringend, wenn noch offen';

  @override
  String get typeSettingsUseDutyView => 'Dienstplan-Ansicht verwenden?';

  @override
  String get typeSettingsUseDutyViewMessage => 'Sind Dienste bei euch der Normalfall? Dann zeigt „Meine Termine“ für alle im Dienst-Team zuerst ihre Dienste, offene Dienste und Zahlen statt der Anwesenheitsquote. Du kannst das jederzeit unter Mehr → Einstellungen ändern.';

  @override
  String get typeSettingsUseIt => 'Ja, verwenden';

  @override
  String get typeSettingsValidHours => 'Gültige Werte: 0-168 Stunden (max. 1 Woche vorher)';

  @override
  String get typeSettingsValue => 'Wert';

  @override
  String get typeSettingsViewFailed => 'Konnte die Ansicht nicht umstellen';

  @override
  String get typeSettingsYesNo => 'Ja / Nein';

  @override
  String get usageActive7 => 'Aktiv (7T)';

  @override
  String get usageActiveTenants => 'Aktive Instanzen';

  @override
  String get usageDays30 => '30 Tage';

  @override
  String get usageDays7 => '7 Tage';

  @override
  String get usageDays90 => '90 Tage';

  @override
  String get usageDevices => 'Geräte';

  @override
  String get usageDistribution => 'Event-Verteilung';

  @override
  String get usageEventsPerDay => 'Events pro Tag';

  @override
  String get usageNoEvents => 'Keine Events im gewählten Zeitraum.';

  @override
  String get usageTitle => 'Usage Dashboard';

  @override
  String get usageTopEvent => 'Top Event';

  @override
  String get usageTopEvents => 'Top Events';

  @override
  String get usageTopTenants => 'Top Instanzen';

  @override
  String get usageTotalEvents => 'Events gesamt';

  @override
  String voiceLeaderFlutterMemberCount(Object count) {
    return '$count Mitglieder';
  }

  @override
  String voiceLeaderFlutterMoreCount(Object count) {
    return '+$count weitere';
  }

  @override
  String get voiceLeaderFlutterNoGroup => 'Du bist noch keiner Stimmgruppe zugeordnet.';

  @override
  String get voiceLeaderFlutterVoiceGroup => 'Stimmgruppe';

  @override
  String get voiceLeaderLoadFailed => 'Fehler beim Laden der Gruppenmitglieder.';

  @override
  String get voiceLeaderMyVoice => 'Meine Stimme';

  @override
  String get voiceLeaderNoContact => 'Keine Kontaktdaten hinterlegt';

  @override
  String get voiceLeaderNoMembers => 'Keine Mitglieder in deiner Stimme gefunden.';

  @override
  String get voiceLeaderNoProfile => 'Kein Spielerprofil gefunden.';

  @override
  String get voiceLeaderProfilePicture => 'Profilbild';

  @override
  String get voiceLeaderSfShort => 'Sf';

  @override
  String get voiceLeaderUpcomingAbsences => 'Anstehende Abwesenheiten:';
}
