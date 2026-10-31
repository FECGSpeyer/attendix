import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// a11y.add
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get a11yAdd;

  /// a11y.clearInput
  ///
  /// In de, this message translates to:
  /// **'Eingabe löschen'**
  String get a11yClearInput;

  /// a11y.decrease
  ///
  /// In de, this message translates to:
  /// **'Verringern'**
  String get a11yDecrease;

  /// a11y.help
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get a11yHelp;

  /// a11y.increase
  ///
  /// In de, this message translates to:
  /// **'Erhöhen'**
  String get a11yIncrease;

  /// a11y.moreActions
  ///
  /// In de, this message translates to:
  /// **'Weitere Aktionen'**
  String get a11yMoreActions;

  /// a11y.nextPage
  ///
  /// In de, this message translates to:
  /// **'Nächste Seite'**
  String get a11yNextPage;

  /// a11y.previousPage
  ///
  /// In de, this message translates to:
  /// **'Vorherige Seite'**
  String get a11yPreviousPage;

  /// a11y.rating
  ///
  /// In de, this message translates to:
  /// **'{count} von 5 Sternen'**
  String a11yRating(Object count);

  /// a11y.selectDate
  ///
  /// In de, this message translates to:
  /// **'Datum wählen'**
  String get a11ySelectDate;

  /// admin.addChurch
  ///
  /// In de, this message translates to:
  /// **'Gemeinde hinzufügen'**
  String get adminAddChurch;

  /// admin.churchAdded
  ///
  /// In de, this message translates to:
  /// **'Die Gemeinde wurde erfolgreich hinzugefügt.'**
  String get adminChurchAdded;

  /// admin.churchName
  ///
  /// In de, this message translates to:
  /// **'Name der Gemeinde'**
  String get adminChurchName;

  /// admin.churchRenamed
  ///
  /// In de, this message translates to:
  /// **'Gemeinde umbenannt'**
  String get adminChurchRenamed;

  /// admin.churchesCount
  ///
  /// In de, this message translates to:
  /// **'Gemeinden ({count})'**
  String adminChurchesCount(Object count);

  /// admin.currentlyUsed
  ///
  /// In de, this message translates to:
  /// **'Aktuell belegt'**
  String get adminCurrentlyUsed;

  /// admin.duplicateGroups
  ///
  /// In de, this message translates to:
  /// **'{count} Duplikat-Gruppe(n) gefunden'**
  String adminDuplicateGroups(Object count);

  /// admin.duplicatesHint
  ///
  /// In de, this message translates to:
  /// **'Gemeinden mit gleichem Namen können zusammengeführt werden.'**
  String get adminDuplicatesHint;

  /// admin.evaluation
  ///
  /// In de, this message translates to:
  /// **'Auswertung'**
  String get adminEvaluation;

  /// admin.flutter.addFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen'**
  String get adminFlutterAddFailed;

  /// admin.gb
  ///
  /// In de, this message translates to:
  /// **'{value} GB'**
  String adminGb(Object value);

  /// admin.invalidLimit
  ///
  /// In de, this message translates to:
  /// **'Bitte eine Zahl größer 0 eingeben oder das Feld leeren (unbegrenzt).'**
  String get adminInvalidLimit;

  /// admin.invalidValues
  ///
  /// In de, this message translates to:
  /// **'Bitte gib gültige Werte ein.'**
  String get adminInvalidValues;

  /// admin.limitHelper
  ///
  /// In de, this message translates to:
  /// **'Leer lassen für unbegrenzt. Neue Instanzen starten mit 5 GB.'**
  String get adminLimitHelper;

  /// admin.maxStorage
  ///
  /// In de, this message translates to:
  /// **'Max. Speicher (GB)'**
  String get adminMaxStorage;

  /// admin.merge
  ///
  /// In de, this message translates to:
  /// **'Zusammenführen'**
  String get adminMerge;

  /// admin.mergeAll
  ///
  /// In de, this message translates to:
  /// **'Alle zusammenführen'**
  String get adminMergeAll;

  /// admin.mergeAllDuplicates
  ///
  /// In de, this message translates to:
  /// **'Alle Duplikate zusammenführen'**
  String get adminMergeAllDuplicates;

  /// admin.mergeAllMessage
  ///
  /// In de, this message translates to:
  /// **'{total} Duplikat(e) in {groups} Gruppe(n) werden zusammengeführt. Fortfahren?'**
  String adminMergeAllMessage(Object total, Object groups);

  /// admin.mergeChurches
  ///
  /// In de, this message translates to:
  /// **'Gemeinden zusammenführen'**
  String get adminMergeChurches;

  /// admin.mergeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Zusammenführen'**
  String get adminMergeFailed;

  /// admin.mergeMessage
  ///
  /// In de, this message translates to:
  /// **'„{source}“ wird in „{target}“ zusammengeführt. Alle Personen werden aktualisiert. Fortfahren?'**
  String adminMergeMessage(Object source, Object target);

  /// admin.mergeMoveMessage
  ///
  /// In de, this message translates to:
  /// **'„{source}“ wird gelöscht und alle Personen zu „{target}“ verschoben. Fortfahren?'**
  String adminMergeMoveMessage(Object source, Object target);

  /// admin.mergeWith
  ///
  /// In de, this message translates to:
  /// **'„{name}“ zusammenführen mit...'**
  String adminMergeWith(Object name);

  /// admin.merged
  ///
  /// In de, this message translates to:
  /// **'Zusammengeführt: {count} Person(en) aktualisiert'**
  String adminMerged(Object count);

  /// admin.mergedAll
  ///
  /// In de, this message translates to:
  /// **'{updated} Person(en) aktualisiert, {total} Duplikat(e) entfernt'**
  String adminMergedAll(Object updated, Object total);

  /// admin.merging
  ///
  /// In de, this message translates to:
  /// **'Gemeinden werden zusammengeführt...'**
  String get adminMerging;

  /// admin.renameChurch
  ///
  /// In de, this message translates to:
  /// **'Gemeinde umbenennen'**
  String get adminRenameChurch;

  /// admin.renameFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Umbenennen'**
  String get adminRenameFailed;

  /// admin.showAllChurches
  ///
  /// In de, this message translates to:
  /// **'Alle Gemeinden anzeigen'**
  String get adminShowAllChurches;

  /// admin.storageFor
  ///
  /// In de, this message translates to:
  /// **'Speicher Dateiablage: {name}'**
  String adminStorageFor(Object name);

  /// admin.storageLimit
  ///
  /// In de, this message translates to:
  /// **'Speicherlimit: {gb} GB'**
  String adminStorageLimit(Object gb);

  /// admin.storageUnlimited
  ///
  /// In de, this message translates to:
  /// **'Speicher: unbegrenzt'**
  String get adminStorageUnlimited;

  /// admin.timesPresent
  ///
  /// In de, this message translates to:
  /// **'{count}x vorhanden'**
  String adminTimesPresent(Object count);

  /// admin.title
  ///
  /// In de, this message translates to:
  /// **'Administration'**
  String get adminTitle;

  /// admin.unlimited
  ///
  /// In de, this message translates to:
  /// **'Unbegrenzt'**
  String get adminUnlimited;

  /// agenda.addTask
  ///
  /// In de, this message translates to:
  /// **'Aufgabe hinzufügen'**
  String get agendaAddTask;

  /// agenda.addTopics
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Thema} other {{count} Themen}} aufnehmen · {min} min'**
  String agendaAddTopics(num count, Object min);

  /// agenda.agendaUpdated
  ///
  /// In de, this message translates to:
  /// **'Tagesordnung aktualisiert'**
  String get agendaAgendaUpdated;

  /// agenda.alreadyInPlan
  ///
  /// In de, this message translates to:
  /// **'bereits im Ablaufplan'**
  String get agendaAlreadyInPlan;

  /// agenda.alreadyPlanned
  ///
  /// In de, this message translates to:
  /// **' (bereits eingeplant)'**
  String get agendaAlreadyPlanned;

  /// agenda.chooseTopics
  ///
  /// In de, this message translates to:
  /// **'Themen auswählen'**
  String get agendaChooseTopics;

  /// agenda.createAsNew
  ///
  /// In de, this message translates to:
  /// **'„{name}“ als neues Thema anlegen'**
  String agendaCreateAsNew(Object name);

  /// agenda.createFailed
  ///
  /// In de, this message translates to:
  /// **'Thema konnte nicht angelegt werden'**
  String get agendaCreateFailed;

  /// agenda.default
  ///
  /// In de, this message translates to:
  /// **'Standard'**
  String get agendaDefault;

  /// agenda.deleteConfirm
  ///
  /// In de, this message translates to:
  /// **'Thema wirklich löschen?'**
  String get agendaDeleteConfirm;

  /// agenda.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Löschen fehlgeschlagen'**
  String get agendaDeleteFailed;

  /// agenda.deleteMessage
  ///
  /// In de, this message translates to:
  /// **'Es verschwindet aus dem Themenspeicher. Bereits geplante Ablaufpläne und Protokolle bleiben unverändert. Soll es nur aus einem Termin raus, entferne es dort über „Themen aufnehmen“ oder in der Teamorganisation.'**
  String get agendaDeleteMessage;

  /// agenda.deleteTopic
  ///
  /// In de, this message translates to:
  /// **'Thema löschen'**
  String get agendaDeleteTopic;

  /// agenda.deleted
  ///
  /// In de, this message translates to:
  /// **'Gelöscht'**
  String get agendaDeleted;

  /// agenda.description
  ///
  /// In de, this message translates to:
  /// **'Beschreibung'**
  String get agendaDescription;

  /// agenda.descriptionPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Hintergrund, Ziel, offene Fragen …'**
  String get agendaDescriptionPlaceholder;

  /// agenda.done
  ///
  /// In de, this message translates to:
  /// **'{who} · erledigt'**
  String agendaDone(Object who);

  /// agenda.doneOn
  ///
  /// In de, this message translates to:
  /// **'{who} · erledigt {date}'**
  String agendaDoneOn(Object who, Object date);

  /// agenda.dueOn
  ///
  /// In de, this message translates to:
  /// **'{who} · fällig {date}'**
  String agendaDueOn(Object who, Object date);

  /// agenda.durationPerSession
  ///
  /// In de, this message translates to:
  /// **'Dauer pro Sitzung (Min.)'**
  String get agendaDurationPerSession;

  /// agenda.enterTitle
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Titel eingeben'**
  String get agendaEnterTitle;

  /// agenda.flutter.noMatch
  ///
  /// In de, this message translates to:
  /// **'Kein passendes Thema gefunden.'**
  String get agendaFlutterNoMatch;

  /// agenda.flutter.noOpenTopics
  ///
  /// In de, this message translates to:
  /// **'Keine offenen Themen. Lege oben ein neues an.'**
  String get agendaFlutterNoOpenTopics;

  /// agenda.flutter.notFound
  ///
  /// In de, this message translates to:
  /// **'Thema nicht gefunden'**
  String get agendaFlutterNotFound;

  /// agenda.high
  ///
  /// In de, this message translates to:
  /// **'Hoch'**
  String get agendaHigh;

  /// agenda.history
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get agendaHistory;

  /// agenda.insertAfter
  ///
  /// In de, this message translates to:
  /// **'Wird nach „{name}“ eingefügt'**
  String agendaInsertAfter(Object name);

  /// agenda.insertAtStart
  ///
  /// In de, this message translates to:
  /// **'Wird am Anfang eingefügt'**
  String get agendaInsertAtStart;

  /// agenda.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Themen konnten nicht geladen werden'**
  String get agendaLoadFailed;

  /// agenda.longer
  ///
  /// In de, this message translates to:
  /// **'Länger'**
  String get agendaLonger;

  /// agenda.low
  ///
  /// In de, this message translates to:
  /// **'Niedrig'**
  String get agendaLow;

  /// agenda.medium
  ///
  /// In de, this message translates to:
  /// **'Mittel'**
  String get agendaMedium;

  /// agenda.newEnd
  ///
  /// In de, this message translates to:
  /// **'{where} · Ende neu {time}'**
  String agendaNewEnd(Object where, Object time);

  /// agenda.newEvent
  ///
  /// In de, this message translates to:
  /// **'Neuen Termin anlegen'**
  String get agendaNewEvent;

  /// agenda.newTopic
  ///
  /// In de, this message translates to:
  /// **'Neues Thema'**
  String get agendaNewTopic;

  /// agenda.noOutcome
  ///
  /// In de, this message translates to:
  /// **'Ohne Ergebnis'**
  String get agendaNoOutcome;

  /// agenda.noProtocolEvent
  ///
  /// In de, this message translates to:
  /// **'Noch kein Termin mit Tagesordnung geplant'**
  String get agendaNoProtocolEvent;

  /// agenda.noTasks
  ///
  /// In de, this message translates to:
  /// **'Keine Aufgaben'**
  String get agendaNoTasks;

  /// agenda.nobody
  ///
  /// In de, this message translates to:
  /// **'Niemand'**
  String get agendaNobody;

  /// agenda.notDiscussed
  ///
  /// In de, this message translates to:
  /// **'Noch in keinem Termin besprochen.'**
  String get agendaNotDiscussed;

  /// agenda.planFailed
  ///
  /// In de, this message translates to:
  /// **'Thema konnte nicht eingeplant werden'**
  String get agendaPlanFailed;

  /// agenda.planIn
  ///
  /// In de, this message translates to:
  /// **'Einplanen'**
  String get agendaPlanIn;

  /// agenda.planSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan konnte nicht gespeichert werden'**
  String get agendaPlanSaveFailed;

  /// agenda.planned
  ///
  /// In de, this message translates to:
  /// **'Geplant'**
  String get agendaPlanned;

  /// agenda.plannedFor
  ///
  /// In de, this message translates to:
  /// **'Eingeplant für {date}'**
  String agendaPlannedFor(Object date);

  /// agenda.postponed
  ///
  /// In de, this message translates to:
  /// **'Vertagt'**
  String get agendaPostponed;

  /// agenda.postponedFromLast
  ///
  /// In de, this message translates to:
  /// **'Vertagt aus letzter Sitzung'**
  String get agendaPostponedFromLast;

  /// agenda.postponedOn
  ///
  /// In de, this message translates to:
  /// **'Vertagt {date}'**
  String agendaPostponedOn(Object date);

  /// agenda.priority
  ///
  /// In de, this message translates to:
  /// **'Priorität'**
  String get agendaPriority;

  /// agenda.proposedBy
  ///
  /// In de, this message translates to:
  /// **'Vorschlag von {name}'**
  String agendaProposedBy(Object name);

  /// agenda.removeTopics
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Thema} other {{count} Themen}} entfernen'**
  String agendaRemoveTopics(num count);

  /// agenda.removedFromPlan
  ///
  /// In de, this message translates to:
  /// **'wird aus dem Ablaufplan entfernt'**
  String get agendaRemovedFromPlan;

  /// agenda.responsible
  ///
  /// In de, this message translates to:
  /// **'Verantwortlich'**
  String get agendaResponsible;

  /// agenda.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Thema konnte nicht gespeichert werden'**
  String get agendaSaveFailed;

  /// agenda.searchOrCreate
  ///
  /// In de, this message translates to:
  /// **'Thema suchen oder neu anlegen'**
  String get agendaSearchOrCreate;

  /// agenda.shorter
  ///
  /// In de, this message translates to:
  /// **'Kürzer'**
  String get agendaShorter;

  /// agenda.status
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get agendaStatus;

  /// agenda.statusDone
  ///
  /// In de, this message translates to:
  /// **'Erledigt'**
  String get agendaStatusDone;

  /// agenda.statusDropped
  ///
  /// In de, this message translates to:
  /// **'Verworfen'**
  String get agendaStatusDropped;

  /// agenda.statusOpen
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get agendaStatusOpen;

  /// agenda.tasks
  ///
  /// In de, this message translates to:
  /// **'Aufgaben'**
  String get agendaTasks;

  /// agenda.tasksDone
  ///
  /// In de, this message translates to:
  /// **'{done} von {total} erledigt'**
  String agendaTasksDone(Object done, Object total);

  /// agenda.titlePlaceholder
  ///
  /// In de, this message translates to:
  /// **'Worum geht es?'**
  String get agendaTitlePlaceholder;

  /// agenda.topic
  ///
  /// In de, this message translates to:
  /// **'Thema'**
  String get agendaTopic;

  /// agenda.topicAdded
  ///
  /// In de, this message translates to:
  /// **'Thema aufgenommen'**
  String get agendaTopicAdded;

  /// agenda.topicRemoved
  ///
  /// In de, this message translates to:
  /// **'Thema aus dem Ablaufplan entfernt'**
  String get agendaTopicRemoved;

  /// agenda.topicStore
  ///
  /// In de, this message translates to:
  /// **'Themenspeicher'**
  String get agendaTopicStore;

  /// agenda.topicsAdded
  ///
  /// In de, this message translates to:
  /// **'{count} Themen aufgenommen'**
  String agendaTopicsAdded(Object count);

  /// agenda.topicsRemoved
  ///
  /// In de, this message translates to:
  /// **'{count} Themen aus dem Ablaufplan entfernt'**
  String agendaTopicsRemoved(Object count);

  /// agenda.whichEvent
  ///
  /// In de, this message translates to:
  /// **'In welchen Termin einplanen?'**
  String get agendaWhichEvent;

  /// app.changePassword
  ///
  /// In de, this message translates to:
  /// **'Passwort ändern'**
  String get appChangePassword;

  /// app.confirmLinkInvalid
  ///
  /// In de, this message translates to:
  /// **'Der Bestätigungslink ist ungültig oder abgelaufen.'**
  String get appConfirmLinkInvalid;

  /// app.emailConfirmed
  ///
  /// In de, this message translates to:
  /// **'E-Mail-Adresse bestätigt. Willkommen!'**
  String get appEmailConfirmed;

  /// app.minSixPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Min. 6 Zeichen eingeben...'**
  String get appMinSixPlaceholder;

  /// app.nativeAd.goTo
  ///
  /// In de, this message translates to:
  /// **'Zum {store}'**
  String appNativeAdGoTo(Object store);

  /// app.nativeAd.header
  ///
  /// In de, this message translates to:
  /// **'Attendix als App verfügbar!'**
  String get appNativeAdHeader;

  /// app.nativeAd.message
  ///
  /// In de, this message translates to:
  /// **'Attendix gibt es jetzt als native App mit Push-Benachrichtigungen und schnellerem Zugriff. Jetzt im {store} herunterladen!'**
  String appNativeAdMessage(Object store);

  /// app.newPassword
  ///
  /// In de, this message translates to:
  /// **'Neues Passwort eingeben'**
  String get appNewPassword;

  /// app.passwordMin
  ///
  /// In de, this message translates to:
  /// **'Bitte gib ein Passwort mit mindestens 6 Zeichen ein'**
  String get appPasswordMin;

  /// appRedirect.loadApp
  ///
  /// In de, this message translates to:
  /// **'Lade die App im Store deines Geräts:'**
  String get appRedirectLoadApp;

  /// app.resetLinkInvalid
  ///
  /// In de, this message translates to:
  /// **'Der Link zum Zurücksetzen ist ungültig oder abgelaufen.'**
  String get appResetLinkInvalid;

  /// attList.addEvent
  ///
  /// In de, this message translates to:
  /// **'Termin hinzufügen'**
  String get attListAddEvent;

  /// attList.addEvents
  ///
  /// In de, this message translates to:
  /// **'Termine hinzufügen'**
  String get attListAddEvents;

  /// attList.addSongs
  ///
  /// In de, this message translates to:
  /// **'Werk(e) hinzufügen'**
  String get attListAddSongs;

  /// attList.average
  ///
  /// In de, this message translates to:
  /// **'Durchschnitt'**
  String get attListAverage;

  /// attList.chooseOneDate
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle mindestens ein Datum aus'**
  String get attListChooseOneDate;

  /// attList.chooseSongs
  ///
  /// In de, this message translates to:
  /// **'Werke auswählen'**
  String get attListChooseSongs;

  /// attList.conductor
  ///
  /// In de, this message translates to:
  /// **'Dirigent'**
  String get attListConductor;

  /// attList.continue
  ///
  /// In de, this message translates to:
  /// **'Fortfahren'**
  String get attListContinue;

  /// attList.countAbsent
  ///
  /// In de, this message translates to:
  /// **'{count} abwesend'**
  String attListCountAbsent(Object count);

  /// attList.countExcused
  ///
  /// In de, this message translates to:
  /// **'{count} entschuldigt'**
  String attListCountExcused(Object count);

  /// attList.countPresent
  ///
  /// In de, this message translates to:
  /// **'{count} anwesend'**
  String attListCountPresent(Object count);

  /// attList.dateMulti
  ///
  /// In de, this message translates to:
  /// **'Datum (Mehrfachauswahl möglich)'**
  String get attListDateMulti;

  /// attList.distributeDuties
  ///
  /// In de, this message translates to:
  /// **'Dienste verteilen'**
  String get attListDistributeDuties;

  /// attList.durationDays
  ///
  /// In de, this message translates to:
  /// **'Dauer (in Tagen)'**
  String get attListDurationDays;

  /// attList.dutyFilled
  ///
  /// In de, this message translates to:
  /// **'{text} besetzt'**
  String attListDutyFilled(Object text);

  /// attList.enterConductor
  ///
  /// In de, this message translates to:
  /// **'Dirigent eingeben'**
  String get attListEnterConductor;

  /// attList.eventAdded
  ///
  /// In de, this message translates to:
  /// **'Termin hinzugefügt'**
  String get attListEventAdded;

  /// attList.eventTypes
  ///
  /// In de, this message translates to:
  /// **'Veranstaltungstypen'**
  String get attListEventTypes;

  /// attList.events
  ///
  /// In de, this message translates to:
  /// **'Termine'**
  String get attListEvents;

  /// attList.eventsAdded
  ///
  /// In de, this message translates to:
  /// **'Termine hinzugefügt'**
  String get attListEventsAdded;

  /// attList.eventsSelected
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Termin ausgewählt} other {{count} Termine ausgewählt}}'**
  String attListEventsSelected(num count);

  /// attList.holidays
  ///
  /// In de, this message translates to:
  /// **'Feiertage'**
  String get attListHolidays;

  /// attList.holidaysOfState
  ///
  /// In de, this message translates to:
  /// **'Feiertage des ausgewählten Bundeslandes'**
  String get attListHolidaysOfState;

  /// attList.infoText
  ///
  /// In de, this message translates to:
  /// **'Info-Text (optional)'**
  String get attListInfoText;

  /// attList.infoTextHelper
  ///
  /// In de, this message translates to:
  /// **'Dieser Text wird anstelle des Typs angezeigt.'**
  String get attListInfoTextHelper;

  /// attList.invalidType
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Anwesenheitstyp ausgewählt'**
  String get attListInvalidType;

  /// attList.less
  ///
  /// In de, this message translates to:
  /// **'Weniger'**
  String get attListLess;

  /// attList.more
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get attListMore;

  /// attList.neededPeople
  ///
  /// In de, this message translates to:
  /// **'Benötigte Personen · {label}'**
  String attListNeededPeople(Object label);

  /// attList.noDate
  ///
  /// In de, this message translates to:
  /// **'Kein Datum ausgewählt'**
  String get attListNoDate;

  /// attList.noEventsYet
  ///
  /// In de, this message translates to:
  /// **'Bisher wurden noch keine Termine angelegt'**
  String get attListNoEventsYet;

  /// attList.noSongsFound
  ///
  /// In de, this message translates to:
  /// **'Keine Werke gefunden'**
  String get attListNoSongsFound;

  /// attList.noSongsSelected
  ///
  /// In de, this message translates to:
  /// **'Keine Werke ausgewählt'**
  String get attListNoSongsSelected;

  /// attList.otherConductor
  ///
  /// In de, this message translates to:
  /// **'Anderer Dirigent'**
  String get attListOtherConductor;

  /// attList.place
  ///
  /// In de, this message translates to:
  /// **'Ort (für Navigation)'**
  String get attListPlace;

  /// attList.placePlaceholder
  ///
  /// In de, this message translates to:
  /// **'z. B. Gemeindehaus, Musterstr. 1, 12345 Berlin'**
  String get attListPlacePlaceholder;

  /// attList.presentOf
  ///
  /// In de, this message translates to:
  /// **'{present} von {total} anwesend'**
  String attListPresentOf(Object present, Object total);

  /// attList.removeConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du den Termin wirklich entfernen?'**
  String get attListRemoveConfirm;

  /// attList.schoolHolidays
  ///
  /// In de, this message translates to:
  /// **'Ferien'**
  String get attListSchoolHolidays;

  /// attList.schoolHolidaysOfState
  ///
  /// In de, this message translates to:
  /// **'Ferien des ausgewählten Bundeslandes'**
  String get attListSchoolHolidaysOfState;

  /// attList.searchSong
  ///
  /// In de, this message translates to:
  /// **'Werk suchen...'**
  String get attListSearchSong;

  /// attList.showAll
  ///
  /// In de, this message translates to:
  /// **'Alle anzeigen'**
  String get attListShowAll;

  /// attList.songs
  ///
  /// In de, this message translates to:
  /// **'Werke'**
  String get attListSongs;

  /// attList.songsLabel
  ///
  /// In de, this message translates to:
  /// **'Werk(e)'**
  String get attListSongsLabel;

  /// attList.songsSelected
  ///
  /// In de, this message translates to:
  /// **'{count} Werk(e) ausgewählt'**
  String attListSongsSelected(num count);

  /// attList.todayDeselected
  ///
  /// In de, this message translates to:
  /// **'Das aktuelle Datum wurde deselektiert'**
  String get attListTodayDeselected;

  /// attList.type
  ///
  /// In de, this message translates to:
  /// **'Typ'**
  String get attListType;

  /// attList.unknownConductor
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Dirigent'**
  String get attListUnknownConductor;

  /// attList.unknownSong
  ///
  /// In de, this message translates to:
  /// **'Unbekanntes Lied'**
  String get attListUnknownSong;

  /// attendance.add
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get attendanceAdd;

  /// attendance.addNote
  ///
  /// In de, this message translates to:
  /// **'Notiz hinzufügen'**
  String get attendanceAddNote;

  /// attendance.addPeopleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen der Personen'**
  String get attendanceAddPeopleFailed;

  /// attendance.addPerson
  ///
  /// In de, this message translates to:
  /// **'Person hinzufügen'**
  String get attendanceAddPerson;

  /// attendance.addPersonsCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Person hinzufügen} other {{count} Personen hinzufügen}}'**
  String attendanceAddPersonsCount(num count);

  /// attendance.addTodo
  ///
  /// In de, this message translates to:
  /// **'To-Do hinzufügen'**
  String get attendanceAddTodo;

  /// attendance.addTopics
  ///
  /// In de, this message translates to:
  /// **'Themen aufnehmen'**
  String get attendanceAddTopics;

  /// attendance.addingPeople
  ///
  /// In de, this message translates to:
  /// **'Personen werden hinzugefügt...'**
  String get attendanceAddingPeople;

  /// attendance.addressPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Adresse oder Ortsname'**
  String get attendanceAddressPlaceholder;

  /// attendance.allAlreadyIncluded
  ///
  /// In de, this message translates to:
  /// **'Alle Personen sind bereits in dieser Anwesenheit enthalten.'**
  String get attendanceAllAlreadyIncluded;

  /// attendance.assign
  ///
  /// In de, this message translates to:
  /// **'Einteilen'**
  String get attendanceAssign;

  /// attendance.assignPerson
  ///
  /// In de, this message translates to:
  /// **'Person einteilen'**
  String get attendanceAssignPerson;

  /// attendance.assignedNotified
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {Eingeteilt, die Person wird benachrichtigt} other {Eingeteilt, die Personen werden benachrichtigt}}'**
  String attendanceAssignedNotified(num count);

  /// attendance.atTime
  ///
  /// In de, this message translates to:
  /// **' um {time} Uhr'**
  String attendanceAtTime(Object time);

  /// attendance.attachmentUploaded
  ///
  /// In de, this message translates to:
  /// **'Anhang hochgeladen'**
  String get attendanceAttachmentUploaded;

  /// attendance.available
  ///
  /// In de, this message translates to:
  /// **'Verfügbar'**
  String get attendanceAvailable;

  /// attendance.cannotWithNote
  ///
  /// In de, this message translates to:
  /// **'Kann nicht: {note}'**
  String attendanceCannotWithNote(Object note);

  /// attendance.changeConductor
  ///
  /// In de, this message translates to:
  /// **'Dirigent ändern'**
  String get attendanceChangeConductor;

  /// attendance.changeFolder
  ///
  /// In de, this message translates to:
  /// **'Ordner ändern'**
  String get attendanceChangeFolder;

  /// attendance.changedOn
  ///
  /// In de, this message translates to:
  /// **'· geändert am {date}'**
  String attendanceChangedOn(Object date);

  /// attendance.checklist
  ///
  /// In de, this message translates to:
  /// **'Checkliste'**
  String get attendanceChecklist;

  /// attendance.checklistRestored
  ///
  /// In de, this message translates to:
  /// **'Checkliste wiederhergestellt'**
  String get attendanceChecklistRestored;

  /// attendance.choose
  ///
  /// In de, this message translates to:
  /// **'Wählen'**
  String get attendanceChoose;

  /// attendance.choosePeople
  ///
  /// In de, this message translates to:
  /// **'Personen auswählen'**
  String get attendanceChoosePeople;

  /// attendance.choosePersonMin
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle mindestens eine Person aus'**
  String get attendanceChoosePersonMin;

  /// attendance.churchOverview
  ///
  /// In de, this message translates to:
  /// **'Gemeinde-Übersicht'**
  String get attendanceChurchOverview;

  /// attendance.clearFilter
  ///
  /// In de, this message translates to:
  /// **'Filter löschen'**
  String get attendanceClearFilter;

  /// attendance.confirmed
  ///
  /// In de, this message translates to:
  /// **'bestätigt'**
  String get attendanceConfirmed;

  /// attendance.connectionRestored
  ///
  /// In de, this message translates to:
  /// **'Verbindung wiederhergestellt'**
  String get attendanceConnectionRestored;

  /// attendance.createRunSheet
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan erstellen'**
  String get attendanceCreateRunSheet;

  /// attendance.currentNote
  ///
  /// In de, this message translates to:
  /// **'Aktuell: {note}'**
  String attendanceCurrentNote(Object note);

  /// attendance.customNote
  ///
  /// In de, this message translates to:
  /// **'Eigene Notiz'**
  String get attendanceCustomNote;

  /// attendance.customNoteEllipsis
  ///
  /// In de, this message translates to:
  /// **'Eigene Notiz...'**
  String get attendanceCustomNoteEllipsis;

  /// attendance.date
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get attendanceDate;

  /// attendance.deadlineDate
  ///
  /// In de, this message translates to:
  /// **'Fristdatum'**
  String get attendanceDeadlineDate;

  /// attendance.deadlineHelper
  ///
  /// In de, this message translates to:
  /// **'Personen können sich nur bis zu diesem Datum anmelden. Eine Abmeldung ist weiterhin möglich.'**
  String get attendanceDeadlineHelper;

  /// attendance.deadlineHours
  ///
  /// In de, this message translates to:
  /// **'Deadline in Stunden (optional)'**
  String get attendanceDeadlineHours;

  /// attendance.declined
  ///
  /// In de, this message translates to:
  /// **'abgesagt'**
  String get attendanceDeclined;

  /// attendance.defaultSortGroup
  ///
  /// In de, this message translates to:
  /// **'Standard (Gruppe)'**
  String get attendanceDefaultSortGroup;

  /// attendance.deleteNote
  ///
  /// In de, this message translates to:
  /// **'Notiz löschen'**
  String get attendanceDeleteNote;

  /// attendance.deleteTodo
  ///
  /// In de, this message translates to:
  /// **'To-Do löschen'**
  String get attendanceDeleteTodo;

  /// attendance.deleteTodoConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du dieses To-Do wirklich löschen?'**
  String get attendanceDeleteTodoConfirm;

  /// attendance.deletedByOther
  ///
  /// In de, this message translates to:
  /// **'Die Anwesenheit wurde soeben von einem anderen Nutzer gelöscht'**
  String get attendanceDeletedByOther;

  /// attendance.descriptionAttachment
  ///
  /// In de, this message translates to:
  /// **'Beschreibung & Anhang'**
  String get attendanceDescriptionAttachment;

  /// attendance.descriptionPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Beschreibung eingeben...'**
  String get attendanceDescriptionPlaceholder;

  /// attendance.draft
  ///
  /// In de, this message translates to:
  /// **'Entwurf'**
  String get attendanceDraft;

  /// attendance.draftEdited
  ///
  /// In de, this message translates to:
  /// **'Entwurf · zuletzt bearbeitet {date} Uhr'**
  String attendanceDraftEdited(Object date);

  /// attendance.dueNow
  ///
  /// In de, this message translates to:
  /// **'Jetzt fällig'**
  String get attendanceDueNow;

  /// attendance.dueOn
  ///
  /// In de, this message translates to:
  /// **'· fällig {date}'**
  String attendanceDueOn(Object date);

  /// attendance.editDescription
  ///
  /// In de, this message translates to:
  /// **'Beschreibung & Anhang bearbeiten'**
  String get attendanceEditDescription;

  /// attendance.editRegFields
  ///
  /// In de, this message translates to:
  /// **'Anmeldefelder bearbeiten'**
  String get attendanceEditRegFields;

  /// attendance.editRunSheet
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan bearbeiten'**
  String get attendanceEditRunSheet;

  /// attendance.emailLink
  ///
  /// In de, this message translates to:
  /// **'Link in der E-Mail'**
  String get attendanceEmailLink;

  /// attendance.end
  ///
  /// In de, this message translates to:
  /// **'Ende'**
  String get attendanceEnd;

  /// attendance.enterNote
  ///
  /// In de, this message translates to:
  /// **'Notiz eingeben...'**
  String get attendanceEnterNote;

  /// attendance.enterText
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Text eingeben'**
  String get attendanceEnterText;

  /// attendance.eventFallback
  ///
  /// In de, this message translates to:
  /// **'Termin'**
  String get attendanceEventFallback;

  /// attendance.eventOnDate
  ///
  /// In de, this message translates to:
  /// **'{type} am {date}'**
  String attendanceEventOnDate(Object type, Object date);

  /// attendance.explicitStatus
  ///
  /// In de, this message translates to:
  /// **'Explizite Statusauswahl'**
  String get attendanceExplicitStatus;

  /// attendance.explicitStatusHint
  ///
  /// In de, this message translates to:
  /// **'Status über Dropdown statt Antippen wählen'**
  String get attendanceExplicitStatusHint;

  /// attendance.exportExcel
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit als Excel exportieren'**
  String get attendanceExportExcel;

  /// attendance.exportPdf
  ///
  /// In de, this message translates to:
  /// **'Exportieren (PDF)'**
  String get attendanceExportPdf;

  /// attendance.exportPdfA5
  ///
  /// In de, this message translates to:
  /// **'Exportieren (PDF 2x A5)'**
  String get attendanceExportPdfA5;

  /// attendance.fewerPeopleNeeded
  ///
  /// In de, this message translates to:
  /// **'Weniger Personen benötigt'**
  String get attendanceFewerPeopleNeeded;

  /// attendance.filesFolder
  ///
  /// In de, this message translates to:
  /// **'Ordner in der Dateiablage'**
  String get attendanceFilesFolder;

  /// attendance.filesFolderHint
  ///
  /// In de, this message translates to:
  /// **'z. B. Aufnahmen des Termins'**
  String get attendanceFilesFolderHint;

  /// attendance.filterActive
  ///
  /// In de, this message translates to:
  /// **'{count} aktiv'**
  String attendanceFilterActive(Object count);

  /// attendance.flutter.a4Standard
  ///
  /// In de, this message translates to:
  /// **'A4 (Standard)'**
  String get attendanceFlutterA4Standard;

  /// attendance.flutter.a5OnA4
  ///
  /// In de, this message translates to:
  /// **'2x A5 auf A4'**
  String get attendanceFlutterA5OnA4;

  /// attendance.flutter.addAttachment
  ///
  /// In de, this message translates to:
  /// **'Anhang hinzufügen'**
  String get attendanceFlutterAddAttachment;

  /// attendance.flutter.addPhoto
  ///
  /// In de, this message translates to:
  /// **'Foto hinzufügen'**
  String get attendanceFlutterAddPhoto;

  /// attendance.flutter.asImage
  ///
  /// In de, this message translates to:
  /// **'Als Bild'**
  String get attendanceFlutterAsImage;

  /// attendance.flutter.attendancesCount
  ///
  /// In de, this message translates to:
  /// **'{count} Anwesenheiten'**
  String attendanceFlutterAttendancesCount(Object count);

  /// attendance.flutter.calendar
  ///
  /// In de, this message translates to:
  /// **'Kalender'**
  String get attendanceFlutterCalendar;

  /// attendance.flutter.camera
  ///
  /// In de, this message translates to:
  /// **'Kamera'**
  String get attendanceFlutterCamera;

  /// attendance.flutter.chooseDeadline
  ///
  /// In de, this message translates to:
  /// **'Anmeldefrist wählen'**
  String get attendanceFlutterChooseDeadline;

  /// attendance.flutter.chooseType
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle einen Veranstaltungstyp'**
  String get attendanceFlutterChooseType;

  /// attendance.flutter.creatingExcel
  ///
  /// In de, this message translates to:
  /// **'Erstelle Excel-Export...'**
  String get attendanceFlutterCreatingExcel;

  /// attendance.flutter.dataUnavailable
  ///
  /// In de, this message translates to:
  /// **'Daten nicht verfügbar'**
  String get attendanceFlutterDataUnavailable;

  /// attendance.flutter.deadlineDisabled
  ///
  /// In de, this message translates to:
  /// **'Anmeldefrist deaktiviert'**
  String get attendanceFlutterDeadlineDisabled;

  /// attendance.flutter.deadlineEnabled
  ///
  /// In de, this message translates to:
  /// **'Anmeldefrist aktiviert'**
  String get attendanceFlutterDeadlineEnabled;

  /// attendance.flutter.deadlineUpdated
  ///
  /// In de, this message translates to:
  /// **'Anmeldefrist aktualisiert'**
  String get attendanceFlutterDeadlineUpdated;

  /// attendance.flutter.deleteTodoTitle
  ///
  /// In de, this message translates to:
  /// **'To-Do löschen?'**
  String get attendanceFlutterDeleteTodoTitle;

  /// attendance.flutter.endAfterStart
  ///
  /// In de, this message translates to:
  /// **'Ende muss nach Beginn liegen'**
  String get attendanceFlutterEndAfterStart;

  /// attendance.flutter.endTime
  ///
  /// In de, this message translates to:
  /// **'Endzeit'**
  String get attendanceFlutterEndTime;

  /// attendance.flutter.endTimeUpdated
  ///
  /// In de, this message translates to:
  /// **'Endzeit aktualisiert'**
  String get attendanceFlutterEndTimeUpdated;

  /// attendance.flutter.errorWith
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String attendanceFlutterErrorWith(Object error);

  /// attendance.flutter.eventsCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Termin} other {{count} Termine}}'**
  String attendanceFlutterEventsCount(num count);

  /// attendance.flutter.excusedShort
  ///
  /// In de, this message translates to:
  /// **'Entsch.'**
  String get attendanceFlutterExcusedShort;

  /// attendance.flutter.exportFormat
  ///
  /// In de, this message translates to:
  /// **'Export-Format'**
  String get attendanceFlutterExportFormat;

  /// attendance.flutter.gallery
  ///
  /// In de, this message translates to:
  /// **'Galerie'**
  String get attendanceFlutterGallery;

  /// attendance.flutter.holiday
  ///
  /// In de, this message translates to:
  /// **'Feiertag'**
  String get attendanceFlutterHoliday;

  /// attendance.flutter.listLoadFailed
  ///
  /// In de, this message translates to:
  /// **'Die Anwesenheitsliste konnte nicht geladen werden.'**
  String get attendanceFlutterListLoadFailed;

  /// attendance.flutter.loadError
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden'**
  String get attendanceFlutterLoadError;

  /// attendance.flutter.noAccount
  ///
  /// In de, this message translates to:
  /// **'Die Person hat keinen Account'**
  String get attendanceFlutterNoAccount;

  /// attendance.flutter.noEntry
  ///
  /// In de, this message translates to:
  /// **'Kein Anwesenheitseintrag gefunden'**
  String get attendanceFlutterNoEntry;

  /// attendance.flutter.noEventTypes
  ///
  /// In de, this message translates to:
  /// **'Keine Veranstaltungstypen konfiguriert'**
  String get attendanceFlutterNoEventTypes;

  /// attendance.flutter.noItemsToExport
  ///
  /// In de, this message translates to:
  /// **'Keine Programmpunkte zum Exportieren'**
  String get attendanceFlutterNoItemsToExport;

  /// attendance.flutter.noItemsToSend
  ///
  /// In de, this message translates to:
  /// **'Keine Programmpunkte zum Senden'**
  String get attendanceFlutterNoItemsToSend;

  /// attendance.flutter.noPermission
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung'**
  String get attendanceFlutterNoPermission;

  /// attendance.flutter.noPlanToExport
  ///
  /// In de, this message translates to:
  /// **'Kein Ablaufplan zum Exportieren'**
  String get attendanceFlutterNoPlanToExport;

  /// attendance.flutter.noPlanToSend
  ///
  /// In de, this message translates to:
  /// **'Kein Ablaufplan zum Senden'**
  String get attendanceFlutterNoPlanToSend;

  /// attendance.flutter.noTodos
  ///
  /// In de, this message translates to:
  /// **'Keine To-Dos vorhanden'**
  String get attendanceFlutterNoTodos;

  /// attendance.flutter.notFound
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit nicht gefunden'**
  String get attendanceFlutterNotFound;

  /// attendance.flutter.noteDeleted
  ///
  /// In de, this message translates to:
  /// **'Notiz gelöscht'**
  String get attendanceFlutterNoteDeleted;

  /// attendance.flutter.notesOptional
  ///
  /// In de, this message translates to:
  /// **'Notizen (optional)'**
  String get attendanceFlutterNotesOptional;

  /// attendance.flutter.onePlanPerPage
  ///
  /// In de, this message translates to:
  /// **'Ein Plan pro Seite'**
  String get attendanceFlutterOnePlanPerPage;

  /// attendance.flutter.open
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get attendanceFlutterOpen;

  /// attendance.flutter.photo
  ///
  /// In de, this message translates to:
  /// **'Foto'**
  String get attendanceFlutterPhoto;

  /// attendance.flutter.photoUploaded
  ///
  /// In de, this message translates to:
  /// **'Foto hochgeladen'**
  String get attendanceFlutterPhotoUploaded;

  /// attendance.flutter.planNotShared
  ///
  /// In de, this message translates to:
  /// **'Plan wird nicht mehr geteilt'**
  String get attendanceFlutterPlanNotShared;

  /// attendance.flutter.planSentTelegram
  ///
  /// In de, this message translates to:
  /// **'Plan per Telegram gesendet'**
  String get attendanceFlutterPlanSentTelegram;

  /// attendance.flutter.planShared
  ///
  /// In de, this message translates to:
  /// **'Plan wird jetzt mit Mitgliedern geteilt'**
  String get attendanceFlutterPlanShared;

  /// attendance.flutter.quickPreview
  ///
  /// In de, this message translates to:
  /// **'Für schnelle Vorschau'**
  String get attendanceFlutterQuickPreview;

  /// attendance.flutter.recordAttendance
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit erfassen'**
  String get attendanceFlutterRecordAttendance;

  /// attendance.flutter.regFieldsSaved
  ///
  /// In de, this message translates to:
  /// **'Anmeldefelder gespeichert'**
  String get attendanceFlutterRegFieldsSaved;

  /// attendance.flutter.removeAttachment
  ///
  /// In de, this message translates to:
  /// **'Anhang entfernen'**
  String get attendanceFlutterRemoveAttachment;

  /// attendance.flutter.restoreChecklistMessage
  ///
  /// In de, this message translates to:
  /// **'Die aktuelle Checkliste wird durch die Standard-Checkliste ersetzt.'**
  String get attendanceFlutterRestoreChecklistMessage;

  /// attendance.flutter.restoreChecklistTitle
  ///
  /// In de, this message translates to:
  /// **'Checkliste wiederherstellen?'**
  String get attendanceFlutterRestoreChecklistTitle;

  /// attendance.flutter.saveFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern: {error}'**
  String attendanceFlutterSaveFailedWith(Object error);

  /// attendance.flutter.schoolHolidays
  ///
  /// In de, this message translates to:
  /// **'Schulferien'**
  String get attendanceFlutterSchoolHolidays;

  /// attendance.flutter.selectDate
  ///
  /// In de, this message translates to:
  /// **'Datum auswählen'**
  String get attendanceFlutterSelectDate;

  /// attendance.flutter.sendFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Senden: {error}'**
  String attendanceFlutterSendFailedWith(Object error);

  /// attendance.flutter.showAllCount
  ///
  /// In de, this message translates to:
  /// **'Alle {count} anzeigen'**
  String attendanceFlutterShowAllCount(Object count);

  /// attendance.flutter.showLess
  ///
  /// In de, this message translates to:
  /// **'Weniger anzeigen'**
  String get attendanceFlutterShowLess;

  /// attendance.flutter.songRemoved
  ///
  /// In de, this message translates to:
  /// **'Werk entfernt'**
  String get attendanceFlutterSongRemoved;

  /// attendance.flutter.standardFormat
  ///
  /// In de, this message translates to:
  /// **'Standard-Format'**
  String get attendanceFlutterStandardFormat;

  /// attendance.flutter.startTimeUpdated
  ///
  /// In de, this message translates to:
  /// **'Startzeit aktualisiert'**
  String get attendanceFlutterStartTimeUpdated;

  /// attendance.flutter.telegramNotConnected
  ///
  /// In de, this message translates to:
  /// **'Telegram nicht verbunden. Bitte zuerst in den Einstellungen verbinden.'**
  String get attendanceFlutterTelegramNotConnected;

  /// attendance.flutter.todoAdded
  ///
  /// In de, this message translates to:
  /// **'To-Do hinzugefügt'**
  String get attendanceFlutterTodoAdded;

  /// attendance.flutter.todoDeleted
  ///
  /// In de, this message translates to:
  /// **'To-Do gelöscht'**
  String get attendanceFlutterTodoDeleted;

  /// attendance.flutter.twoIdenticalPlans
  ///
  /// In de, this message translates to:
  /// **'Zwei identische Pläne (Querformat)'**
  String get attendanceFlutterTwoIdenticalPlans;

  /// attendance.flutter.twoPlansOnePage
  ///
  /// In de, this message translates to:
  /// **'Zwei Pläne auf einer Seite'**
  String get attendanceFlutterTwoPlansOnePage;

  /// attendance.flutter.uploadFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hochladen: {error}'**
  String attendanceFlutterUploadFailedWith(Object error);

  /// attendance.flutter.uploadingPhoto
  ///
  /// In de, this message translates to:
  /// **'Lade Foto hoch...'**
  String get attendanceFlutterUploadingPhoto;

  /// attendance.general
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get attendanceGeneral;

  /// attendance.inDays
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {in {count} Tag} other {in {count} Tagen}}'**
  String attendanceInDays(num count);

  /// attendance.inHours
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {in {count} Stunde} other {in {count} Stunden}}'**
  String attendanceInHours(num count);

  /// attendance.infoText
  ///
  /// In de, this message translates to:
  /// **'Info-Text'**
  String get attendanceInfoText;

  /// attendance.lastChangedBy
  ///
  /// In de, this message translates to:
  /// **'Zuletzt geändert von {name}'**
  String attendanceLastChangedBy(Object name);

  /// attendance.lastChangedByAt
  ///
  /// In de, this message translates to:
  /// **'Zuletzt geändert von {name} am {date} um {time} Uhr'**
  String attendanceLastChangedByAt(Object name, Object date, Object time);

  /// attendance.lateExcusedParen
  ///
  /// In de, this message translates to:
  /// **'Verspätet (entsch.)'**
  String get attendanceLateExcusedParen;

  /// attendance.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitsliste konnte nicht geladen werden'**
  String get attendanceLoadFailed;

  /// attendance.loadFailedReopen
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit konnte nicht geladen werden — bitte erneut öffnen.'**
  String get attendanceLoadFailedReopen;

  /// attendance.loadPeopleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Personen'**
  String get attendanceLoadPeopleFailed;

  /// attendance.loadingPeople
  ///
  /// In de, this message translates to:
  /// **'Lade Personen...'**
  String get attendanceLoadingPeople;

  /// attendance.matchingPeople
  ///
  /// In de, this message translates to:
  /// **'Passende Personen'**
  String get attendanceMatchingPeople;

  /// attendance.message
  ///
  /// In de, this message translates to:
  /// **'Nachricht'**
  String get attendanceMessage;

  /// attendance.messagePlaceholder
  ///
  /// In de, this message translates to:
  /// **'Nachrichtentext'**
  String get attendanceMessagePlaceholder;

  /// attendance.minutesShort
  ///
  /// In de, this message translates to:
  /// **'{min} min'**
  String attendanceMinutesShort(Object min);

  /// attendance.morePeopleNeeded
  ///
  /// In de, this message translates to:
  /// **'Mehr Personen benötigt'**
  String get attendanceMorePeopleNeeded;

  /// attendance.needed
  ///
  /// In de, this message translates to:
  /// **'Benötigt: {count, plural, one {{count} Person} other {{count} Personen}}'**
  String attendanceNeeded(num count);

  /// attendance.noConnection
  ///
  /// In de, this message translates to:
  /// **'Keine Internetverbindung vorhanden'**
  String get attendanceNoConnection;

  /// attendance.noDefaultChecklist
  ///
  /// In de, this message translates to:
  /// **'Keine Standard-Checkliste vorhanden'**
  String get attendanceNoDefaultChecklist;

  /// attendance.noGroup
  ///
  /// In de, this message translates to:
  /// **'Keine Gruppe'**
  String get attendanceNoGroup;

  /// attendance.noPeople
  ///
  /// In de, this message translates to:
  /// **'Keine Personen vorhanden'**
  String get attendanceNoPeople;

  /// attendance.nobodyAssigned
  ///
  /// In de, this message translates to:
  /// **'Niemand zugewiesen'**
  String get attendanceNobodyAssigned;

  /// attendance.notStarted
  ///
  /// In de, this message translates to:
  /// **'Noch nicht begonnen'**
  String get attendanceNotStarted;

  /// attendance.noteAdded
  ///
  /// In de, this message translates to:
  /// **'Notiz hinzugefügt'**
  String get attendanceNoteAdded;

  /// attendance.notes
  ///
  /// In de, this message translates to:
  /// **'Notizen'**
  String get attendanceNotes;

  /// attendance.offline
  ///
  /// In de, this message translates to:
  /// **'Offline'**
  String get attendanceOffline;

  /// attendance.onlyNeutral
  ///
  /// In de, this message translates to:
  /// **'Nur Personen ohne Status'**
  String get attendanceOnlyNeutral;

  /// attendance.onlyNeutralHint
  ///
  /// In de, this message translates to:
  /// **'Sendet nur an Personen, die noch keine Rückmeldung gegeben haben'**
  String get attendanceOnlyNeutralHint;

  /// attendance.openProtocol
  ///
  /// In de, this message translates to:
  /// **'Protokoll öffnen'**
  String get attendanceOpenProtocol;

  /// attendance.otherPeople
  ///
  /// In de, this message translates to:
  /// **'Andere Personen'**
  String get attendanceOtherPeople;

  /// attendance.overdueDays
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Tag überfällig} other {{count} Tage überfällig}}'**
  String attendanceOverdueDays(num count);

  /// attendance.overdueHours
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Stunde überfällig} other {{count} Stunden überfällig}}'**
  String attendanceOverdueHours(num count);

  /// attendance.pending
  ///
  /// In de, this message translates to:
  /// **'{count} ausstehend'**
  String attendancePending(Object count);

  /// attendance.peopleAdded
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Person hinzugefügt} other {{count} Personen hinzugefügt}}'**
  String attendancePeopleAdded(num count);

  /// attendance.personRemoveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Entfernen der Person'**
  String get attendancePersonRemoveFailed;

  /// attendance.personRemoved
  ///
  /// In de, this message translates to:
  /// **'Person aus Anwesenheit entfernt'**
  String get attendancePersonRemoved;

  /// attendance.pictureFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim hinzufügen des Bildes, versuche es später erneut'**
  String get attendancePictureFailed;

  /// attendance.place
  ///
  /// In de, this message translates to:
  /// **'Ort'**
  String get attendancePlace;

  /// attendance.presentPeople
  ///
  /// In de, this message translates to:
  /// **'Anwesende'**
  String get attendancePresentPeople;

  /// attendance.protocol
  ///
  /// In de, this message translates to:
  /// **'Protokoll'**
  String get attendanceProtocol;

  /// attendance.published
  ///
  /// In de, this message translates to:
  /// **'Freigegeben'**
  String get attendancePublished;

  /// attendance.publishedOn
  ///
  /// In de, this message translates to:
  /// **'Freigegeben am {date}'**
  String attendancePublishedOn(Object date);

  /// attendance.readProtocol
  ///
  /// In de, this message translates to:
  /// **'Protokoll lesen'**
  String get attendanceReadProtocol;

  /// attendance.regFields
  ///
  /// In de, this message translates to:
  /// **'Anmeldefelder'**
  String get attendanceRegFields;

  /// attendance.regularlyUnavailableWithReason
  ///
  /// In de, this message translates to:
  /// **'Regelmäßig verhindert: {reason}'**
  String attendanceRegularlyUnavailableWithReason(Object reason);

  /// attendance.reload
  ///
  /// In de, this message translates to:
  /// **'Neu laden'**
  String get attendanceReload;

  /// attendance.reloadFailed
  ///
  /// In de, this message translates to:
  /// **'Neu laden fehlgeschlagen — bitte erneut versuchen.'**
  String get attendanceReloadFailed;

  /// attendance.reminderInfo
  ///
  /// In de, this message translates to:
  /// **'Die Erinnerung wird per App-Benachrichtigung und per E-Mail verschickt. Betreff und Nachricht können frei angepasst werden.'**
  String get attendanceReminderInfo;

  /// attendance.reminderSent
  ///
  /// In de, this message translates to:
  /// **'Erinnerung versendet'**
  String get attendanceReminderSent;

  /// attendance.reminderTitle
  ///
  /// In de, this message translates to:
  /// **'🔔 Erinnerung: {event}'**
  String attendanceReminderTitle(Object event);

  /// attendance.removeFolder
  ///
  /// In de, this message translates to:
  /// **'Ordner entfernen'**
  String get attendanceRemoveFolder;

  /// attendance.removePerson
  ///
  /// In de, this message translates to:
  /// **'Person entfernen'**
  String get attendanceRemovePerson;

  /// attendance.removePersonConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du {name} wirklich aus dieser Anwesenheit entfernen? Diese Aktion kann nicht rückgängig gemacht werden.'**
  String attendanceRemovePersonConfirm(Object name);

  /// attendance.requested
  ///
  /// In de, this message translates to:
  /// **'angefragt'**
  String get attendanceRequested;

  /// attendance.resetChecklist
  ///
  /// In de, this message translates to:
  /// **'Checkliste zurücksetzen'**
  String get attendanceResetChecklist;

  /// attendance.runSheetAgenda
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan & Tagesordnung'**
  String get attendanceRunSheetAgenda;

  /// attendance.selfSignedUp
  ///
  /// In de, this message translates to:
  /// **'selbst eingetragen'**
  String get attendanceSelfSignedUp;

  /// attendance.send
  ///
  /// In de, this message translates to:
  /// **'Versenden'**
  String get attendanceSend;

  /// attendance.sendFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Versenden'**
  String get attendanceSendFailed;

  /// attendance.sendReminder
  ///
  /// In de, this message translates to:
  /// **'Erinnerung versenden'**
  String get attendanceSendReminder;

  /// attendance.sendReminderShort
  ///
  /// In de, this message translates to:
  /// **'Erinnerung senden'**
  String get attendanceSendReminderShort;

  /// attendance.sending
  ///
  /// In de, this message translates to:
  /// **'Wird versendet...'**
  String get attendanceSending;

  /// attendance.setDeadline
  ///
  /// In de, this message translates to:
  /// **'Anmeldefrist setzen'**
  String get attendanceSetDeadline;

  /// attendance.setNeutral
  ///
  /// In de, this message translates to:
  /// **'Status neutral setzen'**
  String get attendanceSetNeutral;

  /// attendance.share
  ///
  /// In de, this message translates to:
  /// **'Teilen'**
  String get attendanceShare;

  /// attendance.shareRunSheet
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan teilen'**
  String get attendanceShareRunSheet;

  /// attendance.showPictures
  ///
  /// In de, this message translates to:
  /// **'Bilder anzeigen'**
  String get attendanceShowPictures;

  /// attendance.showRegFields
  ///
  /// In de, this message translates to:
  /// **'Anmeldefelder anzeigen'**
  String get attendanceShowRegFields;

  /// attendance.signedOut
  ///
  /// In de, this message translates to:
  /// **'abgemeldet'**
  String get attendanceSignedOut;

  /// attendance.songsCount
  ///
  /// In de, this message translates to:
  /// **'Werke ({count})'**
  String attendanceSongsCount(Object count);

  /// attendance.sorting
  ///
  /// In de, this message translates to:
  /// **'Sortierung'**
  String get attendanceSorting;

  /// attendance.staffing
  ///
  /// In de, this message translates to:
  /// **'Besetzung'**
  String get attendanceStaffing;

  /// attendance.start
  ///
  /// In de, this message translates to:
  /// **'Beginn'**
  String get attendanceStart;

  /// attendance.startChecklist
  ///
  /// In de, this message translates to:
  /// **'Checkliste starten'**
  String get attendanceStartChecklist;

  /// attendance.startLabel
  ///
  /// In de, this message translates to:
  /// **'Start'**
  String get attendanceStartLabel;

  /// attendance.startSession
  ///
  /// In de, this message translates to:
  /// **'Sitzung starten & protokollieren'**
  String get attendanceStartSession;

  /// attendance.statusChangeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Ändern des Anwesenheitsstatus, bitte versuche es später erneut'**
  String get attendanceStatusChangeFailed;

  /// attendance.statusFilter
  ///
  /// In de, this message translates to:
  /// **'Status-Filter'**
  String get attendanceStatusFilter;

  /// attendance.statusNotChanged
  ///
  /// In de, this message translates to:
  /// **'Der Status wurde bisher nicht verändert'**
  String get attendanceStatusNotChanged;

  /// attendance.statusOverview
  ///
  /// In de, this message translates to:
  /// **'Status-Übersicht'**
  String get attendanceStatusOverview;

  /// attendance.subject
  ///
  /// In de, this message translates to:
  /// **'Betreff'**
  String get attendanceSubject;

  /// attendance.subjectPlaceholder
  ///
  /// In de, this message translates to:
  /// **'z. B. 🔔 Erinnerung: Probe am 01.09.2026'**
  String get attendanceSubjectPlaceholder;

  /// attendance.tasksFromEvent
  ///
  /// In de, this message translates to:
  /// **'Aufgaben aus diesem Termin'**
  String get attendanceTasksFromEvent;

  /// attendance.telegramImage
  ///
  /// In de, this message translates to:
  /// **'Per Telegram senden (Bild)'**
  String get attendanceTelegramImage;

  /// attendance.telegramPdf
  ///
  /// In de, this message translates to:
  /// **'Per Telegram senden (PDF)'**
  String get attendanceTelegramPdf;

  /// attendance.telegramPdfA5
  ///
  /// In de, this message translates to:
  /// **'Per Telegram senden (PDF 2x A5)'**
  String get attendanceTelegramPdfA5;

  /// attendance.timeOClock
  ///
  /// In de, this message translates to:
  /// **'{time} Uhr'**
  String attendanceTimeOClock(Object time);

  /// attendance.toSong
  ///
  /// In de, this message translates to:
  /// **'Zum Werk'**
  String get attendanceToSong;

  /// attendance.todoText
  ///
  /// In de, this message translates to:
  /// **'To-Do Text...'**
  String get attendanceTodoText;

  /// attendance.totalPeople
  ///
  /// In de, this message translates to:
  /// **'Gesamt: {count, plural, one {{count} Person} other {{count} Personen}}'**
  String attendanceTotalPeople(num count);

  /// attendance.tryAgain
  ///
  /// In de, this message translates to:
  /// **'Bitte versuche es erneut.'**
  String get attendanceTryAgain;

  /// attendance.unassign
  ///
  /// In de, this message translates to:
  /// **'Austragen'**
  String get attendanceUnassign;

  /// attendance.unassignConfirm
  ///
  /// In de, this message translates to:
  /// **'Aus dem Dienst austragen?'**
  String get attendanceUnassignConfirm;

  /// attendance.uploadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hochladen'**
  String get attendanceUploadFailed;

  /// attendance.view
  ///
  /// In de, this message translates to:
  /// **'Ansicht'**
  String get attendanceView;

  /// attendance.whoChanged
  ///
  /// In de, this message translates to:
  /// **'Wer hat geändert?'**
  String get attendanceWhoChanged;

  /// audio.playFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Abspielen: {error}'**
  String audioPlayFailed(Object error);

  /// auth.confirmEmailFirst
  ///
  /// In de, this message translates to:
  /// **'Bitte bestätige zuerst deine E-Mail-Adresse.'**
  String get authConfirmEmailFirst;

  /// auth.confirmationResent
  ///
  /// In de, this message translates to:
  /// **'Bestätigungs-E-Mail wurde erneut gesendet'**
  String get authConfirmationResent;

  /// auth.invalidCredentials
  ///
  /// In de, this message translates to:
  /// **'Ungültige Anmeldedaten'**
  String get authInvalidCredentials;

  /// auth.resendConfirmationFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Senden der Bestätigungs-E-Mail'**
  String get authResendConfirmationFailed;

  /// auth.resetFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Zurücksetzen des Passworts'**
  String get authResetFailed;

  /// auth.resetRetry
  ///
  /// In de, this message translates to:
  /// **'Fehler beim zurücksetzen, versuche es noch einmal'**
  String get authResetRetry;

  /// auth.resetSent
  ///
  /// In de, this message translates to:
  /// **'E-Mail zum Zurücksetzen des Passworts wurde gesendet'**
  String get authResetSent;

  /// auth.userNotFound
  ///
  /// In de, this message translates to:
  /// **'Benutzer nicht gefunden'**
  String get authUserNotFound;

  /// bell.currentInstance
  ///
  /// In de, this message translates to:
  /// **'Aktuelle Instanz'**
  String get bellCurrentInstance;

  /// bell.deleteAll
  ///
  /// In de, this message translates to:
  /// **'Alle löschen'**
  String get bellDeleteAll;

  /// bell.deleteAllHeader
  ///
  /// In de, this message translates to:
  /// **'Alle Benachrichtigungen löschen?'**
  String get bellDeleteAllHeader;

  /// bell.deleteAllMessage
  ///
  /// In de, this message translates to:
  /// **'Alle Benachrichtigungen aus allen Instanzen werden gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.'**
  String get bellDeleteAllMessage;

  /// bell.mark
  ///
  /// In de, this message translates to:
  /// **'Markieren'**
  String get bellMark;

  /// bell.markAllHeader
  ///
  /// In de, this message translates to:
  /// **'Alle als gelesen markieren?'**
  String get bellMarkAllHeader;

  /// bell.markAllMessage
  ///
  /// In de, this message translates to:
  /// **'Alle Benachrichtigungen aus allen Instanzen werden als gelesen markiert.'**
  String get bellMarkAllMessage;

  /// bell.markAllRead
  ///
  /// In de, this message translates to:
  /// **'Alle gelesen'**
  String get bellMarkAllRead;

  /// bell.none
  ///
  /// In de, this message translates to:
  /// **'Keine Benachrichtigungen'**
  String get bellNone;

  /// bell.noneAvailable
  ///
  /// In de, this message translates to:
  /// **'Keine Benachrichtigungen vorhanden.'**
  String get bellNoneAvailable;

  /// bell.title
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen'**
  String get bellTitle;

  /// branding.flutter.replaceLogo
  ///
  /// In de, this message translates to:
  /// **'Logo ersetzen'**
  String get brandingFlutterReplaceLogo;

  /// branding.flutter.uploadLogo
  ///
  /// In de, this message translates to:
  /// **'Logo hochladen'**
  String get brandingFlutterUploadLogo;

  /// branding.intro
  ///
  /// In de, this message translates to:
  /// **'Logo und Text erscheinen dezent auf exportierten Plänen und Listen (PDF/Bild). Das Logo darf maximal 2 MB groß sein. Das Branding gilt für alle Instanzen der Organisation.'**
  String get brandingIntro;

  /// branding.logo
  ///
  /// In de, this message translates to:
  /// **'Logo'**
  String get brandingLogo;

  /// branding.logoRemoved
  ///
  /// In de, this message translates to:
  /// **'Logo entfernt. Speichern nicht vergessen.'**
  String get brandingLogoRemoved;

  /// branding.logoTooBig
  ///
  /// In de, this message translates to:
  /// **'Das Logo darf maximal 2MB groß sein.'**
  String get brandingLogoTooBig;

  /// branding.logoUploaded
  ///
  /// In de, this message translates to:
  /// **'Logo hochgeladen. Speichern nicht vergessen.'**
  String get brandingLogoUploaded;

  /// branding.orgOnly
  ///
  /// In de, this message translates to:
  /// **'Branding wird auf Organisationsebene verwaltet. Diese Instanz ist keiner Organisation zugeordnet.'**
  String get brandingOrgOnly;

  /// branding.removeLogo
  ///
  /// In de, this message translates to:
  /// **'Logo entfernen'**
  String get brandingRemoveLogo;

  /// branding.saved
  ///
  /// In de, this message translates to:
  /// **'Branding gespeichert.'**
  String get brandingSaved;

  /// branding.saving
  ///
  /// In de, this message translates to:
  /// **'Branding wird gespeichert...'**
  String get brandingSaving;

  /// branding.selectImage
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle eine Bilddatei aus.'**
  String get brandingSelectImage;

  /// branding.text
  ///
  /// In de, this message translates to:
  /// **'Branding-Text'**
  String get brandingText;

  /// branding.textPh
  ///
  /// In de, this message translates to:
  /// **'z.B. Verbandsname'**
  String get brandingTextPh;

  /// churchOverview.churches
  ///
  /// In de, this message translates to:
  /// **'Gemeinden'**
  String get churchOverviewChurches;

  /// churchOverview.noChurch
  ///
  /// In de, this message translates to:
  /// **'Ohne Gemeinde'**
  String get churchOverviewNoChurch;

  /// churchOverview.noPeople
  ///
  /// In de, this message translates to:
  /// **'Keine Personen vorhanden'**
  String get churchOverviewNoPeople;

  /// churchOverview.title
  ///
  /// In de, this message translates to:
  /// **'Gemeinde-Übersicht'**
  String get churchOverviewTitle;

  /// churchOverview.total
  ///
  /// In de, this message translates to:
  /// **'Gesamt'**
  String get churchOverviewTotal;

  /// churchOverview.unassigned
  ///
  /// In de, this message translates to:
  /// **'Ohne Zuordnung'**
  String get churchOverviewUnassigned;

  /// churchOverview.unknownChurch
  ///
  /// In de, this message translates to:
  /// **'Unbekannte Gemeinde'**
  String get churchOverviewUnknownChurch;

  /// common.all
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get commonAll;

  /// common.appleMaps
  ///
  /// In de, this message translates to:
  /// **'Apple Karten'**
  String get commonAppleMaps;

  /// common.apply
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get commonApply;

  /// common.back
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get commonBack;

  /// common.cancel
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get commonCancel;

  /// common.cannotUndo
  ///
  /// In de, this message translates to:
  /// **'Diese Aktion kann nicht rückgängig gemacht werden.'**
  String get commonCannotUndo;

  /// common.clef.c
  ///
  /// In de, this message translates to:
  /// **'Altschlüssel'**
  String get commonClefC;

  /// common.clef.f
  ///
  /// In de, this message translates to:
  /// **'Bassschlüssel'**
  String get commonClefF;

  /// common.clef.g
  ///
  /// In de, this message translates to:
  /// **'Violinschlüssel'**
  String get commonClefG;

  /// common.close
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get commonClose;

  /// common.confirm
  ///
  /// In de, this message translates to:
  /// **'Bestätigen'**
  String get commonConfirm;

  /// common.create
  ///
  /// In de, this message translates to:
  /// **'Anlegen'**
  String get commonCreate;

  /// common.createdAt
  ///
  /// In de, this message translates to:
  /// **'Erstellt am: {date}'**
  String commonCreatedAt(Object date);

  /// common.delete
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get commonDelete;

  /// common.edit
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get commonEdit;

  /// common.error
  ///
  /// In de, this message translates to:
  /// **'Fehler'**
  String get commonError;

  /// common.groupLabel.group
  ///
  /// In de, this message translates to:
  /// **'Gruppe'**
  String get commonGroupLabelGroup;

  /// common.groupLabel.instrument
  ///
  /// In de, this message translates to:
  /// **'Instrument'**
  String get commonGroupLabelInstrument;

  /// common.groupLabel.voice
  ///
  /// In de, this message translates to:
  /// **'Stimme'**
  String get commonGroupLabelVoice;

  /// common.history.archived
  ///
  /// In de, this message translates to:
  /// **'Archiviert'**
  String get commonHistoryArchived;

  /// common.history.groupChange
  ///
  /// In de, this message translates to:
  /// **'Wechsel'**
  String get commonHistoryGroupChange;

  /// common.history.paused
  ///
  /// In de, this message translates to:
  /// **'Pausiert'**
  String get commonHistoryPaused;

  /// common.history.returned
  ///
  /// In de, this message translates to:
  /// **'Reaktiviert'**
  String get commonHistoryReturned;

  /// common.history.unexcused
  ///
  /// In de, this message translates to:
  /// **'Unentschuldigt'**
  String get commonHistoryUnexcused;

  /// common.intlLocale
  ///
  /// In de, this message translates to:
  /// **'de-DE'**
  String get commonIntlLocale;

  /// common.loading
  ///
  /// In de, this message translates to:
  /// **'Wird geladen …'**
  String get commonLoading;

  /// common.next
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get commonNext;

  /// common.ngDate
  ///
  /// In de, this message translates to:
  /// **'dd.MM.yyyy'**
  String get commonNgDate;

  /// common.ngDayMonth
  ///
  /// In de, this message translates to:
  /// **'dd.MM.'**
  String get commonNgDayMonth;

  /// common.no
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get commonNo;

  /// common.ok
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// common.open
  ///
  /// In de, this message translates to:
  /// **'Öffnen'**
  String get commonOpen;

  /// common.other
  ///
  /// In de, this message translates to:
  /// **'Sonstiges'**
  String get commonOther;

  /// common.otherPlural
  ///
  /// In de, this message translates to:
  /// **'Sonstige'**
  String get commonOtherPlural;

  /// common.people
  ///
  /// In de, this message translates to:
  /// **'Personen'**
  String get commonPeople;

  /// common.persons
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Person} other {{count} Personen}}'**
  String commonPersons(num count);

  /// common.remove
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get commonRemove;

  /// common.roles.admin
  ///
  /// In de, this message translates to:
  /// **'Admin'**
  String get commonRolesAdmin;

  /// common.roles.helper
  ///
  /// In de, this message translates to:
  /// **'Helfer'**
  String get commonRolesHelper;

  /// common.roles.member
  ///
  /// In de, this message translates to:
  /// **'Mitglied'**
  String get commonRolesMember;

  /// common.roles.parent
  ///
  /// In de, this message translates to:
  /// **'Elternteil'**
  String get commonRolesParent;

  /// common.roles.responsible
  ///
  /// In de, this message translates to:
  /// **'Verantwortlicher'**
  String get commonRolesResponsible;

  /// common.roles.viewer
  ///
  /// In de, this message translates to:
  /// **'Beobachter'**
  String get commonRolesViewer;

  /// common.roles.voiceLeader
  ///
  /// In de, this message translates to:
  /// **'Stimmführer'**
  String get commonRolesVoiceLeader;

  /// common.roles.voiceLeaderHelper
  ///
  /// In de, this message translates to:
  /// **'Stimmführer & Helfer'**
  String get commonRolesVoiceLeaderHelper;

  /// common.save
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get commonSave;

  /// common.search
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get commonSearch;

  /// common.status.absent
  ///
  /// In de, this message translates to:
  /// **'Abwesend'**
  String get commonStatusAbsent;

  /// common.status.accepted
  ///
  /// In de, this message translates to:
  /// **'Zugesagt'**
  String get commonStatusAccepted;

  /// common.status.excused
  ///
  /// In de, this message translates to:
  /// **'Entschuldigt'**
  String get commonStatusExcused;

  /// common.status.late
  ///
  /// In de, this message translates to:
  /// **'Verspätet anwesend'**
  String get commonStatusLate;

  /// common.status.lateExcused
  ///
  /// In de, this message translates to:
  /// **'Verspätet entschuldigt'**
  String get commonStatusLateExcused;

  /// common.status.lateExcusedShort
  ///
  /// In de, this message translates to:
  /// **'Verspätet entsch.'**
  String get commonStatusLateExcusedShort;

  /// common.status.lateReported
  ///
  /// In de, this message translates to:
  /// **'Verspätung gemeldet'**
  String get commonStatusLateReported;

  /// common.status.lateShort
  ///
  /// In de, this message translates to:
  /// **'Verspätet'**
  String get commonStatusLateShort;

  /// common.status.neutral
  ///
  /// In de, this message translates to:
  /// **'Neutral'**
  String get commonStatusNeutral;

  /// common.status.present
  ///
  /// In de, this message translates to:
  /// **'Anwesend'**
  String get commonStatusPresent;

  /// common.unknown
  ///
  /// In de, this message translates to:
  /// **'Unbekannt'**
  String get commonUnknown;

  /// common.unknownError
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Fehler'**
  String get commonUnknownError;

  /// common.without
  ///
  /// In de, this message translates to:
  /// **'Ohne {list}'**
  String commonWithout(Object list);

  /// common.yes
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get commonYes;

  /// core.flutter.accessDenied
  ///
  /// In de, this message translates to:
  /// **'Zugriff verweigert'**
  String get coreFlutterAccessDenied;

  /// core.flutter.difficulty.easy
  ///
  /// In de, this message translates to:
  /// **'Leicht'**
  String get coreFlutterDifficultyEasy;

  /// core.flutter.difficulty.hard
  ///
  /// In de, this message translates to:
  /// **'Schwer'**
  String get coreFlutterDifficultyHard;

  /// core.flutter.difficulty.medium
  ///
  /// In de, this message translates to:
  /// **'Mittel'**
  String get coreFlutterDifficultyMedium;

  /// core.flutter.difficulty.veryHard
  ///
  /// In de, this message translates to:
  /// **'Sehr schwer'**
  String get coreFlutterDifficultyVeryHard;

  /// core.flutter.errorWith
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String coreFlutterErrorWith(Object error);

  /// core.flutter.export.attendanceHeader
  ///
  /// In de, this message translates to:
  /// **'{name} Anwesenheit Stand: {date}'**
  String coreFlutterExportAttendanceHeader(Object name, Object date);

  /// core.flutter.export.endAt
  ///
  /// In de, this message translates to:
  /// **'Ende: {time} Uhr'**
  String coreFlutterExportEndAt(Object time);

  /// core.flutter.export.open
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get coreFlutterExportOpen;

  /// core.flutter.export.pdfRenderFailed
  ///
  /// In de, this message translates to:
  /// **'PDF konnte nicht gerendert werden'**
  String get coreFlutterExportPdfRenderFailed;

  /// core.flutter.export.playerListHeader
  ///
  /// In de, this message translates to:
  /// **'{name} Spielerliste Stand: {date}'**
  String coreFlutterExportPlayerListHeader(Object name, Object date);

  /// core.flutter.export.playerListSheet
  ///
  /// In de, this message translates to:
  /// **'Spielerliste'**
  String get coreFlutterExportPlayerListSheet;

  /// core.flutter.export.rate
  ///
  /// In de, this message translates to:
  /// **'Quote'**
  String get coreFlutterExportRate;

  /// core.flutter.export.rehearsalProgramme
  ///
  /// In de, this message translates to:
  /// **'Probenprogramm'**
  String get coreFlutterExportRehearsalProgramme;

  /// core.flutter.feedback.anonymousHint
  ///
  /// In de, this message translates to:
  /// **'Deine Daten werden nicht mitgesendet'**
  String get coreFlutterFeedbackAnonymousHint;

  /// core.flutter.feedback.questionIntro
  ///
  /// In de, this message translates to:
  /// **'Hast du eine Frage oder brauchst Hilfe?'**
  String get coreFlutterFeedbackQuestionIntro;

  /// core.flutter.feedback.questionRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte gib eine Frage ein'**
  String get coreFlutterFeedbackQuestionRequired;

  /// core.flutter.feedback.ratingIntro
  ///
  /// In de, this message translates to:
  /// **'Wie gefällt dir die App?'**
  String get coreFlutterFeedbackRatingIntro;

  /// core.flutter.fileBytesUnavailable
  ///
  /// In de, this message translates to:
  /// **'Datei-Bytes nicht verfügbar'**
  String get coreFlutterFileBytesUnavailable;

  /// core.flutter.filePathUnavailable
  ///
  /// In de, this message translates to:
  /// **'Dateipfad nicht verfügbar'**
  String get coreFlutterFilePathUnavailable;

  /// core.flutter.history.approved
  ///
  /// In de, this message translates to:
  /// **'Genehmigt'**
  String get coreFlutterHistoryApproved;

  /// core.flutter.history.copiedFrom
  ///
  /// In de, this message translates to:
  /// **'Kopiert von'**
  String get coreFlutterHistoryCopiedFrom;

  /// core.flutter.history.copiedTo
  ///
  /// In de, this message translates to:
  /// **'Kopiert an'**
  String get coreFlutterHistoryCopiedTo;

  /// core.flutter.history.critical
  ///
  /// In de, this message translates to:
  /// **'Kritisch markiert'**
  String get coreFlutterHistoryCritical;

  /// core.flutter.history.declined
  ///
  /// In de, this message translates to:
  /// **'Abgelehnt'**
  String get coreFlutterHistoryDeclined;

  /// core.flutter.history.instrumentChange
  ///
  /// In de, this message translates to:
  /// **'Instrumentenwechsel'**
  String get coreFlutterHistoryInstrumentChange;

  /// core.flutter.history.returned
  ///
  /// In de, this message translates to:
  /// **'Zurückgekehrt'**
  String get coreFlutterHistoryReturned;

  /// core.flutter.history.transferredFrom
  ///
  /// In de, this message translates to:
  /// **'Übertragen von'**
  String get coreFlutterHistoryTransferredFrom;

  /// core.flutter.history.transferredTo
  ///
  /// In de, this message translates to:
  /// **'Übertragen an'**
  String get coreFlutterHistoryTransferredTo;

  /// core.flutter.history.unpaused
  ///
  /// In de, this message translates to:
  /// **'Pause beendet'**
  String get coreFlutterHistoryUnpaused;

  /// core.flutter.holiday
  ///
  /// In de, this message translates to:
  /// **'Feiertag'**
  String get coreFlutterHoliday;

  /// core.flutter.import.birthdayUnreadable
  ///
  /// In de, this message translates to:
  /// **'Geburtsdatum \"{value}\" konnte nicht gelesen werden'**
  String coreFlutterImportBirthdayUnreadable(Object value);

  /// core.flutter.import.categoryNotFound
  ///
  /// In de, this message translates to:
  /// **'Kategorie \"{name}\" nicht gefunden'**
  String coreFlutterImportCategoryNotFound(Object name);

  /// core.flutter.import.difficultyInvalid
  ///
  /// In de, this message translates to:
  /// **'Schwierigkeit \"{value}\" muss 1, 2 oder 3 sein'**
  String coreFlutterImportDifficultyInvalid(Object value);

  /// core.flutter.import.duplicateEmailInFile
  ///
  /// In de, this message translates to:
  /// **'Doppelte E-Mail in der Datei'**
  String get coreFlutterImportDuplicateEmailInFile;

  /// core.flutter.import.duplicateNumberInFile
  ///
  /// In de, this message translates to:
  /// **'Doppelte Nummer in der Datei'**
  String get coreFlutterImportDuplicateNumberInFile;

  /// core.flutter.import.emailExists
  ///
  /// In de, this message translates to:
  /// **'E-Mail existiert bereits in dieser Instanz'**
  String get coreFlutterImportEmailExists;

  /// core.flutter.import.emailInvalid
  ///
  /// In de, this message translates to:
  /// **'E-Mail \"{email}\" sieht ungültig aus'**
  String coreFlutterImportEmailInvalid(Object email);

  /// core.flutter.import.joinedUnreadable
  ///
  /// In de, this message translates to:
  /// **'Eintrittsdatum \"{value}\" konnte nicht gelesen werden'**
  String coreFlutterImportJoinedUnreadable(Object value);

  /// core.flutter.import.linkInvalid
  ///
  /// In de, this message translates to:
  /// **'Link \"{link}\" sieht ungültig aus'**
  String coreFlutterImportLinkInvalid(Object link);

  /// core.flutter.import.nameRequired
  ///
  /// In de, this message translates to:
  /// **'Vor- und Nachname sind erforderlich'**
  String get coreFlutterImportNameRequired;

  /// core.flutter.import.numberRequired
  ///
  /// In de, this message translates to:
  /// **'Nummer ist erforderlich und muss eine Zahl sein'**
  String get coreFlutterImportNumberRequired;

  /// core.flutter.import.songNameRequired
  ///
  /// In de, this message translates to:
  /// **'Name ist erforderlich'**
  String get coreFlutterImportSongNameRequired;

  /// core.flutter.import.songNumberExists
  ///
  /// In de, this message translates to:
  /// **'Liednummer existiert bereits in dieser Instanz'**
  String get coreFlutterImportSongNumberExists;

  /// core.flutter.invalidCopyCount
  ///
  /// In de, this message translates to:
  /// **'Ungültige Kopienanzahl'**
  String get coreFlutterInvalidCopyCount;

  /// core.flutter.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden'**
  String get coreFlutterLoadFailed;

  /// core.flutter.newVersionAvailable
  ///
  /// In de, this message translates to:
  /// **'Neue Version verfügbar'**
  String get coreFlutterNewVersionAvailable;

  /// core.flutter.noBranding
  ///
  /// In de, this message translates to:
  /// **'Kein Branding'**
  String get coreFlutterNoBranding;

  /// core.flutter.noConnection
  ///
  /// In de, this message translates to:
  /// **'Keine Internetverbindung vorhanden'**
  String get coreFlutterNoConnection;

  /// core.flutter.noCopiesSelected
  ///
  /// In de, this message translates to:
  /// **'Keine Kopien zum Drucken ausgewählt'**
  String get coreFlutterNoCopiesSelected;

  /// core.flutter.noEmailAddress
  ///
  /// In de, this message translates to:
  /// **'Keine E-Mail-Adresse vorhanden'**
  String get coreFlutterNoEmailAddress;

  /// core.flutter.noFilesDownloaded
  ///
  /// In de, this message translates to:
  /// **'Keine Dateien konnten heruntergeladen werden'**
  String get coreFlutterNoFilesDownloaded;

  /// core.flutter.noFilesToDownload
  ///
  /// In de, this message translates to:
  /// **'Keine Dateien zum Herunterladen'**
  String get coreFlutterNoFilesToDownload;

  /// core.flutter.noInstanceSelected
  ///
  /// In de, this message translates to:
  /// **'Keine Instanz ausgewählt'**
  String get coreFlutterNoInstanceSelected;

  /// core.flutter.noResponse
  ///
  /// In de, this message translates to:
  /// **'Keine Antwort erhalten'**
  String get coreFlutterNoResponse;

  /// core.flutter.noResultsFor
  ///
  /// In de, this message translates to:
  /// **'Keine Ergebnisse für \"{query}\"'**
  String coreFlutterNoResultsFor(Object query);

  /// core.flutter.noTenantSelected
  ///
  /// In de, this message translates to:
  /// **'Kein Tenant ausgewählt'**
  String get coreFlutterNoTenantSelected;

  /// core.flutter.noVersionHistory
  ///
  /// In de, this message translates to:
  /// **'Keine Versionshistorie verfügbar'**
  String get coreFlutterNoVersionHistory;

  /// core.flutter.notLoggedIn
  ///
  /// In de, this message translates to:
  /// **'Nicht eingeloggt'**
  String get coreFlutterNotLoggedIn;

  /// core.flutter.notSignedIn
  ///
  /// In de, this message translates to:
  /// **'Nicht angemeldet'**
  String get coreFlutterNotSignedIn;

  /// core.flutter.offlineQueueSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Die Änderung konnte nicht offline gespeichert werden'**
  String get coreFlutterOfflineQueueSaveFailed;

  /// core.flutter.openExternally
  ///
  /// In de, this message translates to:
  /// **'Extern öffnen'**
  String get coreFlutterOpenExternally;

  /// core.flutter.pausedLower
  ///
  /// In de, this message translates to:
  /// **'pausiert'**
  String get coreFlutterPausedLower;

  /// core.flutter.pausedUntil
  ///
  /// In de, this message translates to:
  /// **'bis {date}'**
  String coreFlutterPausedUntil(Object date);

  /// core.flutter.pdfLoadFailed
  ///
  /// In de, this message translates to:
  /// **'PDF konnte nicht geladen werden (HTTP {status})'**
  String coreFlutterPdfLoadFailed(Object status);

  /// core.flutter.personHasNoId
  ///
  /// In de, this message translates to:
  /// **'Person hat keine ID'**
  String get coreFlutterPersonHasNoId;

  /// core.flutter.plan.dayN
  ///
  /// In de, this message translates to:
  /// **'Tag {day}'**
  String coreFlutterPlanDayN(Object day);

  /// core.flutter.plan.startsInHours
  ///
  /// In de, this message translates to:
  /// **'beginnt in {hours} Std.'**
  String coreFlutterPlanStartsInHours(Object hours);

  /// core.flutter.plan.startsInHoursMin
  ///
  /// In de, this message translates to:
  /// **'beginnt in {hours} Std. {min} Min.'**
  String coreFlutterPlanStartsInHoursMin(Object hours, Object min);

  /// core.flutter.plan.startsInMin
  ///
  /// In de, this message translates to:
  /// **'beginnt in {min} Min.'**
  String coreFlutterPlanStartsInMin(Object min);

  /// core.flutter.plan.startsSoon
  ///
  /// In de, this message translates to:
  /// **'beginnt gleich'**
  String get coreFlutterPlanStartsSoon;

  /// core.flutter.registration
  ///
  /// In de, this message translates to:
  /// **'Anmeldung'**
  String get coreFlutterRegistration;

  /// core.flutter.repo.accountCreateFailed
  ///
  /// In de, this message translates to:
  /// **'Der Account konnte nicht erstellt werden.'**
  String get coreFlutterRepoAccountCreateFailed;

  /// core.flutter.repo.alreadyAdmin
  ///
  /// In de, this message translates to:
  /// **'Diese Person ist bereits Admin.'**
  String get coreFlutterRepoAlreadyAdmin;

  /// core.flutter.repo.categoryCreateFailed
  ///
  /// In de, this message translates to:
  /// **'Kategorie konnte nicht erstellt werden'**
  String get coreFlutterRepoCategoryCreateFailed;

  /// core.flutter.repo.categoryNotFound
  ///
  /// In de, this message translates to:
  /// **'Gruppenkategorie mit ID {id} nicht gefunden'**
  String coreFlutterRepoCategoryNotFound(Object id);

  /// core.flutter.repo.changeRoleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Ändern der Rolle: {error}'**
  String coreFlutterRepoChangeRoleFailed(Object error);

  /// core.flutter.repo.eventExistsOnDate
  ///
  /// In de, this message translates to:
  /// **'Ein Termin an diesem Datum existiert bereits'**
  String get coreFlutterRepoEventExistsOnDate;

  /// core.flutter.repo.eventNotInTenant
  ///
  /// In de, this message translates to:
  /// **'Termin gehört nicht zur aktuellen Instanz'**
  String get coreFlutterRepoEventNotInTenant;

  /// core.flutter.repo.foreignTenantDenied
  ///
  /// In de, this message translates to:
  /// **'Zugriff auf fremde Instanz verweigert'**
  String get coreFlutterRepoForeignTenantDenied;

  /// core.flutter.repo.groupCreateFailed
  ///
  /// In de, this message translates to:
  /// **'Gruppe konnte nicht erstellt werden'**
  String get coreFlutterRepoGroupCreateFailed;

  /// core.flutter.repo.groupHasPlayers
  ///
  /// In de, this message translates to:
  /// **'Gruppe kann nicht gelöscht werden: {count} Spieler sind noch zugewiesen'**
  String coreFlutterRepoGroupHasPlayers(Object count);

  /// core.flutter.repo.groupNotFound
  ///
  /// In de, this message translates to:
  /// **'Gruppe mit ID {id} nicht gefunden'**
  String coreFlutterRepoGroupNotFound(Object id);

  /// core.flutter.repo.meetingExistsOnDate
  ///
  /// In de, this message translates to:
  /// **'Eine Besprechung an diesem Datum existiert bereits'**
  String get coreFlutterRepoMeetingExistsOnDate;

  /// core.flutter.repo.noPermissionInTenant
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung in dieser Instanz'**
  String get coreFlutterRepoNoPermissionInTenant;

  /// core.flutter.repo.noValidPersons
  ///
  /// In de, this message translates to:
  /// **'Keine gültigen Personen'**
  String get coreFlutterRepoNoValidPersons;

  /// core.flutter.repo.personsNotInTenant
  ///
  /// In de, this message translates to:
  /// **'Personen gehören nicht zur aktuellen Instanz'**
  String get coreFlutterRepoPersonsNotInTenant;

  /// core.flutter.repo.rootNotDeletable
  ///
  /// In de, this message translates to:
  /// **'Root kann nicht gelöscht werden.'**
  String get coreFlutterRepoRootNotDeletable;

  /// core.flutter.repo.songNotFoundOrDenied
  ///
  /// In de, this message translates to:
  /// **'Song nicht gefunden oder Zugriff verweigert'**
  String get coreFlutterRepoSongNotFoundOrDenied;

  /// core.flutter.repo.tenantNotLinked
  ///
  /// In de, this message translates to:
  /// **'Instanz ist nicht verknüpft'**
  String get coreFlutterRepoTenantNotLinked;

  /// core.flutter.repo.typeInUse
  ///
  /// In de, this message translates to:
  /// **'Typ kann nicht gelöscht werden: Wird von {count} Anwesenheit(en) verwendet'**
  String coreFlutterRepoTypeInUse(Object count);

  /// core.flutter.repo.unlinkAccountFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Entfernen der Account-Verknüpfung: {error}'**
  String coreFlutterRepoUnlinkAccountFailed(Object error);

  /// core.flutter.rolePermissionWithoutId
  ///
  /// In de, this message translates to:
  /// **'Rollenberechtigung ohne ID'**
  String get coreFlutterRolePermissionWithoutId;

  /// core.flutter.router.goHome
  ///
  /// In de, this message translates to:
  /// **'Zur Startseite'**
  String get coreFlutterRouterGoHome;

  /// core.flutter.router.invalidAttendanceId
  ///
  /// In de, this message translates to:
  /// **'Ungültige Anwesenheits-ID'**
  String get coreFlutterRouterInvalidAttendanceId;

  /// core.flutter.router.invalidPersonId
  ///
  /// In de, this message translates to:
  /// **'Ungültige Person-ID'**
  String get coreFlutterRouterInvalidPersonId;

  /// core.flutter.router.invalidTenantId
  ///
  /// In de, this message translates to:
  /// **'Ungültige Instanz-ID'**
  String get coreFlutterRouterInvalidTenantId;

  /// core.flutter.router.pageNotFound
  ///
  /// In de, this message translates to:
  /// **'Seite nicht gefunden: {path}'**
  String coreFlutterRouterPageNotFound(Object path);

  /// core.flutter.rule.overall
  ///
  /// In de, this message translates to:
  /// **'insgesamt'**
  String get coreFlutterRuleOverall;

  /// core.flutter.rule.sinceSeasonStart
  ///
  /// In de, this message translates to:
  /// **'seit Saisonstart'**
  String get coreFlutterRuleSinceSeasonStart;

  /// core.flutter.rule.statusN
  ///
  /// In de, this message translates to:
  /// **'Status {n}'**
  String coreFlutterRuleStatusN(Object n);

  /// core.flutter.schoolHolidays
  ///
  /// In de, this message translates to:
  /// **'Schulferien'**
  String get coreFlutterSchoolHolidays;

  /// core.flutter.searchHint
  ///
  /// In de, this message translates to:
  /// **'Suchen...'**
  String get coreFlutterSearchHint;

  /// core.flutter.sheetMusic
  ///
  /// In de, this message translates to:
  /// **'Notenblatt'**
  String get coreFlutterSheetMusic;

  /// core.flutter.shift.freeRange
  ///
  /// In de, this message translates to:
  /// **'Frei ({start} - {end})'**
  String coreFlutterShiftFreeRange(Object start, Object end);

  /// core.flutter.shift.workRange
  ///
  /// In de, this message translates to:
  /// **'Arbeit ({start} - {end}, {hours}h)'**
  String coreFlutterShiftWorkRange(Object start, Object end, Object hours);

  /// core.flutter.songFiles
  ///
  /// In de, this message translates to:
  /// **'Song-Dateien'**
  String get coreFlutterSongFiles;

  /// core.flutter.songNotFound
  ///
  /// In de, this message translates to:
  /// **'Song wurde nicht gefunden oder bereits gelöscht'**
  String get coreFlutterSongNotFound;

  /// core.flutter.update
  ///
  /// In de, this message translates to:
  /// **'Aktualisieren'**
  String get coreFlutterUpdate;

  /// core.flutter.voices
  ///
  /// In de, this message translates to:
  /// **'Stimmen'**
  String get coreFlutterVoices;

  /// core.flutter.xlsUnsupported
  ///
  /// In de, this message translates to:
  /// **'Das alte Excel-Format (.xls) wird nicht unterstützt. Bitte als .xlsx oder .csv speichern.'**
  String get coreFlutterXlsUnsupported;

  /// core.flutter.zipFailed
  ///
  /// In de, this message translates to:
  /// **'ZIP konnte nicht erstellt werden'**
  String get coreFlutterZipFailed;

  /// dashSettings.cards
  ///
  /// In de, this message translates to:
  /// **'Karten'**
  String get dashSettingsCards;

  /// dashSettings.flutter.reorder
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge ändern'**
  String get dashSettingsFlutterReorder;

  /// dashSettings.flutter.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern: {error}'**
  String dashSettingsFlutterSaveFailed(Object error);

  /// dashSettings.reorderHint
  ///
  /// In de, this message translates to:
  /// **'Tippe auf das Symbol oben rechts, um die Reihenfolge per Drag & Drop anzupassen.'**
  String get dashSettingsReorderHint;

  /// dashSettings.reset
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get dashSettingsReset;

  /// dashSettings.showTab
  ///
  /// In de, this message translates to:
  /// **'Dashboard-Tab anzeigen'**
  String get dashSettingsShowTab;

  /// dashSettings.tab
  ///
  /// In de, this message translates to:
  /// **'Tab'**
  String get dashSettingsTab;

  /// dateDialog.changeDate
  ///
  /// In de, this message translates to:
  /// **'Datum ändern'**
  String get dateDialogChangeDate;

  /// dateDialog.changeFailed
  ///
  /// In de, this message translates to:
  /// **'Datum konnte nicht geändert werden'**
  String get dateDialogChangeFailed;

  /// dateDialog.createFailed
  ///
  /// In de, this message translates to:
  /// **'Termin konnte nicht angelegt werden'**
  String get dateDialogCreateFailed;

  /// dateDialog.created
  ///
  /// In de, this message translates to:
  /// **'Termin am {date} angelegt'**
  String dateDialogCreated(Object date);

  /// dateDialog.fromToday
  ///
  /// In de, this message translates to:
  /// **'Bitte ein Datum ab heute wählen'**
  String get dateDialogFromToday;

  /// dateDialog.keep
  ///
  /// In de, this message translates to:
  /// **'Behalten'**
  String get dateDialogKeep;

  /// dateDialog.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Termin konnte nicht geladen werden'**
  String get dateDialogLoadFailed;

  /// dateDialog.moveTo
  ///
  /// In de, this message translates to:
  /// **'Auf welchen Tag soll der Termin verschoben werden?'**
  String get dateDialogMoveTo;

  /// dateDialog.moved
  ///
  /// In de, this message translates to:
  /// **'Termin auf {date} verschoben'**
  String dateDialogMoved(Object date);

  /// dateDialog.noProtocolType
  ///
  /// In de, this message translates to:
  /// **'Kein Termintyp mit Protokoll & Tagesordnung vorhanden'**
  String get dateDialogNoProtocolType;

  /// dateDialog.reset
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get dateDialogReset;

  /// dateDialog.resetStatus
  ///
  /// In de, this message translates to:
  /// **'Status zurücksetzen?'**
  String get dateDialogResetStatus;

  /// dateDialog.resetStatusMessage
  ///
  /// In de, this message translates to:
  /// **'Nicht alle stehen auf „{status}“. Sollen mit der Verschiebung alle auf den Standardstatus zurückgesetzt werden? Abwesenheiten am neuen Tag werden danach wieder eingetragen.'**
  String dateDialogResetStatusMessage(Object status);

  /// dateDialog.whichDay
  ///
  /// In de, this message translates to:
  /// **'An welchem Tag findet der Termin statt?'**
  String get dateDialogWhichDay;

  /// dateDialog.whichType
  ///
  /// In de, this message translates to:
  /// **'Welcher Termintyp?'**
  String get dateDialogWhichType;

  /// db.accountDisabled
  ///
  /// In de, this message translates to:
  /// **'Dein Konto wurde deaktiviert. Bitte wende dich an den Administrator deiner Instanz.'**
  String get dbAccountDisabled;

  /// db.addDefaultTypesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen der Standard Anwesenheitstypen'**
  String get dbAddDefaultTypesFailed;

  /// db.addParentFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim hinzufügen des Elternteils.'**
  String get dbAddParentFailed;

  /// db.addViewerFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim hinzufügen des Beobachters.'**
  String get dbAddViewerFailed;

  /// db.chooseInstance.header
  ///
  /// In de, this message translates to:
  /// **'Instanz auswählen'**
  String get dbChooseInstanceHeader;

  /// db.chooseInstance.message
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle die Instanz aus, die du öffnen möchtest:'**
  String get dbChooseInstanceMessage;

  /// db.codeExpired
  ///
  /// In de, this message translates to:
  /// **'Der Code ist abgelaufen. Bitte fordere einen neuen an.'**
  String get dbCodeExpired;

  /// db.codeInvalid
  ///
  /// In de, this message translates to:
  /// **'Der Code ist ungültig. Bitte überprüfe deine Eingabe.'**
  String get dbCodeInvalid;

  /// db.codeSendFailed
  ///
  /// In de, this message translates to:
  /// **'Der Code konnte nicht gesendet werden. Bitte versuche es erneut.'**
  String get dbCodeSendFailed;

  /// db.codeSent
  ///
  /// In de, this message translates to:
  /// **'Wir haben dir einen Code per E-Mail gesendet.'**
  String get dbCodeSent;

  /// db.createAccountFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen des Accounts'**
  String get dbCreateAccountFailed;

  /// db.createAccountFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen des Accounts: {error}'**
  String dbCreateAccountFailedWith(Object error);

  /// db.createInstanceFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen der Instanz, bitte versuche es später erneut.'**
  String get dbCreateInstanceFailed;

  /// db.createUserFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen des Benutzers, bitte versuche es später erneut.'**
  String get dbCreateUserFailed;

  /// db.deleteAccountFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Kontos'**
  String get dbDeleteAccountFailed;

  /// db.deleteInstanceFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen der Instanz, bitte versuche es später erneut.'**
  String get dbDeleteInstanceFailed;

  /// db.deleteParentFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Elternteils'**
  String get dbDeleteParentFailed;

  /// db.deleteViewerFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Beobachters'**
  String get dbDeleteViewerFailed;

  /// db.demoRestricted
  ///
  /// In de, this message translates to:
  /// **'Diese Funktion ist im Demo-Modus nicht verfügbar.'**
  String get dbDemoRestricted;

  /// db.emailExists
  ///
  /// In de, this message translates to:
  /// **'Deine E-Mail-Adresse existiert bereits. Bitte melde dich an.'**
  String get dbEmailExists;

  /// db.enterCorrectData
  ///
  /// In de, this message translates to:
  /// **'Bitte gib die richtigen Daten an!'**
  String get dbEnterCorrectData;

  /// db.favoriteFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Setzen des Favoriten, bitte versuche es später erneut.'**
  String get dbFavoriteFailed;

  /// db.instanceCreated
  ///
  /// In de, this message translates to:
  /// **'Instanz wurde erfolgreich erstellt!'**
  String get dbInstanceCreated;

  /// db.instanceDeleted
  ///
  /// In de, this message translates to:
  /// **'Instanz wurde erfolgreich gelöscht!'**
  String get dbInstanceDeleted;

  /// db.invalidEmail
  ///
  /// In de, this message translates to:
  /// **'Ungültige E-Mail Adresse'**
  String get dbInvalidEmail;

  /// db.invalidPassword
  ///
  /// In de, this message translates to:
  /// **'Ungültiges Passwort'**
  String get dbInvalidPassword;

  /// db.loadAttendanceTypeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden des Anwesenheitstyps'**
  String get dbLoadAttendanceTypeFailed;

  /// db.loadChildrenFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Kinder'**
  String get dbLoadChildrenFailed;

  /// db.loadGroupMembersFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Gruppenteilnehmer'**
  String get dbLoadGroupMembersFailed;

  /// db.loadPeopleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Personen'**
  String get dbLoadPeopleFailed;

  /// db.loadRoleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Rolle'**
  String get dbLoadRoleFailed;

  /// db.loadTenantsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Tenants'**
  String get dbLoadTenantsFailed;

  /// db.loadTenantsFailed2
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Mandanten'**
  String get dbLoadTenantsFailed2;

  /// db.loadUserFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden des Benutzers'**
  String get dbLoadUserFailed;

  /// db.loginFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Anmelden'**
  String get dbLoginFailed;

  /// db.mainGroupNotFound
  ///
  /// In de, this message translates to:
  /// **'Hauptgruppe nicht gefunden'**
  String get dbMainGroupNotFound;

  /// db.noAccount
  ///
  /// In de, this message translates to:
  /// **'Kein Konto mit dieser E-Mail-Adresse gefunden. Bitte registriere dich zuerst.'**
  String get dbNoAccount;

  /// db.noPersonFound
  ///
  /// In de, this message translates to:
  /// **'Keine Person gefunden'**
  String get dbNoPersonFound;

  /// db.notifyUserFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Informieren des Benutzers'**
  String get dbNotifyUserFailed;

  /// db.otpUnavailable
  ///
  /// In de, this message translates to:
  /// **'Anmeldung per Code ist derzeit nicht möglich.'**
  String get dbOtpUnavailable;

  /// db.passwordChangeFailed
  ///
  /// In de, this message translates to:
  /// **'Passwort konnte nicht geändert werden. Bitte versuche es erneut.'**
  String get dbPasswordChangeFailed;

  /// db.passwordSameAsOld
  ///
  /// In de, this message translates to:
  /// **'Das neue Passwort darf nicht mit dem alten übereinstimmen.'**
  String get dbPasswordSameAsOld;

  /// db.passwordTooWeak
  ///
  /// In de, this message translates to:
  /// **'Das Passwort ist zu schwach. Bitte wähle ein sichereres Passwort.'**
  String get dbPasswordTooWeak;

  /// db.passwordUpdated
  ///
  /// In de, this message translates to:
  /// **'Passwort wurde erfolgreich aktualisiert'**
  String get dbPasswordUpdated;

  /// db.pauseOtherFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Pausieren in anderer Instanz'**
  String get dbPauseOtherFailed;

  /// db.personExistsWithEmail
  ///
  /// In de, this message translates to:
  /// **'In der Zielinstanz existiert bereits eine Person mit der E-Mail-Adresse \"{email}\".'**
  String dbPersonExistsWithEmail(Object email);

  /// db.personExistsWithName
  ///
  /// In de, this message translates to:
  /// **'In der Zielinstanz existiert bereits eine Person mit dem Namen \"{name}\".'**
  String dbPersonExistsWithName(Object name);

  /// db.registerFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Registrieren'**
  String get dbRegisterFailed;

  /// db.removeAuthEmailFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Entfernen der E-Mail aus der Authentifizierung'**
  String get dbRemoveAuthEmailFailed;

  /// db.removeFromTenantFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Accounts vom Mandanten'**
  String get dbRemoveFromTenantFailed;

  /// db.resetPasswordFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Zurücksetzen des Passworts. Versuche es später erneut'**
  String get dbResetPasswordFailed;

  /// db.resetPasswordSent
  ///
  /// In de, this message translates to:
  /// **'Eine E-Mail mit weiteren Anweisungen wurde dir zugesandt'**
  String get dbResetPasswordSent;

  /// db.roleParent
  ///
  /// In de, this message translates to:
  /// **'Elternteil'**
  String get dbRoleParent;

  /// db.roleViewer
  ///
  /// In de, this message translates to:
  /// **'Beobachter'**
  String get dbRoleViewer;

  /// db.sessionExpired
  ///
  /// In de, this message translates to:
  /// **'Deine Sitzung ist abgelaufen. Bitte fordere den Link zum Zurücksetzen erneut an.'**
  String get dbSessionExpired;

  /// db.tooManyAttempts
  ///
  /// In de, this message translates to:
  /// **'Zu viele Versuche. Bitte versuche es später erneut.'**
  String get dbTooManyAttempts;

  /// db.tooManyAttemptsWait
  ///
  /// In de, this message translates to:
  /// **'Zu viele Versuche. Bitte warte einen Moment und versuche es erneut.'**
  String get dbTooManyAttemptsWait;

  /// db.tooManyLogins
  ///
  /// In de, this message translates to:
  /// **'Zu viele Anmeldeversuche. Bitte versuche es später erneut.'**
  String get dbTooManyLogins;

  /// db.tooManyRequests
  ///
  /// In de, this message translates to:
  /// **'Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.'**
  String get dbTooManyRequests;

  /// db.updateChurchFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Kirchenzuordnung'**
  String get dbUpdateChurchFailed;

  /// db.updatePlayerFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim updaten des Spielers'**
  String get dbUpdatePlayerFailed;

  /// db.updateProfileFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren des Profils'**
  String get dbUpdateProfileFailed;

  /// db.updateRoleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Benutzerrolle'**
  String get dbUpdateRoleFailed;

  /// db.updateSongHistoryFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren des Song-Verlaufs'**
  String get dbUpdateSongHistoryFailed;

  /// db.updateUserFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Updaten des Benutzers'**
  String get dbUpdateUserFailed;

  /// db.updateUserFailed2
  ///
  /// In de, this message translates to:
  /// **'Fehler beim updaten des Benutzers'**
  String get dbUpdateUserFailed2;

  /// db.userAlreadyInInstanceAs
  ///
  /// In de, this message translates to:
  /// **'Der Benutzer ist bereits in dieser Instanz: {name} ({role})'**
  String dbUserAlreadyInInstanceAs(Object name, Object role);

  /// db.userAlreadyInTenant
  ///
  /// In de, this message translates to:
  /// **'Der Benutzer ist bereits in diesem Mandanten'**
  String get dbUserAlreadyInTenant;

  /// db.userAlreadyInTenantAs
  ///
  /// In de, this message translates to:
  /// **'Der Benutzer ist bereits in diesem Mandanten: {name} ({role})'**
  String dbUserAlreadyInTenantAs(Object name, Object role);

  /// db.weakPasswordRequirements
  ///
  /// In de, this message translates to:
  /// **'Das Passwort erfüllt nicht die Sicherheitsanforderungen.'**
  String get dbWeakPasswordRequirements;

  /// db.wrongCredentials
  ///
  /// In de, this message translates to:
  /// **'E-Mail oder Passwort falsch. Falls du kein Passwort gesetzt hast, nutze den Anmelde-Code per E-Mail.'**
  String get dbWrongCredentials;

  /// defaults.showAllInfoText
  ///
  /// In de, this message translates to:
  /// **'Du bist bei diesem Termin nicht dabei.'**
  String get defaultsShowAllInfoText;

  /// defaults.types.meeting
  ///
  /// In de, this message translates to:
  /// **'Treffen'**
  String get defaultsTypesMeeting;

  /// defaults.types.performance
  ///
  /// In de, this message translates to:
  /// **'Vortrag'**
  String get defaultsTypesPerformance;

  /// defaults.types.rehearsal
  ///
  /// In de, this message translates to:
  /// **'Probe'**
  String get defaultsTypesRehearsal;

  /// defaults.types.rehearsalPlan
  ///
  /// In de, this message translates to:
  /// **'Probenplan'**
  String get defaultsTypesRehearsalPlan;

  /// deleteAccount.access
  ///
  /// In de, this message translates to:
  /// **'Dein Zugang zur App'**
  String get deleteAccountAccess;

  /// deleteAccount.attendance
  ///
  /// In de, this message translates to:
  /// **'Alle deine Anwesenheitsdaten'**
  String get deleteAccountAttendance;

  /// deleteAccount.cannotUndo
  ///
  /// In de, this message translates to:
  /// **'Diese Aktion kann <strong>nicht rückgängig</strong> gemacht werden.'**
  String get deleteAccountCannotUndo;

  /// deleteAccount.code
  ///
  /// In de, this message translates to:
  /// **'Bestätigungscode'**
  String get deleteAccountCode;

  /// deleteAccount.codePlaceholder
  ///
  /// In de, this message translates to:
  /// **'Code eingeben'**
  String get deleteAccountCodePlaceholder;

  /// deleteAccount.confirm
  ///
  /// In de, this message translates to:
  /// **'Konto wirklich löschen?'**
  String get deleteAccountConfirm;

  /// deleteAccount.confirmMessage
  ///
  /// In de, this message translates to:
  /// **'Dein Konto und alle damit verbundenen Daten werden unwiderruflich entfernt. Diese Aktion kann nicht rückgängig gemacht werden.'**
  String get deleteAccountConfirmMessage;

  /// deleteAccount.deleteFinal
  ///
  /// In de, this message translates to:
  /// **'Endgültig löschen'**
  String get deleteAccountDeleteFinal;

  /// deleteAccount.deleteForever
  ///
  /// In de, this message translates to:
  /// **'Konto endgültig löschen'**
  String get deleteAccountDeleteForever;

  /// deleteAccount.deleted
  ///
  /// In de, this message translates to:
  /// **'Dein Konto wurde gelöscht.'**
  String get deleteAccountDeleted;

  /// deleteAccount.deleting
  ///
  /// In de, this message translates to:
  /// **'Konto wird gelöscht...'**
  String get deleteAccountDeleting;

  /// deleteAccount.enterCode
  ///
  /// In de, this message translates to:
  /// **'Bitte gib zur Bestätigung den folgenden Code ein:'**
  String get deleteAccountEnterCode;

  /// deleteAccount.failed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen: {error}'**
  String deleteAccountFailed(Object error);

  /// deleteAccount.intro
  ///
  /// In de, this message translates to:
  /// **'Wenn du dein Konto löschst, werden <strong>alle</strong> deine Daten unwiderruflich entfernt:'**
  String get deleteAccountIntro;

  /// deleteAccount.memberships
  ///
  /// In de, this message translates to:
  /// **'Alle deine Mitgliedschaften in jeder Instanz'**
  String get deleteAccountMemberships;

  /// deleteAccount.profile
  ///
  /// In de, this message translates to:
  /// **'Dein Profil und Passbild'**
  String get deleteAccountProfile;

  /// deleteAccount.title
  ///
  /// In de, this message translates to:
  /// **'Konto löschen'**
  String get deleteAccountTitle;

  /// deleteAccount.warning
  ///
  /// In de, this message translates to:
  /// **'Achtung'**
  String get deleteAccountWarning;

  /// duty.addRule
  ///
  /// In de, this message translates to:
  /// **'Regel hinzufügen'**
  String get dutyAddRule;

  /// duty.allAssigned
  ///
  /// In de, this message translates to:
  /// **'Alle aus dem Personenkreis sind schon eingeteilt.'**
  String get dutyAllAssigned;

  /// duty.allTypes
  ///
  /// In de, this message translates to:
  /// **'alle Termintypen'**
  String get dutyAllTypes;

  /// duty.allTypesHint
  ///
  /// In de, this message translates to:
  /// **'Ohne Auswahl gilt die Regel für alle Termintypen.'**
  String get dutyAllTypesHint;

  /// duty.alsoPlanned
  ///
  /// In de, this message translates to:
  /// **'Auch geplante Termine?'**
  String get dutyAlsoPlanned;

  /// duty.alsoPlannedButton
  ///
  /// In de, this message translates to:
  /// **'Auch geplante'**
  String get dutyAlsoPlannedButton;

  /// duty.alsoPlannedOther
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} schon geplanter Termin passt} other {{count} schon geplante Termine passen}} zu dieser Regel ({preview}). Soll {name} dort als entschuldigt eingetragen werden? Termine mit eigener Antwort oder Einteilung bleiben unverändert.'**
  String dutyAlsoPlannedOther(num count, Object preview, Object name);

  /// duty.alsoPlannedSelf
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} schon geplanter Termin passt} other {{count} schon geplante Termine passen}} zu dieser Regel ({preview}). Sollst du dort als entschuldigt eingetragen werden? Termine mit eigener Antwort oder Einteilung bleiben unverändert.'**
  String dutyAlsoPlannedSelf(num count, Object preview);

  /// duty.assignHint
  ///
  /// In de, this message translates to:
  /// **'Sortiert nach Anzahl Dienste. Eingeteilte bekommen sofort eine Push-Nachricht und müssen bestätigen.'**
  String get dutyAssignHint;

  /// duty.assignName
  ///
  /// In de, this message translates to:
  /// **'{name} einteilen'**
  String dutyAssignName(Object name);

  /// duty.assignPeople
  ///
  /// In de, this message translates to:
  /// **'{count} Personen einteilen'**
  String dutyAssignPeople(Object count);

  /// duty.assignedToast
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Dienst eingeteilt} other {{count} Dienste eingeteilt}}. Alle bekommen eine Push-Nachricht.'**
  String dutyAssignedToast(num count);

  /// duty.assigning
  ///
  /// In de, this message translates to:
  /// **'Teile ein…'**
  String get dutyAssigning;

  /// duty.calculate
  ///
  /// In de, this message translates to:
  /// **'Vorschlag berechnen'**
  String get dutyCalculate;

  /// duty.childrenHourPlaceholder
  ///
  /// In de, this message translates to:
  /// **'z. B. Kinderstunde'**
  String get dutyChildrenHourPlaceholder;

  /// duty.choosePerson
  ///
  /// In de, this message translates to:
  /// **'Person wählen'**
  String get dutyChoosePerson;

  /// duty.chooseTypeMin
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle mindestens einen Termintyp'**
  String get dutyChooseTypeMin;

  /// duty.chooseWeekday
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle mindestens einen Wochentag'**
  String get dutyChooseWeekday;

  /// duty.declinedToast
  ///
  /// In de, this message translates to:
  /// **'Abgesagt, das Team wird informiert.'**
  String get dutyDeclinedToast;

  /// duty.deleteRule
  ///
  /// In de, this message translates to:
  /// **'Regel löschen'**
  String get dutyDeleteRule;

  /// duty.deleteRuleConfirm
  ///
  /// In de, this message translates to:
  /// **'Regel löschen?'**
  String get dutyDeleteRuleConfirm;

  /// duty.deleteRuleMessage
  ///
  /// In de, this message translates to:
  /// **'Bereits eingetragene Abmeldungen bleiben bestehen.'**
  String get dutyDeleteRuleMessage;

  /// duty.distributeHint
  ///
  /// In de, this message translates to:
  /// **'Nur offene Plätze werden gefüllt, bestehende Einteilungen bleiben. Wer abgesagt hat oder regelmäßig verhindert ist, wird nicht eingeteilt. Wer bisher am wenigsten Dienste hat, kommt zuerst dran.'**
  String get dutyDistributeHint;

  /// duty.distributing
  ///
  /// In de, this message translates to:
  /// **'Verteile Dienste…'**
  String get dutyDistributing;

  /// duty.dutiesCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Dienst} other {{count} Dienste}}'**
  String dutyDutiesCount(num count);

  /// duty.dutiesPerPerson
  ///
  /// In de, this message translates to:
  /// **'Dienste pro Person im Zeitraum'**
  String get dutyDutiesPerPerson;

  /// duty.duty
  ///
  /// In de, this message translates to:
  /// **'Dienst'**
  String get dutyDuty;

  /// duty.eventTypes
  ///
  /// In de, this message translates to:
  /// **'Termintypen'**
  String get dutyEventTypes;

  /// duty.eventsAdjusted
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Termin angepasst} other {{count} Termine angepasst}}'**
  String dutyEventsAdjusted(num count);

  /// duty.flutter.allFilled
  ///
  /// In de, this message translates to:
  /// **'alles besetzt'**
  String get dutyFlutterAllFilled;

  /// duty.flutter.declineFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Abmelden'**
  String get dutyFlutterDeclineFailed;

  /// duty.flutter.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen'**
  String get dutyFlutterDeleteFailed;

  /// duty.flutter.errorWith
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String dutyFlutterErrorWith(Object error);

  /// duty.flutter.nameRequested
  ///
  /// In de, this message translates to:
  /// **'{name} (angefragt)'**
  String dutyFlutterNameRequested(Object name);

  /// duty.flutter.nobodyAssigned
  ///
  /// In de, this message translates to:
  /// **'noch niemand eingeteilt'**
  String get dutyFlutterNobodyAssigned;

  /// duty.flutter.nothingToDistribute
  ///
  /// In de, this message translates to:
  /// **'Nichts zu verteilen'**
  String get dutyFlutterNothingToDistribute;

  /// duty.flutter.plannedNew
  ///
  /// In de, this message translates to:
  /// **'(+{count} neu)'**
  String dutyFlutterPlannedNew(Object count);

  /// duty.flutter.saveAssignments
  ///
  /// In de, this message translates to:
  /// **'{count} Einteilungen speichern'**
  String dutyFlutterSaveAssignments(Object count);

  /// duty.flutter.timeOClock
  ///
  /// In de, this message translates to:
  /// **'{time} Uhr'**
  String dutyFlutterTimeOClock(Object time);

  /// duty.flutter.unassignMessage
  ///
  /// In de, this message translates to:
  /// **'{name} ist dann nicht mehr eingeteilt.'**
  String dutyFlutterUnassignMessage(Object name);

  /// duty.forWhichTypes
  ///
  /// In de, this message translates to:
  /// **'Für welche Termintypen?'**
  String get dutyForWhichTypes;

  /// duty.from
  ///
  /// In de, this message translates to:
  /// **'Von'**
  String get dutyFrom;

  /// duty.greyHint
  ///
  /// In de, this message translates to:
  /// **'Grau = schon eingeteilt, bleibt unverändert.'**
  String get dutyGreyHint;

  /// duty.inMonth
  ///
  /// In de, this message translates to:
  /// **' im {month}'**
  String dutyInMonth(Object month);

  /// duty.maxPerPerson
  ///
  /// In de, this message translates to:
  /// **'Höchstens pro Person'**
  String get dutyMaxPerPerson;

  /// duty.myRequestsTitle
  ///
  /// In de, this message translates to:
  /// **'Deine Dienste: bitte bestätigen'**
  String get dutyMyRequestsTitle;

  /// duty.noDutyEvents
  ///
  /// In de, this message translates to:
  /// **'Im Zeitraum gibt es keine Termine mit Dienst-Modus.'**
  String get dutyNoDutyEvents;

  /// duty.noRuleOther
  ///
  /// In de, this message translates to:
  /// **'Noch keine Regel. Trag ein, an welchen Wochentagen die Person grundsätzlich nicht kann, z. B. mittwochs wegen der Kinderstunde.'**
  String get dutyNoRuleOther;

  /// duty.noRuleSelf
  ///
  /// In de, this message translates to:
  /// **'Noch keine Regel. Trag ein, an welchen Wochentagen du grundsätzlich nicht kannst, z. B. mittwochs wegen der Kinderstunde.'**
  String get dutyNoRuleSelf;

  /// duty.nobody
  ///
  /// In de, this message translates to:
  /// **'Niemand (Platz offen lassen)'**
  String get dutyNobody;

  /// duty.nobodyElse
  ///
  /// In de, this message translates to:
  /// **'Niemand sonst ist für diesen Termin verfügbar'**
  String get dutyNobodyElse;

  /// duty.notTwiceSameDay
  ///
  /// In de, this message translates to:
  /// **'Nicht zweimal am selben Tag'**
  String get dutyNotTwiceSameDay;

  /// duty.onlyNew
  ///
  /// In de, this message translates to:
  /// **'Nur neue Termine'**
  String get dutyOnlyNew;

  /// duty.open
  ///
  /// In de, this message translates to:
  /// **'offen'**
  String get dutyOpen;

  /// duty.overbooked
  ///
  /// In de, this message translates to:
  /// **'Du hast mehr Personen gewählt als Plätze frei sind. Der Dienst ist dann überbesetzt.'**
  String get dutyOverbooked;

  /// duty.period
  ///
  /// In de, this message translates to:
  /// **'Zeitraum'**
  String get dutyPeriod;

  /// duty.placesFree
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Platz frei} other {{count} Plätze frei}}'**
  String dutyPlacesFree(num count);

  /// duty.plannedSummary
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Einteilung} other {{count} Einteilungen}} geplant.'**
  String dutyPlannedSummary(num count);

  /// duty.plannedSummaryMissing
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Einteilung} other {{count} Einteilungen}} geplant, {missing, plural, one {{missing} Platz bleibt} other {{missing} Plätze bleiben}} offen.'**
  String dutyPlannedSummaryMissing(num count, num missing);

  /// duty.reasonOptional
  ///
  /// In de, this message translates to:
  /// **'Grund (optional)'**
  String get dutyReasonOptional;

  /// duty.redistribute
  ///
  /// In de, this message translates to:
  /// **'Neu verteilen'**
  String get dutyRedistribute;

  /// duty.ruleHint
  ///
  /// In de, this message translates to:
  /// **'Neue Termine an diesen Tagen werden automatisch als entschuldigt eingetragen. Bei Diensten wirst du dann nicht eingeteilt.'**
  String get dutyRuleHint;

  /// duty.rules
  ///
  /// In de, this message translates to:
  /// **'Regeln'**
  String get dutyRules;

  /// duty.sameDay
  ///
  /// In de, this message translates to:
  /// **'· am selben Tag schon dran'**
  String get dutySameDay;

  /// duty.saved
  ///
  /// In de, this message translates to:
  /// **'Gespeichert'**
  String get dutySaved;

  /// duty.swap
  ///
  /// In de, this message translates to:
  /// **'{name} tauschen'**
  String dutySwap(Object name);

  /// duty.tapToSwap
  ///
  /// In de, this message translates to:
  /// **'Tippe auf einen Namen zum Tauschen.'**
  String get dutyTapToSwap;

  /// duty.to
  ///
  /// In de, this message translates to:
  /// **'Bis'**
  String get dutyTo;

  /// duty.unlimited
  ///
  /// In de, this message translates to:
  /// **'unbefristet'**
  String get dutyUnlimited;

  /// duty.until
  ///
  /// In de, this message translates to:
  /// **'bis {date}'**
  String dutyUntil(Object date);

  /// duty.validUntil
  ///
  /// In de, this message translates to:
  /// **'Gültig bis (optional)'**
  String get dutyValidUntil;

  /// duty.weekdays
  ///
  /// In de, this message translates to:
  /// **'Wochentage'**
  String get dutyWeekdays;

  /// editor.agendaDesc
  ///
  /// In de, this message translates to:
  /// **'Tagesordnungspunkt einfügen'**
  String get editorAgendaDesc;

  /// editor.bold
  ///
  /// In de, this message translates to:
  /// **'Fett'**
  String get editorBold;

  /// editor.bulletDesc
  ///
  /// In de, this message translates to:
  /// **'Ungeordnete Liste'**
  String get editorBulletDesc;

  /// editor.bulletList
  ///
  /// In de, this message translates to:
  /// **'Aufzählung'**
  String get editorBulletList;

  /// editor.formatting
  ///
  /// In de, this message translates to:
  /// **'Formatierung'**
  String get editorFormatting;

  /// editor.h1
  ///
  /// In de, this message translates to:
  /// **'Überschrift 1'**
  String get editorH1;

  /// editor.h1Desc
  ///
  /// In de, this message translates to:
  /// **'Große Überschrift'**
  String get editorH1Desc;

  /// editor.h2
  ///
  /// In de, this message translates to:
  /// **'Überschrift 2'**
  String get editorH2;

  /// editor.h2Desc
  ///
  /// In de, this message translates to:
  /// **'Mittlere Überschrift'**
  String get editorH2Desc;

  /// editor.heading
  ///
  /// In de, this message translates to:
  /// **'Überschrift'**
  String get editorHeading;

  /// editor.italic
  ///
  /// In de, this message translates to:
  /// **'Kursiv'**
  String get editorItalic;

  /// editor.link
  ///
  /// In de, this message translates to:
  /// **'Link'**
  String get editorLink;

  /// editor.linkText
  ///
  /// In de, this message translates to:
  /// **'Angezeigter Text (optional)'**
  String get editorLinkText;

  /// editor.messagePlaceholder
  ///
  /// In de, this message translates to:
  /// **'Nachricht schreiben …'**
  String get editorMessagePlaceholder;

  /// editor.newTask
  ///
  /// In de, this message translates to:
  /// **'/aufgabe – Neue Aufgabe'**
  String get editorNewTask;

  /// editor.newTaskDesc
  ///
  /// In de, this message translates to:
  /// **'Aufgabe erstellen und verknüpfen'**
  String get editorNewTaskDesc;

  /// editor.notesPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Tippe hier, um Notizen zu schreiben …'**
  String get editorNotesPlaceholder;

  /// editor.orderedDesc
  ///
  /// In de, this message translates to:
  /// **'Geordnete Liste'**
  String get editorOrderedDesc;

  /// editor.orderedList
  ///
  /// In de, this message translates to:
  /// **'Nummerierte Liste'**
  String get editorOrderedList;

  /// editor.strike
  ///
  /// In de, this message translates to:
  /// **'Durchgestrichen'**
  String get editorStrike;

  /// editor.underline
  ///
  /// In de, this message translates to:
  /// **'Unterstrichen'**
  String get editorUnderline;

  /// editor.undo
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get editorUndo;

  /// excuse.customOption
  ///
  /// In de, this message translates to:
  /// **'Sonstiger Grund (Text)'**
  String get excuseCustomOption;

  /// excuse.late
  ///
  /// In de, this message translates to:
  /// **'Verspätung'**
  String get excuseLate;

  /// excuse.minChars
  ///
  /// In de, this message translates to:
  /// **'Mindestens 5 Zeichen eingeben...'**
  String get excuseMinChars;

  /// excuse.reason
  ///
  /// In de, this message translates to:
  /// **'Grund'**
  String get excuseReason;

  /// excuse.signOut
  ///
  /// In de, this message translates to:
  /// **'Abmeldung'**
  String get excuseSignOut;

  /// export.addExtraField
  ///
  /// In de, this message translates to:
  /// **'Extrafeld hinzufügen'**
  String get exportAddExtraField;

  /// export.addField
  ///
  /// In de, this message translates to:
  /// **'Feld hinzufügen'**
  String get exportAddField;

  /// export.asc
  ///
  /// In de, this message translates to:
  /// **'Aufsteigend (A–Z)'**
  String get exportAsc;

  /// export.attendance
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit'**
  String get exportAttendance;

  /// export.attendanceFile
  ///
  /// In de, this message translates to:
  /// **'{name}_{date}_Anwesenheit.xlsx'**
  String exportAttendanceFile(Object name, Object date);

  /// export.attendanceFileAsOf
  ///
  /// In de, this message translates to:
  /// **'{name}_Anwesenheit_Stand_{date}'**
  String exportAttendanceFileAsOf(Object name, Object date);

  /// export.attendancePercent
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit %'**
  String get exportAttendancePercent;

  /// export.attendanceTitle
  ///
  /// In de, this message translates to:
  /// **'{name} Anwesenheit'**
  String exportAttendanceTitle(Object name);

  /// export.church
  ///
  /// In de, this message translates to:
  /// **'Gemeinde'**
  String get exportChurch;

  /// export.desc
  ///
  /// In de, this message translates to:
  /// **'Absteigend (Z–A)'**
  String get exportDesc;

  /// export.duration
  ///
  /// In de, this message translates to:
  /// **'Dauer'**
  String get exportDuration;

  /// export.export
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get exportExport;

  /// export.exportType
  ///
  /// In de, this message translates to:
  /// **'Export-Typ'**
  String get exportExportType;

  /// export.fields
  ///
  /// In de, this message translates to:
  /// **'Felder'**
  String get exportFields;

  /// export.firstName
  ///
  /// In de, this message translates to:
  /// **'Vorname'**
  String get exportFirstName;

  /// export.flutter.columnName
  ///
  /// In de, this message translates to:
  /// **'Spaltenname'**
  String get exportFlutterColumnName;

  /// export.flutter.customFieldEmpty
  ///
  /// In de, this message translates to:
  /// **'Eigenes Feld (leer)'**
  String get exportFlutterCustomFieldEmpty;

  /// export.flutter.failedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Export: {error}'**
  String exportFlutterFailedWith(Object error);

  /// export.flutter.pdfLimitHint
  ///
  /// In de, this message translates to:
  /// **'PDF-Export ist auf die letzten 8 Termine begrenzt. Für alle Termine der Saison nutze den Excel-Export.'**
  String get exportFlutterPdfLimitHint;

  /// export.flutter.success
  ///
  /// In de, this message translates to:
  /// **'Export erfolgreich'**
  String get exportFlutterSuccess;

  /// export.group
  ///
  /// In de, this message translates to:
  /// **'Gruppe'**
  String get exportGroup;

  /// export.lastName
  ///
  /// In de, this message translates to:
  /// **'Nachname'**
  String get exportLastName;

  /// export.noPlan
  ///
  /// In de, this message translates to:
  /// **'Kein Plan verfügbar'**
  String get exportNoPlan;

  /// export.notes
  ///
  /// In de, this message translates to:
  /// **'Bemerkung'**
  String get exportNotes;

  /// export.order
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge'**
  String get exportOrder;

  /// export.performer
  ///
  /// In de, this message translates to:
  /// **'Ausführung'**
  String get exportPerformer;

  /// export.playerListFile
  ///
  /// In de, this message translates to:
  /// **'{name}_Spielerliste_Stand_{date}'**
  String exportPlayerListFile(Object name, Object date);

  /// export.playerListTitle
  ///
  /// In de, this message translates to:
  /// **'{name} Spielerliste'**
  String exportPlayerListTitle(Object name);

  /// export.players
  ///
  /// In de, this message translates to:
  /// **'Spieler'**
  String get exportPlayers;

  /// export.programmeItem
  ///
  /// In de, this message translates to:
  /// **'Programmpunkt'**
  String get exportProgrammeItem;

  /// export.runSheet
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan'**
  String get exportRunSheet;

  /// export.sortBy
  ///
  /// In de, this message translates to:
  /// **'Sortieren nach'**
  String get exportSortBy;

  /// export.status
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get exportStatus;

  /// export.time
  ///
  /// In de, this message translates to:
  /// **'Uhrzeit'**
  String get exportTime;

  /// export.title
  ///
  /// In de, this message translates to:
  /// **'Daten exportieren'**
  String get exportTitle;

  /// extraFields.addNew
  ///
  /// In de, this message translates to:
  /// **'Neues Feld hinzufügen'**
  String get extraFieldsAddNew;

  /// extraFields.addOption
  ///
  /// In de, this message translates to:
  /// **'Bitte füge mindestens eine Option für das Auswahlfeld hinzu.'**
  String get extraFieldsAddOption;

  /// extraFields.allNeedName
  ///
  /// In de, this message translates to:
  /// **'Alle Zusatzfelder müssen einen Namen haben.'**
  String get extraFieldsAllNeedName;

  /// extraFields.asChip
  ///
  /// In de, this message translates to:
  /// **'Als Chip'**
  String get extraFieldsAsChip;

  /// extraFields.church
  ///
  /// In de, this message translates to:
  /// **'BFECG Gemeinde'**
  String get extraFieldsChurch;

  /// extraFields.defaultOptional
  ///
  /// In de, this message translates to:
  /// **'Standardwert (optional)'**
  String get extraFieldsDefaultOptional;

  /// extraFields.defaultValue
  ///
  /// In de, this message translates to:
  /// **'Standardwert'**
  String get extraFieldsDefaultValue;

  /// extraFields.deleteField
  ///
  /// In de, this message translates to:
  /// **'Zusatzfeld löschen?'**
  String get extraFieldsDeleteField;

  /// extraFields.deleteFieldMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du das Zusatzfeld „{name}“ wirklich löschen?'**
  String extraFieldsDeleteFieldMessage(Object name);

  /// extraFields.deleteOption
  ///
  /// In de, this message translates to:
  /// **'Option löschen?'**
  String get extraFieldsDeleteOption;

  /// extraFields.deleteOptionMessage
  ///
  /// In de, this message translates to:
  /// **'Wenn du die Option „{option}“ löschst, werden alle betroffenen Datensätze auf den Standardwert zurückgesetzt.'**
  String extraFieldsDeleteOptionMessage(Object option);

  /// extraFields.display
  ///
  /// In de, this message translates to:
  /// **'Anzeige in Listen'**
  String get extraFieldsDisplay;

  /// extraFields.displayLine
  ///
  /// In de, this message translates to:
  /// **'Anzeige: {mode}'**
  String extraFieldsDisplayLine(Object mode);

  /// extraFields.editable
  ///
  /// In de, this message translates to:
  /// **'Von Mitgliedern bearbeitbar'**
  String get extraFieldsEditable;

  /// extraFields.editableHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, damit Mitglieder den Wert selbst ändern können.'**
  String get extraFieldsEditableHelper;

  /// extraFields.editableSuffix
  ///
  /// In de, this message translates to:
  /// **' (bearbeitbar)'**
  String get extraFieldsEditableSuffix;

  /// extraFields.flutter.firstOptionDefault
  ///
  /// In de, this message translates to:
  /// **'Erste Option ist der Standardwert'**
  String get extraFieldsFlutterFirstOptionDefault;

  /// extraFields.flutter.leaveMessage
  ///
  /// In de, this message translates to:
  /// **'Du hast ungespeicherte Änderungen. Möchtest du die Seite trotzdem verlassen?'**
  String get extraFieldsFlutterLeaveMessage;

  /// extraFields.forPersons
  ///
  /// In de, this message translates to:
  /// **'Zusätzliche Felder für Personen'**
  String get extraFieldsForPersons;

  /// extraFields.forSongs
  ///
  /// In de, this message translates to:
  /// **'Zusätzliche Felder für Werke'**
  String get extraFieldsForSongs;

  /// extraFields.idEmpty
  ///
  /// In de, this message translates to:
  /// **'Die ID des Zusatzfeldes darf nicht leer sein.'**
  String get extraFieldsIdEmpty;

  /// extraFields.idExists
  ///
  /// In de, this message translates to:
  /// **'Ein Zusatzfeld mit dieser ID existiert bereits. Bitte wähle einen anderen Namen.'**
  String get extraFieldsIdExists;

  /// extraFields.invalidName
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen gültigen Namen für das Zusatzfeld ein.'**
  String get extraFieldsInvalidName;

  /// extraFields.noOptions
  ///
  /// In de, this message translates to:
  /// **'Keine Optionen'**
  String get extraFieldsNoOptions;

  /// extraFields.noOptionsSelected
  ///
  /// In de, this message translates to:
  /// **'Keine Optionen ausgewählt'**
  String get extraFieldsNoOptionsSelected;

  /// extraFields.noneYet
  ///
  /// In de, this message translates to:
  /// **'Es wurden noch keine zusätzlichen Felder hinzugefügt.'**
  String get extraFieldsNoneYet;

  /// extraFields.number
  ///
  /// In de, this message translates to:
  /// **'Zahl'**
  String get extraFieldsNumber;

  /// extraFields.optionsEmpty
  ///
  /// In de, this message translates to:
  /// **'Optionen dürfen nicht leer sein.'**
  String get extraFieldsOptionsEmpty;

  /// extraFields.optionsEmptyIn
  ///
  /// In de, this message translates to:
  /// **'Die Optionen im Feld „{name}“ dürfen nicht leer sein.'**
  String extraFieldsOptionsEmptyIn(Object name);

  /// extraFields.personsUpdated
  ///
  /// In de, this message translates to:
  /// **'{count} Personen aktualisiert'**
  String extraFieldsPersonsUpdated(Object count);

  /// extraFields.resetAll
  ///
  /// In de, this message translates to:
  /// **'Alle Werte auf Standard zurücksetzen'**
  String get extraFieldsResetAll;

  /// extraFields.resetValues
  ///
  /// In de, this message translates to:
  /// **'Werte zurücksetzen?'**
  String get extraFieldsResetValues;

  /// extraFields.resetValuesMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du alle Werte des Feldes „{name}“ auf den Standardwert zurücksetzen? Dies kann nicht rückgängig gemacht werden!'**
  String extraFieldsResetValuesMessage(Object name);

  /// extraFields.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern'**
  String get extraFieldsSaveFailed;

  /// extraFields.saved
  ///
  /// In de, this message translates to:
  /// **'Felder gespeichert'**
  String get extraFieldsSaved;

  /// extraFields.saving
  ///
  /// In de, this message translates to:
  /// **'Felder werden gespeichert...'**
  String get extraFieldsSaving;

  /// extraFields.select
  ///
  /// In de, this message translates to:
  /// **'Auswahl'**
  String get extraFieldsSelect;

  /// extraFields.selectNeedsOption
  ///
  /// In de, this message translates to:
  /// **'Das Auswahlfeld „{name}“ muss mindestens eine Option haben.'**
  String extraFieldsSelectNeedsOption(Object name);

  /// extraFields.textarea
  ///
  /// In de, this message translates to:
  /// **'Textbereich'**
  String get extraFieldsTextarea;

  /// extraFields.title
  ///
  /// In de, this message translates to:
  /// **'Zusatzfelder'**
  String get extraFieldsTitle;

  /// extraFields.typeLine
  ///
  /// In de, this message translates to:
  /// **'Typ: {type}'**
  String extraFieldsTypeLine(Object type);

  /// extraFields.underName
  ///
  /// In de, this message translates to:
  /// **'Unter dem Namen'**
  String get extraFieldsUnderName;

  /// extraFields.valuePh
  ///
  /// In de, this message translates to:
  /// **'Wert eingeben...'**
  String get extraFieldsValuePh;

  /// extraFields.visible
  ///
  /// In de, this message translates to:
  /// **'Für Mitglieder sichtbar'**
  String get extraFieldsVisible;

  /// extraFields.visibleHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, damit Mitglieder dieses Feld in ihren Stammdaten sehen können.'**
  String get extraFieldsVisibleHelper;

  /// extraFields.yesNo
  ///
  /// In de, this message translates to:
  /// **'Ja/Nein'**
  String get extraFieldsYesNo;

  /// files.almostFull
  ///
  /// In de, this message translates to:
  /// **' · fast voll'**
  String get filesAlmostFull;

  /// files.andMore
  ///
  /// In de, this message translates to:
  /// **' und {count} weitere'**
  String filesAndMore(Object count);

  /// files.ascending
  ///
  /// In de, this message translates to:
  /// **'aufsteigend'**
  String get filesAscending;

  /// files.changedAt
  ///
  /// In de, this message translates to:
  /// **'· Geändert: {date}'**
  String filesChangedAt(Object date);

  /// files.connectTelegram
  ///
  /// In de, this message translates to:
  /// **'Bitte verbinde zuerst Telegram in den Benachrichtigungen.'**
  String get filesConnectTelegram;

  /// files.create
  ///
  /// In de, this message translates to:
  /// **'Erstellen'**
  String get filesCreate;

  /// files.createFolder
  ///
  /// In de, this message translates to:
  /// **'Ordner erstellen'**
  String get filesCreateFolder;

  /// files.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Löschen fehlgeschlagen: {error}'**
  String filesDeleteFailed(Object error);

  /// files.deleteFile
  ///
  /// In de, this message translates to:
  /// **'Datei löschen?'**
  String get filesDeleteFile;

  /// files.deleteFolder
  ///
  /// In de, this message translates to:
  /// **'Ordner löschen?'**
  String get filesDeleteFolder;

  /// files.deleteMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du {name} wirklich löschen?'**
  String filesDeleteMessage(Object name);

  /// files.deleted
  ///
  /// In de, this message translates to:
  /// **'Eintrag wurde gelöscht.'**
  String get filesDeleted;

  /// files.descending
  ///
  /// In de, this message translates to:
  /// **'absteigend'**
  String get filesDescending;

  /// files.download
  ///
  /// In de, this message translates to:
  /// **'Datei herunterladen'**
  String get filesDownload;

  /// files.downloadFailed
  ///
  /// In de, this message translates to:
  /// **'Download fehlgeschlagen: {error}'**
  String filesDownloadFailed(Object error);

  /// files.exists
  ///
  /// In de, this message translates to:
  /// **'Datei existiert bereits'**
  String get filesExists;

  /// files.existsMessage
  ///
  /// In de, this message translates to:
  /// **'Folgende Datei(en) existieren bereits: {names}. Möchtest du diese überschreiben?'**
  String filesExistsMessage(Object names);

  /// files.flutter.ascending
  ///
  /// In de, this message translates to:
  /// **'Aufsteigend'**
  String get filesFlutterAscending;

  /// files.flutter.descending
  ///
  /// In de, this message translates to:
  /// **'Absteigend'**
  String get filesFlutterDescending;

  /// files.flutter.movePh
  ///
  /// In de, this message translates to:
  /// **'z. B. Dokumente/2026'**
  String get filesFlutterMovePh;

  /// files.flutter.openDownload
  ///
  /// In de, this message translates to:
  /// **'Datei öffnen/downloaden'**
  String get filesFlutterOpenDownload;

  /// files.flutter.openFolder
  ///
  /// In de, this message translates to:
  /// **'Ordner öffnen'**
  String get filesFlutterOpenFolder;

  /// files.flutter.openLinkFailed
  ///
  /// In de, this message translates to:
  /// **'Link konnte nicht geöffnet werden'**
  String get filesFlutterOpenLinkFailed;

  /// files.flutter.shareFolderLink
  ///
  /// In de, this message translates to:
  /// **'Link zu diesem Ordner teilen'**
  String get filesFlutterShareFolderLink;

  /// files.flutter.shareRootLink
  ///
  /// In de, this message translates to:
  /// **'Link zur Dateiablage teilen'**
  String get filesFlutterShareRootLink;

  /// files.folderCreated
  ///
  /// In de, this message translates to:
  /// **'Ordner wurde erstellt.'**
  String get filesFolderCreated;

  /// files.folderEmpty
  ///
  /// In de, this message translates to:
  /// **'Dieser Ordner ist leer.'**
  String get filesFolderEmpty;

  /// files.folderFailed
  ///
  /// In de, this message translates to:
  /// **'Ordner konnte nicht erstellt werden: {error}'**
  String filesFolderFailed(Object error);

  /// files.folderName
  ///
  /// In de, this message translates to:
  /// **'Ordnername'**
  String get filesFolderName;

  /// files.full
  ///
  /// In de, this message translates to:
  /// **' · voll'**
  String get filesFull;

  /// files.howMuch
  ///
  /// In de, this message translates to:
  /// **'Wie viel Speicher braucht ihr ungefähr? (optional)'**
  String get filesHowMuch;

  /// files.linkCopied
  ///
  /// In de, this message translates to:
  /// **'Link in Zwischenablage kopiert'**
  String get filesLinkCopied;

  /// files.linkToast
  ///
  /// In de, this message translates to:
  /// **'Link: {url}'**
  String filesLinkToast(Object url);

  /// files.linkedNotFound
  ///
  /// In de, this message translates to:
  /// **'Die verlinkte Datei wurde nicht gefunden.'**
  String get filesLinkedNotFound;

  /// files.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Dateien: {error}'**
  String filesLoadFailed(Object error);

  /// files.modified
  ///
  /// In de, this message translates to:
  /// **'Änderungsdatum'**
  String get filesModified;

  /// files.move
  ///
  /// In de, this message translates to:
  /// **'Verschieben'**
  String get filesMove;

  /// files.moveFailed
  ///
  /// In de, this message translates to:
  /// **'Verschieben fehlgeschlagen: {error}'**
  String filesMoveFailed(Object error);

  /// files.moveHint
  ///
  /// In de, this message translates to:
  /// **'Zielordner relativ zum Tenant-Root. Leer lassen für Root.'**
  String get filesMoveHint;

  /// files.moved
  ///
  /// In de, this message translates to:
  /// **'Eintrag wurde verschoben.'**
  String get filesMoved;

  /// files.name
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get filesName;

  /// files.newName
  ///
  /// In de, this message translates to:
  /// **'Neuer Name'**
  String get filesNewName;

  /// files.noAccess
  ///
  /// In de, this message translates to:
  /// **'Du hast keinen Zugriff auf Dateien.'**
  String get filesNoAccess;

  /// files.noDeleteRights
  ///
  /// In de, this message translates to:
  /// **'Du darfst Dateien nicht löschen.'**
  String get filesNoDeleteRights;

  /// files.noEditRights
  ///
  /// In de, this message translates to:
  /// **'Du darfst Dateien nicht bearbeiten.'**
  String get filesNoEditRights;

  /// files.noHits
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer für „{term}“.'**
  String filesNoHits(Object term);

  /// files.noneUploaded
  ///
  /// In de, this message translates to:
  /// **'Keine Datei hochgeladen.'**
  String get filesNoneUploaded;

  /// files.overwrite
  ///
  /// In de, this message translates to:
  /// **'Überschreiben'**
  String get filesOverwrite;

  /// files.playFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Abspielen: {error}'**
  String filesPlayFailed(Object error);

  /// files.previewFailed
  ///
  /// In de, this message translates to:
  /// **'Bildvorschau fehlgeschlagen: {error}'**
  String filesPreviewFailed(Object error);

  /// files.rename
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get filesRename;

  /// files.renameFailed
  ///
  /// In de, this message translates to:
  /// **'Umbenennen fehlgeschlagen: {error}'**
  String filesRenameFailed(Object error);

  /// files.renameFile
  ///
  /// In de, this message translates to:
  /// **'Datei umbenennen'**
  String get filesRenameFile;

  /// files.renameFolder
  ///
  /// In de, this message translates to:
  /// **'Ordner umbenennen'**
  String get filesRenameFolder;

  /// files.renamed
  ///
  /// In de, this message translates to:
  /// **'Eintrag wurde umbenannt.'**
  String get filesRenamed;

  /// files.requestFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Senden der Anfrage: {error}'**
  String filesRequestFailed(Object error);

  /// files.requestHint
  ///
  /// In de, this message translates to:
  /// **'Die Anfrage geht an den Attendix-Admin. Er meldet sich bei dir.'**
  String get filesRequestHint;

  /// files.requestMore
  ///
  /// In de, this message translates to:
  /// **'Mehr Speicher anfragen'**
  String get filesRequestMore;

  /// files.requestSent
  ///
  /// In de, this message translates to:
  /// **'Deine Anfrage wurde gesendet. Wir melden uns so schnell wie möglich.'**
  String get filesRequestSent;

  /// files.resetSearch
  ///
  /// In de, this message translates to:
  /// **'Suche zurücksetzen'**
  String get filesResetSearch;

  /// files.root
  ///
  /// In de, this message translates to:
  /// **'Root'**
  String get filesRoot;

  /// files.search
  ///
  /// In de, this message translates to:
  /// **'Suche'**
  String get filesSearch;

  /// files.searchCombine
  ///
  /// In de, this message translates to:
  /// **'Filter sind kombinierbar, z. B. <strong>protokoll typ:pdf datum:2026</strong>.'**
  String get filesSearchCombine;

  /// files.searchDate
  ///
  /// In de, this message translates to:
  /// **'<strong>datum:&lt;wert&gt;</strong> · Filtert nach Änderungsdatum (z. B. <strong>datum:2026</strong>, <strong>datum:03.2026</strong>, <strong>datum:03.03.2026</strong>).'**
  String get filesSearchDate;

  /// files.searchHelp
  ///
  /// In de, this message translates to:
  /// **'Freitext durchsucht den Dateinamen/Ordnernamen.'**
  String get filesSearchHelp;

  /// files.searchPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Dateien & Ordner suchen...'**
  String get filesSearchPlaceholder;

  /// files.searchType
  ///
  /// In de, this message translates to:
  /// **'<strong>typ:&lt;wert&gt;</strong> · Filtert nach Dateityp oder Art (z. B. <strong>typ:pdf</strong>, <strong>typ:ordner</strong>, <strong>typ:datei</strong>).'**
  String get filesSearchType;

  /// files.send
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get filesSend;

  /// files.sendTelegram
  ///
  /// In de, this message translates to:
  /// **'Per Telegram senden'**
  String get filesSendTelegram;

  /// files.sendingTelegram
  ///
  /// In de, this message translates to:
  /// **'Datei wird per Telegram gesendet...'**
  String get filesSendingTelegram;

  /// files.shareLink
  ///
  /// In de, this message translates to:
  /// **'Link teilen'**
  String get filesShareLink;

  /// files.size
  ///
  /// In de, this message translates to:
  /// **'Dateigröße'**
  String get filesSize;

  /// files.skip
  ///
  /// In de, this message translates to:
  /// **'Überspringen'**
  String get filesSkip;

  /// files.sortDate
  ///
  /// In de, this message translates to:
  /// **'Datum ({dir})'**
  String filesSortDate(Object dir);

  /// files.sortName
  ///
  /// In de, this message translates to:
  /// **'Name ({dir})'**
  String filesSortName(Object dir);

  /// files.sortSize
  ///
  /// In de, this message translates to:
  /// **'Größe ({dir})'**
  String filesSortSize(Object dir);

  /// files.sorting
  ///
  /// In de, this message translates to:
  /// **'Sortierung'**
  String get filesSorting;

  /// files.storageFull
  ///
  /// In de, this message translates to:
  /// **'Speicher voll'**
  String get filesStorageFull;

  /// files.storageFullMessage
  ///
  /// In de, this message translates to:
  /// **'Für diesen Upload werden {needed} benötigt, frei sind noch {free} von {max}. Lösche nicht mehr benötigte Dateien oder frage mehr Speicher an.'**
  String filesStorageFullMessage(Object needed, Object free, Object max);

  /// files.storageUsed
  ///
  /// In de, this message translates to:
  /// **'Speicher: {used} belegt'**
  String filesStorageUsed(Object used);

  /// files.storageUsedOf
  ///
  /// In de, this message translates to:
  /// **'Speicher: {used} von {max} belegt'**
  String filesStorageUsedOf(Object used, Object max);

  /// files.telegramFailed
  ///
  /// In de, this message translates to:
  /// **'Telegram-Versand fehlgeschlagen: {error}'**
  String filesTelegramFailed(Object error);

  /// files.title
  ///
  /// In de, this message translates to:
  /// **'Dateien'**
  String get filesTitle;

  /// files.upload
  ///
  /// In de, this message translates to:
  /// **'Dateien hochladen'**
  String get filesUpload;

  /// files.uploadProgress
  ///
  /// In de, this message translates to:
  /// **'Upload {done}/{total} ({percent}%)'**
  String filesUploadProgress(Object done, Object total, Object percent);

  /// files.uploadSummary
  ///
  /// In de, this message translates to:
  /// **'{ok} hochgeladen, {skipped} übersprungen, {failed} fehlgeschlagen.'**
  String filesUploadSummary(Object ok, Object skipped, Object failed);

  /// files.uploadedMany
  ///
  /// In de, this message translates to:
  /// **'{count} Dateien wurden hochgeladen.'**
  String filesUploadedMany(Object count);

  /// files.uploadedOne
  ///
  /// In de, this message translates to:
  /// **'Datei wurde hochgeladen.'**
  String get filesUploadedOne;

  /// folderPicker.choose
  ///
  /// In de, this message translates to:
  /// **'Wählen'**
  String get folderPickerChoose;

  /// folderPicker.chooseThis
  ///
  /// In de, this message translates to:
  /// **'Diesen Ordner wählen'**
  String get folderPickerChooseThis;

  /// folderPicker.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Ordner: {error}'**
  String folderPickerLoadFailed(Object error);

  /// folderPicker.noSubfolders
  ///
  /// In de, this message translates to:
  /// **'Keine Unterordner vorhanden.'**
  String get folderPickerNoSubfolders;

  /// folderPicker.parent
  ///
  /// In de, this message translates to:
  /// **'Übergeordneter Ordner'**
  String get folderPickerParent;

  /// folderPicker.title
  ///
  /// In de, this message translates to:
  /// **'Ordner wählen'**
  String get folderPickerTitle;

  /// generalSettings.absenceReasons
  ///
  /// In de, this message translates to:
  /// **'Abwesenheitsgründe'**
  String get generalSettingsAbsenceReasons;

  /// generalSettings.addReason
  ///
  /// In de, this message translates to:
  /// **'Grund hinzufügen'**
  String get generalSettingsAddReason;

  /// generalSettings.addRule
  ///
  /// In de, this message translates to:
  /// **'Regel hinzufügen'**
  String get generalSettingsAddRule;

  /// generalSettings.allEvents
  ///
  /// In de, this message translates to:
  /// **'Alle Termine für Mitglieder sichtbar'**
  String get generalSettingsAllEvents;

  /// generalSettings.allEventsHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, damit Mitglieder auf der Abmelde-Seite alle Termine der Instanz sehen können (nicht nur eigene). Eigene Termine werden hervorgehoben.'**
  String get generalSettingsAllEventsHelper;

  /// generalSettings.allTime
  ///
  /// In de, this message translates to:
  /// **'Gesamte Historie'**
  String get generalSettingsAllTime;

  /// generalSettings.allTypes
  ///
  /// In de, this message translates to:
  /// **'Alle Typen'**
  String get generalSettingsAllTypes;

  /// generalSettings.allowRegister
  ///
  /// In de, this message translates to:
  /// **'Registrierung erlauben'**
  String get generalSettingsAllowRegister;

  /// generalSettings.and
  ///
  /// In de, this message translates to:
  /// **'UND (alle Regeln müssen zutreffen)'**
  String get generalSettingsAnd;

  /// generalSettings.attTypes
  ///
  /// In de, this message translates to:
  /// **'Anwesenheits-Typen'**
  String get generalSettingsAttTypes;

  /// generalSettings.attendance
  ///
  /// In de, this message translates to:
  /// **'Anwesenheiten'**
  String get generalSettingsAttendance;

  /// generalSettings.autoApprove
  ///
  /// In de, this message translates to:
  /// **'Auto-Genehmigung'**
  String get generalSettingsAutoApprove;

  /// generalSettings.autoApproveHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, um neue Registrierungen automatisch zu genehmigen. Andernfalls müssen neue Registrierungen manuell genehmigt werden.'**
  String get generalSettingsAutoApproveHelper;

  /// generalSettings.branding
  ///
  /// In de, this message translates to:
  /// **'Branding'**
  String get generalSettingsBranding;

  /// generalSettings.combine
  ///
  /// In de, this message translates to:
  /// **'Verknüpfung'**
  String get generalSettingsCombine;

  /// generalSettings.combineHelper
  ///
  /// In de, this message translates to:
  /// **'Wie diese Regel mit anderen Regeln kombiniert wird'**
  String get generalSettingsCombineHelper;

  /// generalSettings.count
  ///
  /// In de, this message translates to:
  /// **'Anzahl'**
  String get generalSettingsCount;

  /// generalSettings.criticalRules
  ///
  /// In de, this message translates to:
  /// **'Problemfall-Regeln'**
  String get generalSettingsCriticalRules;

  /// generalSettings.days
  ///
  /// In de, this message translates to:
  /// **'Anzahl Tage'**
  String get generalSettingsDays;

  /// generalSettings.daysHelper
  ///
  /// In de, this message translates to:
  /// **'Anzahl der Tage, die zurück geprüft werden'**
  String get generalSettingsDaysHelper;

  /// generalSettings.deleteRule
  ///
  /// In de, this message translates to:
  /// **'Regel löschen?'**
  String get generalSettingsDeleteRule;

  /// generalSettings.deleteRuleMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du diese Regel wirklich löschen?'**
  String get generalSettingsDeleteRuleMessage;

  /// generalSettings.dutyView
  ///
  /// In de, this message translates to:
  /// **'Dienstplan-Ansicht für Meine Termine'**
  String get generalSettingsDutyView;

  /// generalSettings.dutyViewHelper
  ///
  /// In de, this message translates to:
  /// **'„Meine Termine“ zeigt für Personen aus einem Dienst-Team zuerst ihre Dienste, offene Dienste und Zahlen statt der Anwesenheitsquote. Andere Termine stehen eingeklappt darunter.'**
  String get generalSettingsDutyViewHelper;

  /// generalSettings.flutter.andHint
  ///
  /// In de, this message translates to:
  /// **'Person ist kritisch, wenn ALLE Regeln zutreffen'**
  String get generalSettingsFlutterAndHint;

  /// generalSettings.flutter.andShort
  ///
  /// In de, this message translates to:
  /// **'UND'**
  String get generalSettingsFlutterAndShort;

  /// generalSettings.flutter.daysSuffix
  ///
  /// In de, this message translates to:
  /// **'Tage'**
  String get generalSettingsFlutterDaysSuffix;

  /// generalSettings.flutter.deleteRuleNamed
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die Regel \"{name}\" wirklich löschen?'**
  String generalSettingsFlutterDeleteRuleNamed(Object name);

  /// generalSettings.flutter.disabled
  ///
  /// In de, this message translates to:
  /// **'Deaktiviert'**
  String get generalSettingsFlutterDisabled;

  /// generalSettings.flutter.editRule
  ///
  /// In de, this message translates to:
  /// **'Regel bearbeiten'**
  String get generalSettingsFlutterEditRule;

  /// generalSettings.flutter.excuses
  ///
  /// In de, this message translates to:
  /// **'Entschuldigungen'**
  String get generalSettingsFlutterExcuses;

  /// generalSettings.flutter.excusesHelper
  ///
  /// In de, this message translates to:
  /// **'Erlaubt \"Entschuldigt\" als Status'**
  String get generalSettingsFlutterExcusesHelper;

  /// generalSettings.flutter.fieldsCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Feld} other {{count} Felder}}'**
  String generalSettingsFlutterFieldsCount(num count);

  /// generalSettings.flutter.noHolidays
  ///
  /// In de, this message translates to:
  /// **'Keine Feiertage'**
  String get generalSettingsFlutterNoHolidays;

  /// generalSettings.flutter.noTypes
  ///
  /// In de, this message translates to:
  /// **'Keine Terminarten vorhanden'**
  String get generalSettingsFlutterNoTypes;

  /// generalSettings.flutter.orHint
  ///
  /// In de, this message translates to:
  /// **'Person ist kritisch, wenn EINE der Regeln zutrifft'**
  String get generalSettingsFlutterOrHint;

  /// generalSettings.flutter.orShort
  ///
  /// In de, this message translates to:
  /// **'ODER'**
  String get generalSettingsFlutterOrShort;

  /// generalSettings.flutter.practiceEnd
  ///
  /// In de, this message translates to:
  /// **'Probenende'**
  String get generalSettingsFlutterPracticeEnd;

  /// generalSettings.flutter.practiceStart
  ///
  /// In de, this message translates to:
  /// **'Probenbeginn'**
  String get generalSettingsFlutterPracticeStart;

  /// generalSettings.flutter.ruleAdded
  ///
  /// In de, this message translates to:
  /// **'Regel hinzugefügt'**
  String get generalSettingsFlutterRuleAdded;

  /// generalSettings.flutter.ruleDeleted
  ///
  /// In de, this message translates to:
  /// **'Regel gelöscht'**
  String get generalSettingsFlutterRuleDeleted;

  /// generalSettings.flutter.ruleEnabled
  ///
  /// In de, this message translates to:
  /// **'Regel aktiviert'**
  String get generalSettingsFlutterRuleEnabled;

  /// generalSettings.flutter.ruleEnabledHelper
  ///
  /// In de, this message translates to:
  /// **'Deaktivierte Regeln werden nicht ausgewertet'**
  String get generalSettingsFlutterRuleEnabledHelper;

  /// generalSettings.flutter.ruleUpdated
  ///
  /// In de, this message translates to:
  /// **'Regel aktualisiert'**
  String get generalSettingsFlutterRuleUpdated;

  /// generalSettings.flutter.statusCritical
  ///
  /// In de, this message translates to:
  /// **'Status (zählt als kritisch)'**
  String get generalSettingsFlutterStatusCritical;

  /// generalSettings.foreignInfo
  ///
  /// In de, this message translates to:
  /// **'Info-Text für fremde Termine'**
  String get generalSettingsForeignInfo;

  /// generalSettings.foreignInfoPh
  ///
  /// In de, this message translates to:
  /// **'Du bist bei diesem Termin nicht dabei.'**
  String get generalSettingsForeignInfoPh;

  /// generalSettings.general
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get generalSettingsGeneral;

  /// generalSettings.groupNameEmpty
  ///
  /// In de, this message translates to:
  /// **'Der Gruppenname darf nicht leer sein.'**
  String get generalSettingsGroupNameEmpty;

  /// generalSettings.holidayState
  ///
  /// In de, this message translates to:
  /// **'Bundesland für Ferien/Feiertage'**
  String get generalSettingsHolidayState;

  /// generalSettings.holidaysHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, um beim Anlegen der Anwesenheiten die Ferien und Feiertage hervorzuheben. (nur verfügbar für Deutschland)'**
  String get generalSettingsHolidaysHelper;

  /// generalSettings.lastXDays
  ///
  /// In de, this message translates to:
  /// **'Letzte X Tage'**
  String get generalSettingsLastXDays;

  /// generalSettings.lateExcusedShort
  ///
  /// In de, this message translates to:
  /// **'Verspätet (entsch.)'**
  String get generalSettingsLateExcusedShort;

  /// generalSettings.lateReasons
  ///
  /// In de, this message translates to:
  /// **'Verspätungsgründe'**
  String get generalSettingsLateReasons;

  /// generalSettings.maintainTeachers
  ///
  /// In de, this message translates to:
  /// **'Lehrer pflegen'**
  String get generalSettingsMaintainTeachers;

  /// generalSettings.membersList
  ///
  /// In de, this message translates to:
  /// **'Mitgliederliste für alle'**
  String get generalSettingsMembersList;

  /// generalSettings.membersListHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, um Mitgliedern (Spieler, Helfer, Stimmführer) eine Übersicht aller Personen anzuzeigen.'**
  String get generalSettingsMembersListHelper;

  /// generalSettings.nameOptional
  ///
  /// In de, this message translates to:
  /// **'Name (optional)'**
  String get generalSettingsNameOptional;

  /// generalSettings.neutral
  ///
  /// In de, this message translates to:
  /// **'Neutral'**
  String get generalSettingsNeutral;

  /// generalSettings.newRule
  ///
  /// In de, this message translates to:
  /// **'Neue Regel hinzufügen'**
  String get generalSettingsNewRule;

  /// generalSettings.noGroupsYet
  ///
  /// In de, this message translates to:
  /// **'Es sind noch keine Gruppen vorhanden. Bitte lege zuerst mindestens eine Gruppe an, bevor du die Registrierung aktivierst.'**
  String get generalSettingsNoGroupsYet;

  /// generalSettings.noRules
  ///
  /// In de, this message translates to:
  /// **'Es wurden noch keine Problemfall-Regeln definiert. Regeln bestimmen, wann eine Person als Problemfall markiert wird.'**
  String get generalSettingsNoRules;

  /// generalSettings.none
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get generalSettingsNone;

  /// generalSettings.or
  ///
  /// In de, this message translates to:
  /// **'ODER (eine Regel muss zutreffen)'**
  String get generalSettingsOr;

  /// generalSettings.other
  ///
  /// In de, this message translates to:
  /// **'Sonstiges'**
  String get generalSettingsOther;

  /// generalSettings.parentsFeature
  ///
  /// In de, this message translates to:
  /// **'Eltern-Funktion'**
  String get generalSettingsParentsFeature;

  /// generalSettings.parentsHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, um Eltern die Möglichkeit zu geben, Einsicht in die Anwesenheiten ihrer Kinder zu geben und Abwesenheiten pflegen zu können.'**
  String get generalSettingsParentsHelper;

  /// generalSettings.percent
  ///
  /// In de, this message translates to:
  /// **'Prozent'**
  String get generalSettingsPercent;

  /// generalSettings.periodHelper
  ///
  /// In de, this message translates to:
  /// **'Bestimmt den Zeitraum für die Zählung'**
  String get generalSettingsPeriodHelper;

  /// generalSettings.periodPositive
  ///
  /// In de, this message translates to:
  /// **'Der Zeitraum muss größer als 0 sein.'**
  String get generalSettingsPeriodPositive;

  /// generalSettings.periodType
  ///
  /// In de, this message translates to:
  /// **'Zeitraum-Typ'**
  String get generalSettingsPeriodType;

  /// generalSettings.reasonPh
  ///
  /// In de, this message translates to:
  /// **'Grund eingeben...'**
  String get generalSettingsReasonPh;

  /// generalSettings.reasons
  ///
  /// In de, this message translates to:
  /// **'Abwesenheits- & Verspätungsgründe'**
  String get generalSettingsReasons;

  /// generalSettings.reasonsCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Grund} other {{count} Gründe}} konfiguriert'**
  String generalSettingsReasonsCount(num count);

  /// generalSettings.registerFields
  ///
  /// In de, this message translates to:
  /// **'Registrierungsfelder'**
  String get generalSettingsRegisterFields;

  /// generalSettings.registerFieldsHint
  ///
  /// In de, this message translates to:
  /// **'Wähle die Felder aus, die bei der Registrierung angezeigt werden sollen. Alle ausgewählten Felder sind Pflichtfelder.'**
  String get generalSettingsRegisterFieldsHint;

  /// generalSettings.registerHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, um neuen Personen die Registrierung in dieser Instanz zu erlauben. Der Link wird automatisch generiert und kann nach dem Speichern kopiert werden.'**
  String get generalSettingsRegisterHelper;

  /// generalSettings.registerNoGroups
  ///
  /// In de, this message translates to:
  /// **'Registrierung kann nicht aktiviert werden: Bitte lege zuerst mindestens eine Gruppe an.'**
  String get generalSettingsRegisterNoGroups;

  /// generalSettings.registration
  ///
  /// In de, this message translates to:
  /// **'Registrierung'**
  String get generalSettingsRegistration;

  /// generalSettings.reload
  ///
  /// In de, this message translates to:
  /// **'Neu laden'**
  String get generalSettingsReload;

  /// generalSettings.restoreDefaults
  ///
  /// In de, this message translates to:
  /// **'Standardwerte wiederherstellen'**
  String get generalSettingsRestoreDefaults;

  /// generalSettings.rulePh
  ///
  /// In de, this message translates to:
  /// **'z.B. Verspätungs-Warnung'**
  String get generalSettingsRulePh;

  /// generalSettings.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Einstellungen'**
  String get generalSettingsSaveFailed;

  /// generalSettings.saved
  ///
  /// In de, this message translates to:
  /// **'Einstellungen gespeichert'**
  String get generalSettingsSaved;

  /// generalSettings.savedReload
  ///
  /// In de, this message translates to:
  /// **'Die Einstellungen wurden erfolgreich gespeichert. Bitte lade die Seite neu, um die Änderungen zu sehen.'**
  String get generalSettingsSavedReload;

  /// generalSettings.saving
  ///
  /// In de, this message translates to:
  /// **'Einstellungen werden gespeichert...'**
  String get generalSettingsSaving;

  /// generalSettings.seasonHelper
  ///
  /// In de, this message translates to:
  /// **'Anwesenheiten werden erst ab diesem Datum bei den Personen berücksichtigt'**
  String get generalSettingsSeasonHelper;

  /// generalSettings.seasonStart
  ///
  /// In de, this message translates to:
  /// **'Saisonbeginn'**
  String get generalSettingsSeasonStart;

  /// generalSettings.selectStatus
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle mindestens einen Status aus.'**
  String get generalSettingsSelectStatus;

  /// generalSettings.shareSongs
  ///
  /// In de, this message translates to:
  /// **'Werke öffentlich teilen'**
  String get generalSettingsShareSongs;

  /// generalSettings.shareSongsHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, um Werke als öffentlichen link zu teilen. Jeder mit dem Link kann die Werke ansehen aber nicht bearbeiten. Der Link wird automatisch generiert und kann nach dem Speichern kopiert werden.'**
  String get generalSettingsShareSongsHelper;

  /// generalSettings.shiftPlans
  ///
  /// In de, this message translates to:
  /// **'Schichtpläne'**
  String get generalSettingsShiftPlans;

  /// generalSettings.shiftPresent
  ///
  /// In de, this message translates to:
  /// **'Schicht-/Arbeitsbedingt = Anwesend'**
  String get generalSettingsShiftPresent;

  /// generalSettings.shiftPresentHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, um schicht- oder arbeitsbedingt entschuldigte Abwesenheiten als anwesend für die prozentuale Berechnung zu werten.'**
  String get generalSettingsShiftPresentHelper;

  /// generalSettings.shortNameEmpty
  ///
  /// In de, this message translates to:
  /// **'Der Kurzname darf nicht leer sein.'**
  String get generalSettingsShortNameEmpty;

  /// generalSettings.shortNameHelper
  ///
  /// In de, this message translates to:
  /// **'Wird vor allem als Dateiname bei Exports verwendet'**
  String get generalSettingsShortNameHelper;

  /// generalSettings.showHolidays
  ///
  /// In de, this message translates to:
  /// **'Ferien/Feiertage anzeigen'**
  String get generalSettingsShowHolidays;

  /// generalSettings.sinceSeason
  ///
  /// In de, this message translates to:
  /// **'Seit Saisonbeginn'**
  String get generalSettingsSinceSeason;

  /// generalSettings.songDb
  ///
  /// In de, this message translates to:
  /// **'Werk-Datenbank'**
  String get generalSettingsSongDb;

  /// generalSettings.teachersHelper
  ///
  /// In de, this message translates to:
  /// **'Aktivieren, um die Lehrer der Spieler verwalten zu können.'**
  String get generalSettingsTeachersHelper;

  /// generalSettings.tenantName
  ///
  /// In de, this message translates to:
  /// **'Instanz-Name'**
  String get generalSettingsTenantName;

  /// generalSettings.tenantShort
  ///
  /// In de, this message translates to:
  /// **'Instanz-Kürzel'**
  String get generalSettingsTenantShort;

  /// generalSettings.thresholdPositive
  ///
  /// In de, this message translates to:
  /// **'Der Schwellenwert muss größer als 0 sein.'**
  String get generalSettingsThresholdPositive;

  /// generalSettings.thresholdType
  ///
  /// In de, this message translates to:
  /// **'Schwellenwert-Typ'**
  String get generalSettingsThresholdType;

  /// handover.addFilter
  ///
  /// In de, this message translates to:
  /// **'Filter hinzufügen'**
  String get handoverAddFilter;

  /// handover.alreadyThere
  ///
  /// In de, this message translates to:
  /// **'Die folgenden Personen konnten nicht übertragen werden, da sie bereits in der Zielinstanz vorhanden sind:\n{names}'**
  String handoverAlreadyThere(Object names);

  /// handover.archiveNote
  ///
  /// In de, this message translates to:
  /// **'Die Personen werden in dieser Instanz archiviert.'**
  String get handoverArchiveNote;

  /// handover.confirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die {count} ausgewählten Personen wirklich in die Instanz „{tenant}“ übertragen? {note}'**
  String handoverConfirm(Object count, Object tenant, Object note);

  /// handover.failed
  ///
  /// In de, this message translates to:
  /// **'Fehler bei der Personenübergabe'**
  String get handoverFailed;

  /// handover.failedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler bei der Personenübergabe: {error}'**
  String handoverFailedWith(Object error);

  /// handover.groupMapping
  ///
  /// In de, this message translates to:
  /// **'Gruppen-Zuordnung'**
  String get handoverGroupMapping;

  /// handover.inGroupDots
  ///
  /// In de, this message translates to:
  /// **'Ist in der Gruppe...'**
  String get handoverInGroupDots;

  /// handover.intro
  ///
  /// In de, this message translates to:
  /// **'Hiermit kannst du Personen innerhalb einer Organisation weitergeben oder in einer andere Instanz kopieren. Falls die Person ein Account hat, wird diese informiert.'**
  String get handoverIntro;

  /// handover.keepHelper
  ///
  /// In de, this message translates to:
  /// **'Die Person wird in der aktuellen Instanz nicht archiviert sondern bleibt aktiv'**
  String get handoverKeepHelper;

  /// handover.keepInTenant
  ///
  /// In de, this message translates to:
  /// **'Personen in Instanz behalten'**
  String get handoverKeepInTenant;

  /// handover.mainGroupHelper
  ///
  /// In de, this message translates to:
  /// **'Personen die in der Hauptgruppe sind, werden auch angezeigt'**
  String get handoverMainGroupHelper;

  /// handover.noData
  ///
  /// In de, this message translates to:
  /// **'Keine Daten für die Personenübergabe vorhanden.'**
  String get handoverNoData;

  /// handover.noOtherTenants
  ///
  /// In de, this message translates to:
  /// **'Es sind keine weiteren Instanzen vorhanden. Bitte füge weitere Instanzen dieser Organisation hinzu.'**
  String get handoverNoOtherTenants;

  /// handover.noneSelected
  ///
  /// In de, this message translates to:
  /// **'Keine Personen ausgewählt'**
  String get handoverNoneSelected;

  /// handover.olderThan
  ///
  /// In de, this message translates to:
  /// **'Älter als'**
  String get handoverOlderThan;

  /// handover.olderThanDots
  ///
  /// In de, this message translates to:
  /// **'Älter als...'**
  String get handoverOlderThanDots;

  /// handover.personList
  ///
  /// In de, this message translates to:
  /// **'Personenliste'**
  String get handoverPersonList;

  /// handover.respectMainGroup
  ///
  /// In de, this message translates to:
  /// **'Hauptgruppe beachten'**
  String get handoverRespectMainGroup;

  /// handover.selectAll
  ///
  /// In de, this message translates to:
  /// **'Alle auswählen'**
  String get handoverSelectAll;

  /// handover.selectGroup
  ///
  /// In de, this message translates to:
  /// **'Gruppe auswählen'**
  String get handoverSelectGroup;

  /// handover.settings
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get handoverSettings;

  /// handover.stayNote
  ///
  /// In de, this message translates to:
  /// **'Die Personen bleiben in dieser Instanz erhalten.'**
  String get handoverStayNote;

  /// handover.targetTenant
  ///
  /// In de, this message translates to:
  /// **'Ziel-Instanz'**
  String get handoverTargetTenant;

  /// handover.title
  ///
  /// In de, this message translates to:
  /// **'Personenübergabe'**
  String get handoverTitle;

  /// handover.transfer
  ///
  /// In de, this message translates to:
  /// **'Übertragen'**
  String get handoverTransfer;

  /// handover.transferred
  ///
  /// In de, this message translates to:
  /// **'{count} Personen wurden übertragen.'**
  String handoverTransferred(Object count);

  /// handover.transferring
  ///
  /// In de, this message translates to:
  /// **'Personen werden übertragen...'**
  String get handoverTransferring;

  /// handover.youngerThan
  ///
  /// In de, this message translates to:
  /// **'Jünger als'**
  String get handoverYoungerThan;

  /// handover.youngerThanDots
  ///
  /// In de, this message translates to:
  /// **'Jünger als...'**
  String get handoverYoungerThanDots;

  /// help.articleNotFound
  ///
  /// In de, this message translates to:
  /// **'Dieser Artikel wurde nicht gefunden.'**
  String get helpArticleNotFound;

  /// help.articles
  ///
  /// In de, this message translates to:
  /// **'Artikel'**
  String get helpArticles;

  /// help.glossary
  ///
  /// In de, this message translates to:
  /// **'Glossar'**
  String get helpGlossary;

  /// help.lookup
  ///
  /// In de, this message translates to:
  /// **'Nachschlagen'**
  String get helpLookup;

  /// help.noHits
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer für „{term}“.'**
  String helpNoHits(Object term);

  /// help.noTerms
  ///
  /// In de, this message translates to:
  /// **'Keine Begriffe gefunden.'**
  String get helpNoTerms;

  /// help.searchPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Frage oder Stichwort suchen...'**
  String get helpSearchPlaceholder;

  /// help.searchTerm
  ///
  /// In de, this message translates to:
  /// **'Begriff suchen...'**
  String get helpSearchTerm;

  /// help.title
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get helpTitle;

  /// help.topics
  ///
  /// In de, this message translates to:
  /// **'Themen'**
  String get helpTopics;

  /// history.addSongs
  ///
  /// In de, this message translates to:
  /// **'Werk(e) hinzufügen'**
  String get historyAddSongs;

  /// history.datePlaceholder
  ///
  /// In de, this message translates to:
  /// **'TT.MM.JJJJ'**
  String get historyDatePlaceholder;

  /// history.flutter.entryDeleted
  ///
  /// In de, this message translates to:
  /// **'Eintrag gelöscht'**
  String get historyFlutterEntryDeleted;

  /// history.flutter.noTenant
  ///
  /// In de, this message translates to:
  /// **'Kein Tenant ausgewählt'**
  String get historyFlutterNoTenant;

  /// history.flutter.songsAdded
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {Werk hinzugefügt} other {{count} Werke hinzugefügt}}'**
  String historyFlutterSongsAdded(num count);

  /// history.flutter.unknownSong
  ///
  /// In de, this message translates to:
  /// **'Unbekanntes Werk'**
  String get historyFlutterUnknownSong;

  /// history.noneFound
  ///
  /// In de, this message translates to:
  /// **'Keine Werke gefunden'**
  String get historyNoneFound;

  /// history.noneSelected
  ///
  /// In de, this message translates to:
  /// **'Keine Werke ausgewählt'**
  String get historyNoneSelected;

  /// history.noneYet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Werke gespielt'**
  String get historyNoneYet;

  /// history.rehearsals
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Probe} other {{count} Proben}}'**
  String historyRehearsals(num count);

  /// history.removeConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du den Eintrag wirklich entfernen?'**
  String get historyRemoveConfirm;

  /// history.searchSong
  ///
  /// In de, this message translates to:
  /// **'Werk suchen...'**
  String get historySearchSong;

  /// history.selectAtLeastOne
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle mindestens ein Werk an'**
  String get historySelectAtLeastOne;

  /// history.selectSongs
  ///
  /// In de, this message translates to:
  /// **'Werke auswählen'**
  String get historySelectSongs;

  /// history.selectedCount
  ///
  /// In de, this message translates to:
  /// **'{count} Werk(e) ausgewählt'**
  String historySelectedCount(Object count);

  /// history.songs
  ///
  /// In de, this message translates to:
  /// **'Werk(e)'**
  String get historySongs;

  /// history.title
  ///
  /// In de, this message translates to:
  /// **'Werkhistorie'**
  String get historyTitle;

  /// homeDashboard.absences
  ///
  /// In de, this message translates to:
  /// **'Abwesenheiten & Pausierungen'**
  String get homeDashboardAbsences;

  /// homeDashboard.allHidden
  ///
  /// In de, this message translates to:
  /// **'Alle Karten sind ausgeblendet. Konfiguriere das Dashboard unter Einstellungen.'**
  String get homeDashboardAllHidden;

  /// homeDashboard.average
  ///
  /// In de, this message translates to:
  /// **'Durchschnitt'**
  String get homeDashboardAverage;

  /// homeDashboard.birthdayRange
  ///
  /// In de, this message translates to:
  /// **'Letzte und nächste 14 Tage'**
  String get homeDashboardBirthdayRange;

  /// homeDashboard.birthdays
  ///
  /// In de, this message translates to:
  /// **'Geburtstage'**
  String get homeDashboardBirthdays;

  /// homeDashboard.configure
  ///
  /// In de, this message translates to:
  /// **'Dashboard konfigurieren'**
  String get homeDashboardConfigure;

  /// homeDashboard.current
  ///
  /// In de, this message translates to:
  /// **'Aktuell'**
  String get homeDashboardCurrent;

  /// homeDashboard.currentPlan
  ///
  /// In de, this message translates to:
  /// **'Aktueller Ablaufplan'**
  String get homeDashboardCurrentPlan;

  /// homeDashboard.currentProblemCases
  ///
  /// In de, this message translates to:
  /// **'Aktuelle Problemfälle'**
  String get homeDashboardCurrentProblemCases;

  /// homeDashboard.currentSongs
  ///
  /// In de, this message translates to:
  /// **'Aktuelle Werke'**
  String get homeDashboardCurrentSongs;

  /// homeDashboard.daysAgo
  ///
  /// In de, this message translates to:
  /// **'vor {count} Tagen'**
  String homeDashboardDaysAgo(Object count);

  /// homeDashboard.events
  ///
  /// In de, this message translates to:
  /// **'Termine'**
  String get homeDashboardEvents;

  /// homeDashboard.flutter.exit
  ///
  /// In de, this message translates to:
  /// **'Austritt'**
  String get homeDashboardFlutterExit;

  /// homeDashboard.flutter.join
  ///
  /// In de, this message translates to:
  /// **'Beitritt'**
  String get homeDashboardFlutterJoin;

  /// homeDashboard.flutter.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden: {error}'**
  String homeDashboardFlutterLoadFailed(Object error);

  /// homeDashboard.flutter.pause
  ///
  /// In de, this message translates to:
  /// **'Pause'**
  String get homeDashboardFlutterPause;

  /// homeDashboard.flutter.timeRange
  ///
  /// In de, this message translates to:
  /// **'{time} Uhr'**
  String homeDashboardFlutterTimeRange(Object time);

  /// homeDashboard.inDays
  ///
  /// In de, this message translates to:
  /// **'in {count} Tagen'**
  String homeDashboardInDays(Object count);

  /// homeDashboard.last4Weeks
  ///
  /// In de, this message translates to:
  /// **'Letzte 4 Wochen'**
  String get homeDashboardLast4Weeks;

  /// homeDashboard.last60Days
  ///
  /// In de, this message translates to:
  /// **'Letzte 60 Tage'**
  String get homeDashboardLast60Days;

  /// homeDashboard.lastEvent
  ///
  /// In de, this message translates to:
  /// **'Letzter Termin'**
  String get homeDashboardLastEvent;

  /// homeDashboard.lastSummary
  ///
  /// In de, this message translates to:
  /// **'{present}/{total} anwesend · {excused} entschuldigt'**
  String homeDashboardLastSummary(Object present, Object total, Object excused);

  /// homeDashboard.lateExcusedShort
  ///
  /// In de, this message translates to:
  /// **'Entsch. verspätet'**
  String get homeDashboardLateExcusedShort;

  /// homeDashboard.live
  ///
  /// In de, this message translates to:
  /// **'Live'**
  String get homeDashboardLive;

  /// homeDashboard.memberChanges
  ///
  /// In de, this message translates to:
  /// **'Mitglieder-Veränderungen'**
  String get homeDashboardMemberChanges;

  /// homeDashboard.nextAndLast
  ///
  /// In de, this message translates to:
  /// **'Nächster & letzter Termin'**
  String get homeDashboardNextAndLast;

  /// homeDashboard.noAbsences
  ///
  /// In de, this message translates to:
  /// **'Keine Abwesenheiten im Zeitraum.'**
  String get homeDashboardNoAbsences;

  /// homeDashboard.noBirthdays
  ///
  /// In de, this message translates to:
  /// **'Keine Geburtstage im Zeitraum.'**
  String get homeDashboardNoBirthdays;

  /// homeDashboard.noChanges
  ///
  /// In de, this message translates to:
  /// **'Keine Veränderungen im Zeitraum.'**
  String get homeDashboardNoChanges;

  /// homeDashboard.noEvents
  ///
  /// In de, this message translates to:
  /// **'Keine Termine gefunden.'**
  String get homeDashboardNoEvents;

  /// homeDashboard.noPlannedSongs
  ///
  /// In de, this message translates to:
  /// **'Keine geplanten Werke.'**
  String get homeDashboardNoPlannedSongs;

  /// homeDashboard.noProblemCases
  ///
  /// In de, this message translates to:
  /// **'Keine Problemfälle vorhanden.'**
  String get homeDashboardNoProblemCases;

  /// homeDashboard.planTimes
  ///
  /// In de, this message translates to:
  /// **'{start} – {end} Uhr · {count, plural, one {{count} Position} other {{count} Positionen}}'**
  String homeDashboardPlanTimes(Object start, Object end, num count);

  /// homeDashboard.plannedSongs
  ///
  /// In de, this message translates to:
  /// **'Geplante Werke'**
  String get homeDashboardPlannedSongs;

  /// homeDashboard.problemCases
  ///
  /// In de, this message translates to:
  /// **'Problemfälle'**
  String get homeDashboardProblemCases;

  /// homeDashboard.recently
  ///
  /// In de, this message translates to:
  /// **'Zuletzt'**
  String get homeDashboardRecently;

  /// homeDashboard.shift
  ///
  /// In de, this message translates to:
  /// **'Schicht'**
  String get homeDashboardShift;

  /// homeDashboard.shiftCount
  ///
  /// In de, this message translates to:
  /// **'{count} Schicht'**
  String homeDashboardShiftCount(Object count);

  /// homeDashboard.signOuts
  ///
  /// In de, this message translates to:
  /// **'Abmeldungen'**
  String get homeDashboardSignOuts;

  /// homeDashboard.signedOut
  ///
  /// In de, this message translates to:
  /// **'Abgemeldet'**
  String get homeDashboardSignedOut;

  /// homeDashboard.totalCount
  ///
  /// In de, this message translates to:
  /// **'{count} gesamt'**
  String homeDashboardTotalCount(Object count);

  /// homeDashboard.turned
  ///
  /// In de, this message translates to:
  /// **'ist {age} geworden'**
  String homeDashboardTurned(Object age);

  /// homeDashboard.turns
  ///
  /// In de, this message translates to:
  /// **'wird {age}'**
  String homeDashboardTurns(Object age);

  /// homeDashboard.turnsToday
  ///
  /// In de, this message translates to:
  /// **'wird heute {age}'**
  String homeDashboardTurnsToday(Object age);

  /// homeDashboard.yesterday
  ///
  /// In de, this message translates to:
  /// **'Gestern'**
  String get homeDashboardYesterday;

  /// imageViewer.hint
  ///
  /// In de, this message translates to:
  /// **'Doppeltippen oder mit zwei Fingern zoomen'**
  String get imageViewerHint;

  /// imageViewer.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Bild konnte nicht geladen werden'**
  String get imageViewerLoadFailed;

  /// imageViewer.zoomIn
  ///
  /// In de, this message translates to:
  /// **'Vergrößern'**
  String get imageViewerZoomIn;

  /// imageViewer.zoomOut
  ///
  /// In de, this message translates to:
  /// **'Verkleinern'**
  String get imageViewerZoomOut;

  /// imageViewer.zoomReset
  ///
  /// In de, this message translates to:
  /// **'Zoom zurücksetzen'**
  String get imageViewerZoomReset;

  /// instruments.addGroup
  ///
  /// In de, this message translates to:
  /// **'Gruppe hinzufügen'**
  String get instrumentsAddGroup;

  /// instruments.cannotDelete
  ///
  /// In de, this message translates to:
  /// **'Du kannst das Instrument nicht löschen, da es Spieler gibt (gab), die darauf spielen'**
  String get instrumentsCannotDelete;

  /// instruments.categories
  ///
  /// In de, this message translates to:
  /// **'Kategorien'**
  String get instrumentsCategories;

  /// instruments.category
  ///
  /// In de, this message translates to:
  /// **'Kategorie'**
  String get instrumentsCategory;

  /// instruments.categoryName
  ///
  /// In de, this message translates to:
  /// **'Name der Kategorie'**
  String get instrumentsCategoryName;

  /// instruments.deleteCategory
  ///
  /// In de, this message translates to:
  /// **'Kategorie wirklich löschen? Alle Gruppen in dieser Kategorie verlieren die Kategorisierung.'**
  String get instrumentsDeleteCategory;

  /// instruments.deleteGroup
  ///
  /// In de, this message translates to:
  /// **'Gruppe wirklich löschen?'**
  String get instrumentsDeleteGroup;

  /// instruments.dragCategories
  ///
  /// In de, this message translates to:
  /// **'Ziehe die Kategorien, um die Reihenfolge anzupassen. Klicke auf das Häkchen, um zu speichern.'**
  String get instrumentsDragCategories;

  /// instruments.dragGroups
  ///
  /// In de, this message translates to:
  /// **'Ziehe die Gruppen, um die Reihenfolge anzupassen. Klicke auf das Häkchen, um zu speichern.'**
  String get instrumentsDragGroups;

  /// instruments.editCategory
  ///
  /// In de, this message translates to:
  /// **'Kategorie bearbeiten'**
  String get instrumentsEditCategory;

  /// instruments.enterName
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einem Namen an'**
  String get instrumentsEnterName;

  /// instruments.es
  ///
  /// In de, this message translates to:
  /// **'Es'**
  String get instrumentsEs;

  /// instruments.flutter.addFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen'**
  String get instrumentsFlutterAddFailed;

  /// instruments.flutter.clef
  ///
  /// In de, this message translates to:
  /// **'{clef}-Schlüssel'**
  String instrumentsFlutterClef(Object clef);

  /// instruments.flutter.clefs
  ///
  /// In de, this message translates to:
  /// **'Notenschlüssel'**
  String get instrumentsFlutterClefs;

  /// instruments.flutter.generateSynonyms
  ///
  /// In de, this message translates to:
  /// **'Synonyme generieren'**
  String get instrumentsFlutterGenerateSynonyms;

  /// instruments.flutter.noCategories
  ///
  /// In de, this message translates to:
  /// **'Keine Kategorien'**
  String get instrumentsFlutterNoCategories;

  /// instruments.flutter.noCategoriesHint
  ///
  /// In de, this message translates to:
  /// **'Tippe + um eine Kategorie zu erstellen'**
  String get instrumentsFlutterNoCategoriesHint;

  /// instruments.flutter.shortName
  ///
  /// In de, this message translates to:
  /// **'Kurzname'**
  String get instrumentsFlutterShortName;

  /// instruments.generatingSynonyms
  ///
  /// In de, this message translates to:
  /// **'Synonyme werden generiert...'**
  String get instrumentsGeneratingSynonyms;

  /// instruments.groupPh
  ///
  /// In de, this message translates to:
  /// **'z.B. Mädchen, Posaune, Alt 1, etc.'**
  String get instrumentsGroupPh;

  /// instruments.groupsCount
  ///
  /// In de, this message translates to:
  /// **'Gruppen ({count})'**
  String instrumentsGroupsCount(Object count);

  /// instruments.mainGroup
  ///
  /// In de, this message translates to:
  /// **'{name} (Hauptgruppe)'**
  String instrumentsMainGroup(Object name);

  /// instruments.nameFirst
  ///
  /// In de, this message translates to:
  /// **'Bitte gib zuerst einen Namen an!'**
  String get instrumentsNameFirst;

  /// instruments.nameRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen Namen an!'**
  String get instrumentsNameRequired;

  /// instruments.newCategory
  ///
  /// In de, this message translates to:
  /// **'Neue Kategorie'**
  String get instrumentsNewCategory;

  /// instruments.noCategory
  ///
  /// In de, this message translates to:
  /// **'Keine Kategorie'**
  String get instrumentsNoCategory;

  /// instruments.orderFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern der Reihenfolge'**
  String get instrumentsOrderFailed;

  /// instruments.range
  ///
  /// In de, this message translates to:
  /// **'Tonumfang'**
  String get instrumentsRange;

  /// instruments.savingOrder
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge wird gespeichert...'**
  String get instrumentsSavingOrder;

  /// instruments.synonyms
  ///
  /// In de, this message translates to:
  /// **'Synonyme'**
  String get instrumentsSynonyms;

  /// instruments.synonymsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Generieren der Synonyme'**
  String get instrumentsSynonymsFailed;

  /// instruments.synonymsGenerated
  ///
  /// In de, this message translates to:
  /// **'Synonyme erfolgreich generiert!'**
  String get instrumentsSynonymsGenerated;

  /// instruments.synonymsHelper
  ///
  /// In de, this message translates to:
  /// **'Definiere Synonyme um beim Hinzufügen von Dateien zu Werken die Instrumente automatisch zuordnen zu können. Synonyme durch Komma trennen.'**
  String get instrumentsSynonymsHelper;

  /// instruments.tuning
  ///
  /// In de, this message translates to:
  /// **'Stimmung'**
  String get instrumentsTuning;

  /// instruments.update
  ///
  /// In de, this message translates to:
  /// **'Aktualisieren'**
  String get instrumentsUpdate;

  /// instruments.updated
  ///
  /// In de, this message translates to:
  /// **'{name} wurde erfolgreich aktualisiert'**
  String instrumentsUpdated(Object name);

  /// legal.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Inhalt konnte nicht geladen werden.'**
  String get legalLoadFailed;

  /// legal.title
  ///
  /// In de, this message translates to:
  /// **'Impressum & Datenschutz'**
  String get legalTitle;

  /// linkPersons.failed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Verknüpfen'**
  String get linkPersonsFailed;

  /// linkPersons.ignore
  ///
  /// In de, this message translates to:
  /// **'Ignorieren'**
  String get linkPersonsIgnore;

  /// linkPersons.intro
  ///
  /// In de, this message translates to:
  /// **'Mögliche Übereinstimmungen aus verschiedenen Instanzen. Verknüpfte Personen synchronisieren Name, Geburtstag, E-Mail und Telefon automatisch.'**
  String get linkPersonsIntro;

  /// linkPersons.link
  ///
  /// In de, this message translates to:
  /// **'Verknüpfen'**
  String get linkPersonsLink;

  /// linkPersons.linked
  ///
  /// In de, this message translates to:
  /// **'{count} Personen verknüpft'**
  String linkPersonsLinked(Object count);

  /// linkPersons.linkedCount
  ///
  /// In de, this message translates to:
  /// **'{count} Personen wurden verknüpft.'**
  String linkPersonsLinkedCount(Object count);

  /// linkPersons.noMore
  ///
  /// In de, this message translates to:
  /// **'Keine weiteren Vorschläge.'**
  String get linkPersonsNoMore;

  /// linkPersons.reason.firstNamePrefix
  ///
  /// In de, this message translates to:
  /// **'Vorname-Präfix'**
  String get linkPersonsReasonFirstNamePrefix;

  /// linkPersons.reason.lastNamePrefix
  ///
  /// In de, this message translates to:
  /// **'Nachname-Präfix'**
  String get linkPersonsReasonLastNamePrefix;

  /// linkPersons.reason.linked
  ///
  /// In de, this message translates to:
  /// **'Verknüpfte Person'**
  String get linkPersonsReasonLinked;

  /// linkPersons.reason.nearlyIdentical
  ///
  /// In de, this message translates to:
  /// **'Name fast identisch'**
  String get linkPersonsReasonNearlyIdentical;

  /// linkPersons.reason.sameBirthday
  ///
  /// In de, this message translates to:
  /// **'Gleicher Geburtstag'**
  String get linkPersonsReasonSameBirthday;

  /// linkPersons.reason.sameEmail
  ///
  /// In de, this message translates to:
  /// **'E-Mail identisch'**
  String get linkPersonsReasonSameEmail;

  /// linkPersons.reason.sameFirstName
  ///
  /// In de, this message translates to:
  /// **'Vorname identisch'**
  String get linkPersonsReasonSameFirstName;

  /// linkPersons.reason.sameLastName
  ///
  /// In de, this message translates to:
  /// **'Nachname identisch'**
  String get linkPersonsReasonSameLastName;

  /// linkPersons.reason.similarBirthday
  ///
  /// In de, this message translates to:
  /// **'Ähnlicher Geburtstag'**
  String get linkPersonsReasonSimilarBirthday;

  /// linkPersons.reason.similarName
  ///
  /// In de, this message translates to:
  /// **'Ähnlicher Name'**
  String get linkPersonsReasonSimilarName;

  /// linkPersons.reason.swapped
  ///
  /// In de, this message translates to:
  /// **'Vor-/Nachname vertauscht'**
  String get linkPersonsReasonSwapped;

  /// linkPersons.selectOne
  ///
  /// In de, this message translates to:
  /// **'Bitte mindestens eine Übereinstimmung auswählen'**
  String get linkPersonsSelectOne;

  /// linkPersons.title
  ///
  /// In de, this message translates to:
  /// **'Personen verknüpfen'**
  String get linkPersonsTitle;

  /// login.email
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get loginEmail;

  /// login.emailPlaceholder
  ///
  /// In de, this message translates to:
  /// **'E-Mail eingeben...'**
  String get loginEmailPlaceholder;

  /// login.failed.header
  ///
  /// In de, this message translates to:
  /// **'Anmeldung fehlgeschlagen'**
  String get loginFailedHeader;

  /// login.failed.message
  ///
  /// In de, this message translates to:
  /// **'E-Mail oder Passwort ist falsch. Falls du kein Passwort gesetzt hast, kannst du dich stattdessen mit einem Code per E-Mail anmelden.'**
  String get loginFailedMessage;

  /// login.flutter.accessDenied
  ///
  /// In de, this message translates to:
  /// **'Der Zugriff wurde verweigert.'**
  String get loginFlutterAccessDenied;

  /// login.flutter.backToLogin
  ///
  /// In de, this message translates to:
  /// **'Zurück zum Login'**
  String get loginFlutterBackToLogin;

  /// login.flutter.checkSpam
  ///
  /// In de, this message translates to:
  /// **'Bitte prüfe auch deinen Spam-Ordner.'**
  String get loginFlutterCheckSpam;

  /// login.flutter.confirmEmail
  ///
  /// In de, this message translates to:
  /// **'E-Mail bestätigen'**
  String get loginFlutterConfirmEmail;

  /// login.flutter.confirmEmailSent
  ///
  /// In de, this message translates to:
  /// **'Wir haben dir eine E-Mail an {email} gesendet. Bitte klicke auf den Link darin, um deinen Account zu aktivieren.'**
  String loginFlutterConfirmEmailSent(Object email);

  /// login.flutter.enterPassword
  ///
  /// In de, this message translates to:
  /// **'Bitte Passwort eingeben'**
  String get loginFlutterEnterPassword;

  /// login.flutter.linkFailed
  ///
  /// In de, this message translates to:
  /// **'Der Link konnte nicht verarbeitet werden.'**
  String get loginFlutterLinkFailed;

  /// login.flutter.newPassword
  ///
  /// In de, this message translates to:
  /// **'Neues Passwort'**
  String get loginFlutterNewPassword;

  /// login.flutter.otherEmail
  ///
  /// In de, this message translates to:
  /// **'Andere E-Mail verwenden'**
  String get loginFlutterOtherEmail;

  /// login.flutter.resetIntro
  ///
  /// In de, this message translates to:
  /// **'Gib deine E-Mail-Adresse ein und wir senden dir einen Link zum Zurücksetzen.'**
  String get loginFlutterResetIntro;

  /// login.flutter.resetLinkSent
  ///
  /// In de, this message translates to:
  /// **'Wir haben einen Link zum Zurücksetzen deines Passworts an {email} gesendet.'**
  String loginFlutterResetLinkSent(Object email);

  /// login.flutter.sendLink
  ///
  /// In de, this message translates to:
  /// **'Link senden'**
  String get loginFlutterSendLink;

  /// login.flutter.toLogin
  ///
  /// In de, this message translates to:
  /// **'Zum Login'**
  String get loginFlutterToLogin;

  /// login.flutter.unexpectedError
  ///
  /// In de, this message translates to:
  /// **'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.'**
  String get loginFlutterUnexpectedError;

  /// login.forgotPassword
  ///
  /// In de, this message translates to:
  /// **'Passwort vergessen?'**
  String get loginForgotPassword;

  /// login.installUpdate
  ///
  /// In de, this message translates to:
  /// **'Update installieren'**
  String get loginInstallUpdate;

  /// login.legal
  ///
  /// In de, this message translates to:
  /// **'Impressum & Datenschutz'**
  String get loginLegal;

  /// login.linkAndSignIn
  ///
  /// In de, this message translates to:
  /// **'Verknüpfen & anmelden'**
  String get loginLinkAndSignIn;

  /// login.linkNote
  ///
  /// In de, this message translates to:
  /// **'Verknüpfe dein Attendix-Konto einmalig mit Microsoft. Melde dich mit deinen Attendix-Zugangsdaten an – danach wirst du in Teams automatisch angemeldet.'**
  String get loginLinkNote;

  /// login.modeOtp
  ///
  /// In de, this message translates to:
  /// **'Code per E-Mail'**
  String get loginModeOtp;

  /// login.modePassword
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get loginModePassword;

  /// login.noAccount.header
  ///
  /// In de, this message translates to:
  /// **'Kein Konto gefunden'**
  String get loginNoAccountHeader;

  /// login.noAccount.message
  ///
  /// In de, this message translates to:
  /// **'Für diese E-Mail-Adresse existiert noch kein Konto. Möchtest du dich jetzt registrieren?'**
  String get loginNoAccountMessage;

  /// login.notConfirmed.header
  ///
  /// In de, this message translates to:
  /// **'E-Mail nicht bestätigt'**
  String get loginNotConfirmedHeader;

  /// login.notConfirmed.message
  ///
  /// In de, this message translates to:
  /// **'Deine E-Mail-Adresse wurde noch nicht bestätigt. Möchtest du die Bestätigungs-E-Mail erneut senden?'**
  String get loginNotConfirmedMessage;

  /// login.notConfirmed.resend
  ///
  /// In de, this message translates to:
  /// **'Erneut senden'**
  String get loginNotConfirmedResend;

  /// login.otpLabel
  ///
  /// In de, this message translates to:
  /// **'Code aus der E-Mail'**
  String get loginOtpLabel;

  /// login.password
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get loginPassword;

  /// login.register
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get loginRegister;

  /// login.resendCode
  ///
  /// In de, this message translates to:
  /// **'Code erneut senden'**
  String get loginResendCode;

  /// login.resendIn
  ///
  /// In de, this message translates to:
  /// **'Erneut senden ({seconds}s)'**
  String loginResendIn(Object seconds);

  /// login.reset.confirm
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get loginResetConfirm;

  /// login.reset.header
  ///
  /// In de, this message translates to:
  /// **'Passwort zurücksetzen'**
  String get loginResetHeader;

  /// login.sendCode
  ///
  /// In de, this message translates to:
  /// **'Code senden'**
  String get loginSendCode;

  /// login.showPassword
  ///
  /// In de, this message translates to:
  /// **'Passwort anzeigen'**
  String get loginShowPassword;

  /// login.signIn
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get loginSignIn;

  /// login.startDemo
  ///
  /// In de, this message translates to:
  /// **'Demo starten'**
  String get loginStartDemo;

  /// login.toast.enterEmail
  ///
  /// In de, this message translates to:
  /// **'Bitte gib deine E-Mail-Adresse ein.'**
  String get loginToastEnterEmail;

  /// login.toast.invalidEmail
  ///
  /// In de, this message translates to:
  /// **'Bitte eine gültige E-Mail Adresse eingeben.'**
  String get loginToastInvalidEmail;

  /// login.toast.msLinked
  ///
  /// In de, this message translates to:
  /// **'Microsoft-Konto verknüpft. Du wirst künftig automatisch angemeldet.'**
  String get loginToastMsLinked;

  /// login.toast.registered
  ///
  /// In de, this message translates to:
  /// **'Registrierung erfolgreich, bitte bestätige deine E-Mail-Adresse.'**
  String get loginToastRegistered;

  /// login.version
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String loginVersion(Object version);

  /// messages.allActive
  ///
  /// In de, this message translates to:
  /// **'Alle aktiven Mitglieder'**
  String get messagesAllActive;

  /// messages.allCount
  ///
  /// In de, this message translates to:
  /// **'Alle {count}'**
  String messagesAllCount(Object count);

  /// messages.countsFailed
  ///
  /// In de, this message translates to:
  /// **'Die Empfänger konnten nicht geladen werden.'**
  String get messagesCountsFailed;

  /// messages.deleteConfirm
  ///
  /// In de, this message translates to:
  /// **'Mitteilung löschen?'**
  String get messagesDeleteConfirm;

  /// messages.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen'**
  String get messagesDeleteFailed;

  /// messages.deleteHint
  ///
  /// In de, this message translates to:
  /// **'Die Mitteilung verschwindet auch bei allen Empfängern aus der App. Bereits versendete E-Mails bleiben bestehen.'**
  String get messagesDeleteHint;

  /// messages.deleteMessage
  ///
  /// In de, this message translates to:
  /// **'Mitteilung löschen'**
  String get messagesDeleteMessage;

  /// messages.earlier
  ///
  /// In de, this message translates to:
  /// **'Frühere Mitteilungen'**
  String get messagesEarlier;

  /// messages.email
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get messagesEmail;

  /// messages.emailBounced
  ///
  /// In de, this message translates to:
  /// **'E-Mail unzustellbar'**
  String get messagesEmailBounced;

  /// messages.emailCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Person hat} other {{count} Personen haben}} eine E-Mail-Adresse'**
  String messagesEmailCount(num count);

  /// messages.emailDelivered
  ///
  /// In de, this message translates to:
  /// **'E-Mail zugestellt'**
  String get messagesEmailDelivered;

  /// messages.emailDeliveredChip
  ///
  /// In de, this message translates to:
  /// **'E-Mail zugestellt'**
  String get messagesEmailDeliveredChip;

  /// messages.emailFailed
  ///
  /// In de, this message translates to:
  /// **'E-Mail fehlgeschlagen'**
  String get messagesEmailFailed;

  /// messages.emailOpened
  ///
  /// In de, this message translates to:
  /// **'E-Mail geöffnet {time}'**
  String messagesEmailOpened(Object time);

  /// messages.emailOpenedApprox
  ///
  /// In de, this message translates to:
  /// **'E-Mail geöffnet (ungefähr)'**
  String get messagesEmailOpenedApprox;

  /// messages.emailPending
  ///
  /// In de, this message translates to:
  /// **'E-Mail ausstehend'**
  String get messagesEmailPending;

  /// messages.emailSent
  ///
  /// In de, this message translates to:
  /// **'E-Mail gesendet'**
  String get messagesEmailSent;

  /// messages.flutter.hideMessage
  ///
  /// In de, this message translates to:
  /// **'Nachricht ausblenden'**
  String get messagesFlutterHideMessage;

  /// messages.flutter.problems
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Problem} other {{count} Probleme}}'**
  String messagesFlutterProblems(num count);

  /// messages.flutter.showMessage
  ///
  /// In de, this message translates to:
  /// **'Nachricht anzeigen'**
  String get messagesFlutterShowMessage;

  /// messages.from
  ///
  /// In de, this message translates to:
  /// **'Von {name} · {date}'**
  String messagesFrom(Object name, Object date);

  /// messages.inclMainGroup
  ///
  /// In de, this message translates to:
  /// **'inkl. Hauptgruppe'**
  String get messagesInclMainGroup;

  /// messages.isSending
  ///
  /// In de, this message translates to:
  /// **'Mitteilung wird versendet'**
  String get messagesIsSending;

  /// messages.listLoadFailed
  ///
  /// In de, this message translates to:
  /// **'Mitteilungen konnten nicht geladen werden'**
  String get messagesListLoadFailed;

  /// messages.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Mitteilung konnte nicht geladen werden'**
  String get messagesLoadFailed;

  /// messages.message
  ///
  /// In de, this message translates to:
  /// **'Mitteilung'**
  String get messagesMessage;

  /// messages.messages
  ///
  /// In de, this message translates to:
  /// **'Mitteilungen'**
  String get messagesMessages;

  /// messages.newMessage
  ///
  /// In de, this message translates to:
  /// **'Neue Mitteilung'**
  String get messagesNewMessage;

  /// messages.noAccount
  ///
  /// In de, this message translates to:
  /// **'Kein App-Konto'**
  String get messagesNoAccount;

  /// messages.noAccountNoEmail
  ///
  /// In de, this message translates to:
  /// **'Kein App-Konto, keine E-Mail'**
  String get messagesNoAccountNoEmail;

  /// messages.noEmail
  ///
  /// In de, this message translates to:
  /// **'Keine E-Mail'**
  String get messagesNoEmail;

  /// messages.noPeopleView
  ///
  /// In de, this message translates to:
  /// **'Keine Personen in dieser Ansicht.'**
  String get messagesNoPeopleView;

  /// messages.none
  ///
  /// In de, this message translates to:
  /// **'Noch keine Mitteilungen'**
  String get messagesNone;

  /// messages.noneHint
  ///
  /// In de, this message translates to:
  /// **'Informiere deine Gruppe mit einer Mitteilung und sieh direkt, wer sie schon gelesen hat.'**
  String get messagesNoneHint;

  /// messages.notAvailable
  ///
  /// In de, this message translates to:
  /// **'Diese Mitteilung gibt es nicht mehr oder du hast keinen Zugriff darauf.'**
  String get messagesNotAvailable;

  /// messages.onlyGroups
  ///
  /// In de, this message translates to:
  /// **'Nur bestimmte Gruppen'**
  String get messagesOnlyGroups;

  /// messages.openCount
  ///
  /// In de, this message translates to:
  /// **'Offen {count}'**
  String messagesOpenCount(Object count);

  /// messages.openedEstimate
  ///
  /// In de, this message translates to:
  /// **'„Geöffnet“ bei E-Mails ist ein Schätzwert: manche Mail-Apps laden Bilder vorab, andere blockieren sie.'**
  String get messagesOpenedEstimate;

  /// messages.overview
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get messagesOverview;

  /// messages.problemsCount
  ///
  /// In de, this message translates to:
  /// **'Probleme {count}'**
  String messagesProblemsCount(Object count);

  /// messages.push
  ///
  /// In de, this message translates to:
  /// **'Push'**
  String get messagesPush;

  /// messages.pushCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Person hat} other {{count} Personen haben}} Mitteilungen aktiviert'**
  String messagesPushCount(num count);

  /// messages.pushDelivered
  ///
  /// In de, this message translates to:
  /// **'Push/Telegram zugestellt'**
  String get messagesPushDelivered;

  /// messages.pushFailed
  ///
  /// In de, this message translates to:
  /// **'Push fehlgeschlagen'**
  String get messagesPushFailed;

  /// messages.pushOff
  ///
  /// In de, this message translates to:
  /// **'Push aus'**
  String get messagesPushOff;

  /// messages.pushTelegram
  ///
  /// In de, this message translates to:
  /// **'Push / Telegram'**
  String get messagesPushTelegram;

  /// messages.readAt
  ///
  /// In de, this message translates to:
  /// **'✓ Gelesen {time}'**
  String messagesReadAt(Object time);

  /// messages.readCount
  ///
  /// In de, this message translates to:
  /// **'Gelesen {count}'**
  String messagesReadCount(Object count);

  /// messages.readInApp
  ///
  /// In de, this message translates to:
  /// **'in der App gelesen'**
  String get messagesReadInApp;

  /// messages.readOf
  ///
  /// In de, this message translates to:
  /// **'{read} von {total} gelesen'**
  String messagesReadOf(Object read, Object total);

  /// messages.recipients
  ///
  /// In de, this message translates to:
  /// **'Empfänger'**
  String get messagesRecipients;

  /// messages.recipientsSummary
  ///
  /// In de, this message translates to:
  /// **'<strong>{count, plural, one {{count} Person} other {{count} Personen}}</strong> erhalten diese Mitteilung.'**
  String messagesRecipientsSummary(num count);

  /// messages.retry
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get messagesRetry;

  /// messages.send
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get messagesSend;

  /// messages.sendConfirm
  ///
  /// In de, this message translates to:
  /// **'Mitteilung senden?'**
  String get messagesSendConfirm;

  /// messages.sendConfirmMessage
  ///
  /// In de, this message translates to:
  /// **'„{title}“ geht an {count, plural, one {{count} Person} other {{count} Personen}} ({channels}). Das kann nicht rückgängig gemacht werden.'**
  String messagesSendConfirmMessage(Object title, num count, Object channels);

  /// messages.sendFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Versenden, bitte versuche es erneut.'**
  String get messagesSendFailed;

  /// messages.sendVia
  ///
  /// In de, this message translates to:
  /// **'Versand über'**
  String get messagesSendVia;

  /// messages.sending
  ///
  /// In de, this message translates to:
  /// **'Versand läuft …'**
  String get messagesSending;

  /// messages.sendingNow
  ///
  /// In de, this message translates to:
  /// **'Wird versendet …'**
  String get messagesSendingNow;

  /// messages.sent
  ///
  /// In de, this message translates to:
  /// **'Gesendet'**
  String get messagesSent;

  /// messages.stillSending
  ///
  /// In de, this message translates to:
  /// **'Der Versand läuft noch. Ziehe nach unten, um zu aktualisieren.'**
  String get messagesStillSending;

  /// messages.telegram
  ///
  /// In de, this message translates to:
  /// **'Telegram'**
  String get messagesTelegram;

  /// messages.title
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get messagesTitle;

  /// messages.titlePlaceholder
  ///
  /// In de, this message translates to:
  /// **'z. B. Probe am Samstag fällt aus'**
  String get messagesTitlePlaceholder;

  /// messages.toPeople
  ///
  /// In de, this message translates to:
  /// **'an {count, plural, one {{count} Person} other {{count} Personen}}'**
  String messagesToPeople(num count);

  /// messages.unreachable
  ///
  /// In de, this message translates to:
  /// **'Nicht erreichbar'**
  String get messagesUnreachable;

  /// messages.unreachableSummary
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Person ist über keinen Kanal erreichbar und sieht} other {{count} Personen sind über keinen Kanal erreichbar und sehen}} die Mitteilung nur, wenn sie die App öffnen.'**
  String messagesUnreachableSummary(num count);

  /// messages.unread
  ///
  /// In de, this message translates to:
  /// **'Ungelesen'**
  String get messagesUnread;

  /// messages.viaEmail
  ///
  /// In de, this message translates to:
  /// **'{count} per E-Mail'**
  String messagesViaEmail(Object count);

  /// messages.viaPush
  ///
  /// In de, this message translates to:
  /// **'{count} per Push/Telegram'**
  String messagesViaPush(Object count);

  /// messages.writeFirst
  ///
  /// In de, this message translates to:
  /// **'Erste Mitteilung schreiben'**
  String get messagesWriteFirst;

  /// notif.announcements
  ///
  /// In de, this message translates to:
  /// **'Mitteilungen'**
  String get notifAnnouncements;

  /// notif.announcementsHelper
  ///
  /// In de, this message translates to:
  /// **'Nachrichten von Admins und Verantwortlichen deiner Instanz'**
  String get notifAnnouncementsHelper;

  /// notif.appUpdates
  ///
  /// In de, this message translates to:
  /// **'App-Updates'**
  String get notifAppUpdates;

  /// notif.appUpdatesHelper
  ///
  /// In de, this message translates to:
  /// **'Erhalte Benachrichtigungen über App-Updates sobald verfügbar'**
  String get notifAppUpdatesHelper;

  /// notif.birthdays
  ///
  /// In de, this message translates to:
  /// **'Geburtstage'**
  String get notifBirthdays;

  /// notif.birthdaysHelper
  ///
  /// In de, this message translates to:
  /// **'Erhalte täglich um 8:00 Uhr eine Benachrichtigung, falls jemand heute Geburtstag hat'**
  String get notifBirthdaysHelper;

  /// notif.bothChannels
  ///
  /// In de, this message translates to:
  /// **'Beide Kanäle gleichzeitig'**
  String get notifBothChannels;

  /// notif.bothChannelsHelper
  ///
  /// In de, this message translates to:
  /// **'Push und Telegram werden parallel gesendet, nicht nur als Fallback.'**
  String get notifBothChannelsHelper;

  /// notif.checklist
  ///
  /// In de, this message translates to:
  /// **'Checklisten-Erinnerungen'**
  String get notifChecklist;

  /// notif.checklistHelper
  ///
  /// In de, this message translates to:
  /// **'Erhalte Erinnerungen für fällige To-Dos in deiner Checkliste. Nur möglich, wenn du Verantwortlicher einer Gruppe bist.'**
  String get notifChecklistHelper;

  /// notif.connect
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get notifConnect;

  /// notif.disconnect
  ///
  /// In de, this message translates to:
  /// **'Trennen'**
  String get notifDisconnect;

  /// notif.disconnectConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die Verbindung wirklich trennen?'**
  String get notifDisconnectConfirm;

  /// notif.disconnectHint
  ///
  /// In de, this message translates to:
  /// **'Die Verbindung kann jederzeit wiederhergestellt werden'**
  String get notifDisconnectHint;

  /// notif.duties
  ///
  /// In de, this message translates to:
  /// **'Dienste'**
  String get notifDuties;

  /// notif.dutiesHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn du für einen Dienst eingeteilt wirst, an die Bestätigung erinnert wirst oder jemand zum Einspringen gesucht wird. Dringende Anfragen kommen trotzdem an.'**
  String get notifDutiesHelper;

  /// notif.enable
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen aktivieren'**
  String get notifEnable;

  /// notif.eventReminders
  ///
  /// In de, this message translates to:
  /// **'Terminerinnerungen'**
  String get notifEventReminders;

  /// notif.flutter.configNotFound
  ///
  /// In de, this message translates to:
  /// **'Konfiguration nicht gefunden'**
  String get notifFlutterConfigNotFound;

  /// notif.flutter.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden: {error}'**
  String notifFlutterLoadFailed(Object error);

  /// notif.flutter.telegramOpenFailed
  ///
  /// In de, this message translates to:
  /// **'Konnte Telegram nicht öffnen'**
  String get notifFlutterTelegramOpenFailed;

  /// notif.flutter.updateFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Konfiguration'**
  String get notifFlutterUpdateFailed;

  /// notif.flutter.userIdCopied
  ///
  /// In de, this message translates to:
  /// **'Benutzer-Id kopiert'**
  String get notifFlutterUserIdCopied;

  /// notif.linked
  ///
  /// In de, this message translates to:
  /// **'Konto erfolgreich verknüpft'**
  String get notifLinked;

  /// notif.liveActivity
  ///
  /// In de, this message translates to:
  /// **'Laufender Ablaufplan'**
  String get notifLiveActivity;

  /// notif.liveActivityHelper
  ///
  /// In de, this message translates to:
  /// **'Zeigt den aktuellen Punkt eines laufenden Ablaufplans auf dem Sperrbildschirm.'**
  String get notifLiveActivityHelper;

  /// notif.liveActivityHelperIos
  ///
  /// In de, this message translates to:
  /// **'Zeigt den aktuellen Punkt eines laufenden Ablaufplans auf dem Sperrbildschirm und in der Dynamic Island.'**
  String get notifLiveActivityHelperIos;

  /// notif.newProblemCases
  ///
  /// In de, this message translates to:
  /// **'Neue Problemfälle'**
  String get notifNewProblemCases;

  /// notif.newRegistrations
  ///
  /// In de, this message translates to:
  /// **'Neu-Registrierungen'**
  String get notifNewRegistrations;

  /// notif.push
  ///
  /// In de, this message translates to:
  /// **'Push-Benachrichtigungen'**
  String get notifPush;

  /// notif.pushPreferred
  ///
  /// In de, this message translates to:
  /// **'Push wird bevorzugt. Telegram wird nur als Fallback genutzt, wenn keine Push-Zustellung möglich ist.'**
  String get notifPushPreferred;

  /// notif.responsibleOnly
  ///
  /// In de, this message translates to:
  /// **'Nur möglich, wenn du Verantwortlicher einer Gruppe bist.'**
  String get notifResponsibleOnly;

  /// notif.signIns
  ///
  /// In de, this message translates to:
  /// **'Anmeldungen'**
  String get notifSignIns;

  /// notif.signOuts
  ///
  /// In de, this message translates to:
  /// **'Abmeldungen'**
  String get notifSignOuts;

  /// notif.tasks
  ///
  /// In de, this message translates to:
  /// **'Aufgaben-Erinnerungen'**
  String get notifTasks;

  /// notif.tasksHelper
  ///
  /// In de, this message translates to:
  /// **'Erhalte Erinnerungen 2 Tage vor Fälligkeit von Aufgaben, für die du verantwortlich bist.'**
  String get notifTasksHelper;

  /// notif.telegram
  ///
  /// In de, this message translates to:
  /// **'Telegramverknüpfung'**
  String get notifTelegram;

  /// notif.tenantSettings
  ///
  /// In de, this message translates to:
  /// **'Instanz-Einstellungen'**
  String get notifTenantSettings;

  /// notif.title
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen'**
  String get notifTitle;

  /// notif.userId
  ///
  /// In de, this message translates to:
  /// **'Benutzer-Id'**
  String get notifUserId;

  /// openFile.linkFailed
  ///
  /// In de, this message translates to:
  /// **'Der Link konnte nicht geöffnet werden.'**
  String get openFileLinkFailed;

  /// openFile.noTenantAccess
  ///
  /// In de, this message translates to:
  /// **'Du hast keinen Zugriff auf diese Instanz.'**
  String get openFileNoTenantAccess;

  /// org.appearancePlans
  ///
  /// In de, this message translates to:
  /// **'Darstellung & Pläne'**
  String get orgAppearancePlans;

  /// org.choose
  ///
  /// In de, this message translates to:
  /// **'Auswählen'**
  String get orgChoose;

  /// org.create
  ///
  /// In de, this message translates to:
  /// **'Organisation erstellen'**
  String get orgCreate;

  /// org.createNew
  ///
  /// In de, this message translates to:
  /// **'Neue Organisation erstellen'**
  String get orgCreateNew;

  /// org.createOrLink
  ///
  /// In de, this message translates to:
  /// **'Organisation erstellen / verknüpfen'**
  String get orgCreateOrLink;

  /// org.created
  ///
  /// In de, this message translates to:
  /// **'Die Organisation wurde erfolgreich erstellt.'**
  String get orgCreated;

  /// org.disable
  ///
  /// In de, this message translates to:
  /// **'Deaktivieren'**
  String get orgDisable;

  /// org.disableSync
  ///
  /// In de, this message translates to:
  /// **'Synchronisierung deaktivieren?'**
  String get orgDisableSync;

  /// org.disableSyncMessage
  ///
  /// In de, this message translates to:
  /// **'Die Werke dieser Instanz sind danach leer, bis eigene Werke angelegt werden. Historieneinträge auf Werke der Quellinstanz können nicht mehr aufgelöst werden.'**
  String get orgDisableSyncMessage;

  /// orgFields.addOption
  ///
  /// In de, this message translates to:
  /// **'Bitte füge mindestens eine Auswahloption hinzu.'**
  String get orgFieldsAddOption;

  /// orgFields.applyChanges
  ///
  /// In de, this message translates to:
  /// **'Änderungen übernehmen'**
  String get orgFieldsApplyChanges;

  /// orgFields.flutter.firstOptionDefault
  ///
  /// In de, this message translates to:
  /// **'Erste Option ist der Standardwert'**
  String get orgFieldsFlutterFirstOptionDefault;

  /// orgFields.intro
  ///
  /// In de, this message translates to:
  /// **'Diese Felder und ihre Werte gelten für dieselbe Person gemeinsam in allen Instanzen der Organisation.'**
  String get orgFieldsIntro;

  /// orgFields.invalid
  ///
  /// In de, this message translates to:
  /// **'Ungültige Organisations-Zusatzfelder.'**
  String get orgFieldsInvalid;

  /// orgFields.nameExists
  ///
  /// In de, this message translates to:
  /// **'Ein Zusatzfeld mit diesem Namen existiert bereits.'**
  String get orgFieldsNameExists;

  /// orgFields.needsOptions
  ///
  /// In de, this message translates to:
  /// **'Das Auswahlfeld „{name}“ benötigt Optionen.'**
  String orgFieldsNeedsOptions(Object name);

  /// orgFields.none
  ///
  /// In de, this message translates to:
  /// **'Es wurden noch keine organisationsweiten Zusatzfelder hinzugefügt.'**
  String get orgFieldsNone;

  /// orgFields.saved
  ///
  /// In de, this message translates to:
  /// **'Organisations-Zusatzfelder gespeichert.'**
  String get orgFieldsSaved;

  /// orgFields.title
  ///
  /// In de, this message translates to:
  /// **'Personen-Zusatzfelder'**
  String get orgFieldsTitle;

  /// org.flutter.fieldCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Feld} other {{count} Felder}}'**
  String orgFlutterFieldCount(num count);

  /// org.flutter.noFields
  ///
  /// In de, this message translates to:
  /// **'Keine Felder'**
  String get orgFlutterNoFields;

  /// org.flutter.unlinkFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Trennen'**
  String get orgFlutterUnlinkFailed;

  /// org.handover
  ///
  /// In de, this message translates to:
  /// **'Übergabe'**
  String get orgHandover;

  /// org.linkPersonsHint
  ///
  /// In de, this message translates to:
  /// **'Personen aus verschiedenen Instanzen miteinander verbinden'**
  String get orgLinkPersonsHint;

  /// org.namePh
  ///
  /// In de, this message translates to:
  /// **'Name eingeben...'**
  String get orgNamePh;

  /// org.noneAdminOnly
  ///
  /// In de, this message translates to:
  /// **'Diese Instanz ist keiner Organisation zugewiesen. Nur Administratoren können Organisationen verwalten.'**
  String get orgNoneAdminOnly;

  /// org.noneIntro
  ///
  /// In de, this message translates to:
  /// **'Erstelle eine neue Organisation oder verknüpfe diese Instanz mit einer bestehenden, um Personen organisationsweit zu verbinden und gemeinsame Pläne zu nutzen.'**
  String get orgNoneIntro;

  /// org.noneLinked
  ///
  /// In de, this message translates to:
  /// **'Keine Organisation verknüpft'**
  String get orgNoneLinked;

  /// org.noneOwnSongs
  ///
  /// In de, this message translates to:
  /// **'Keine (eigene Werke)'**
  String get orgNoneOwnSongs;

  /// org.orgPlans
  ///
  /// In de, this message translates to:
  /// **'Org-Pläne'**
  String get orgOrgPlans;

  /// org.personFields
  ///
  /// In de, this message translates to:
  /// **'Personen-Zusatzfelder'**
  String get orgPersonFields;

  /// org.personFieldsHint
  ///
  /// In de, this message translates to:
  /// **'Felder und Werte für verknüpfte Personen gemeinsam verwalten'**
  String get orgPersonFieldsHint;

  /// org.persons
  ///
  /// In de, this message translates to:
  /// **'Personen'**
  String get orgPersons;

  /// org.pleaseSelect
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle eine Organisation aus.'**
  String get orgPleaseSelect;

  /// org.rename
  ///
  /// In de, this message translates to:
  /// **'Organisation umbenennen'**
  String get orgRename;

  /// org.renamed
  ///
  /// In de, this message translates to:
  /// **'Organisation umbenannt'**
  String get orgRenamed;

  /// org.select
  ///
  /// In de, this message translates to:
  /// **'Organisation auswählen'**
  String get orgSelect;

  /// org.selected
  ///
  /// In de, this message translates to:
  /// **'Die Organisation wurde erfolgreich ausgewählt.'**
  String get orgSelected;

  /// org.songSync
  ///
  /// In de, this message translates to:
  /// **'Werk-Synchronisierung'**
  String get orgSongSync;

  /// org.songSyncIntro
  ///
  /// In de, this message translates to:
  /// **'Werke einer anderen Instanz verwenden. Alle Änderungen werden dort gespeichert.'**
  String get orgSongSyncIntro;

  /// org.sourceTenant
  ///
  /// In de, this message translates to:
  /// **'Quellinstanz'**
  String get orgSourceTenant;

  /// org.syncSaved
  ///
  /// In de, this message translates to:
  /// **'Werk-Synchronisierung gespeichert.'**
  String get orgSyncSaved;

  /// org.tapRename
  ///
  /// In de, this message translates to:
  /// **'Tippen zum Umbenennen'**
  String get orgTapRename;

  /// orgTemplates.addTemplate
  ///
  /// In de, this message translates to:
  /// **'Vorlage hinzufügen'**
  String get orgTemplatesAddTemplate;

  /// orgTemplates.defaultFields
  ///
  /// In de, this message translates to:
  /// **'Standardfelder'**
  String get orgTemplatesDefaultFields;

  /// orgTemplates.defaultFieldsHint
  ///
  /// In de, this message translates to:
  /// **'Standardfelder erscheinen im Planungs-Menü als schnell hinzufügbare Felder für alle Instanzen der Organisation.'**
  String get orgTemplatesDefaultFieldsHint;

  /// orgTemplates.duration
  ///
  /// In de, this message translates to:
  /// **'{h} h {m} min'**
  String orgTemplatesDuration(Object h, Object m);

  /// orgTemplates.durationH
  ///
  /// In de, this message translates to:
  /// **'{h} h'**
  String orgTemplatesDurationH(Object h);

  /// orgTemplates.endApprox
  ///
  /// In de, this message translates to:
  /// **'Ende ca. {time}'**
  String orgTemplatesEndApprox(Object time);

  /// orgTemplates.enterFieldName
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Feldnamen eingeben.'**
  String get orgTemplatesEnterFieldName;

  /// orgTemplates.enterName
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Namen eingeben.'**
  String get orgTemplatesEnterName;

  /// orgTemplates.fieldName
  ///
  /// In de, this message translates to:
  /// **'Feldname'**
  String get orgTemplatesFieldName;

  /// orgTemplates.fieldNamePh
  ///
  /// In de, this message translates to:
  /// **'Feldname...'**
  String get orgTemplatesFieldNamePh;

  /// orgTemplates.minutes
  ///
  /// In de, this message translates to:
  /// **'Minuten'**
  String get orgTemplatesMinutes;

  /// orgTemplates.noDefaultFields
  ///
  /// In de, this message translates to:
  /// **'Noch keine Standardfelder definiert'**
  String get orgTemplatesNoDefaultFields;

  /// orgTemplates.noTemplates
  ///
  /// In de, this message translates to:
  /// **'Noch keine Vorlagen definiert'**
  String get orgTemplatesNoTemplates;

  /// orgTemplates.performerOptPh
  ///
  /// In de, this message translates to:
  /// **'Ausführender (optional)...'**
  String get orgTemplatesPerformerOptPh;

  /// orgTemplates.renameTemplate
  ///
  /// In de, this message translates to:
  /// **'Vorlage umbenennen'**
  String get orgTemplatesRenameTemplate;

  /// orgTemplates.songPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Werk-Platzhalter'**
  String get orgTemplatesSongPlaceholder;

  /// orgTemplates.templateNamePh
  ///
  /// In de, this message translates to:
  /// **'Name der Vorlage...'**
  String get orgTemplatesTemplateNamePh;

  /// orgTemplates.templates
  ///
  /// In de, this message translates to:
  /// **'Vorlagen'**
  String get orgTemplatesTemplates;

  /// orgTemplates.templatesHint
  ///
  /// In de, this message translates to:
  /// **'Vorlagen können beim Planen mit einem Tippen auf das Programm angewendet werden und ersetzen dabei den aktuellen Ablauf.'**
  String get orgTemplatesTemplatesHint;

  /// orgTemplates.title
  ///
  /// In de, this message translates to:
  /// **'Planvorlagen & Felder'**
  String get orgTemplatesTitle;

  /// org.tenants
  ///
  /// In de, this message translates to:
  /// **'Instanzen'**
  String get orgTenants;

  /// org.thisTenant
  ///
  /// In de, this message translates to:
  /// **'Diese Instanz'**
  String get orgThisTenant;

  /// org.title
  ///
  /// In de, this message translates to:
  /// **'Organisation'**
  String get orgTitle;

  /// org.unlink
  ///
  /// In de, this message translates to:
  /// **'Organisation von Instanz trennen?'**
  String get orgUnlink;

  /// org.unlinkButton
  ///
  /// In de, this message translates to:
  /// **'Trennen'**
  String get orgUnlinkButton;

  /// org.unlinkMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die Organisation „{name}“ wirklich von der Instanz trennen?'**
  String orgUnlinkMessage(Object name);

  /// org.unlinkTenant
  ///
  /// In de, this message translates to:
  /// **'Instanz trennen'**
  String get orgUnlinkTenant;

  /// org.unlinked
  ///
  /// In de, this message translates to:
  /// **'Die Organisation wurde erfolgreich von der Instanz getrennt.'**
  String get orgUnlinked;

  /// org.validName
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen gültigen Namen ein.'**
  String get orgValidName;

  /// people.activate
  ///
  /// In de, this message translates to:
  /// **'Aktivieren'**
  String get peopleActivate;

  /// people.activating
  ///
  /// In de, this message translates to:
  /// **'Wird aktiviert...'**
  String get peopleActivating;

  /// people.activeAgain
  ///
  /// In de, this message translates to:
  /// **'Person wieder aktiv'**
  String get peopleActiveAgain;

  /// people.activePeople
  ///
  /// In de, this message translates to:
  /// **'Aktive Personen'**
  String get peopleActivePeople;

  /// people.ageShort
  ///
  /// In de, this message translates to:
  /// **'{date} ({age} J.)'**
  String peopleAgeShort(Object date, Object age);

  /// people.ageYears
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Jahr} other {{count} Jahre}}'**
  String peopleAgeYears(num count);

  /// people.andMore
  ///
  /// In de, this message translates to:
  /// **'… und {count} weitere'**
  String peopleAndMore(Object count);

  /// people.archive
  ///
  /// In de, this message translates to:
  /// **'Archivieren'**
  String get peopleArchive;

  /// people.archiveTitle
  ///
  /// In de, this message translates to:
  /// **'{name} Archivieren'**
  String peopleArchiveTitle(Object name);

  /// people.attendance
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit'**
  String get peopleAttendance;

  /// people.attendanceAsc
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit ↑'**
  String get peopleAttendanceAsc;

  /// people.attendanceDesc
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit ↓'**
  String get peopleAttendanceDesc;

  /// people.birthday
  ///
  /// In de, this message translates to:
  /// **'Geburtsdatum'**
  String get peopleBirthday;

  /// people.birthdayAsc
  ///
  /// In de, this message translates to:
  /// **'Geburtsdatum ↑'**
  String get peopleBirthdayAsc;

  /// people.birthdayDesc
  ///
  /// In de, this message translates to:
  /// **'Geburtsdatum ↓'**
  String get peopleBirthdayDesc;

  /// people.birthdayToday
  ///
  /// In de, this message translates to:
  /// **'Geburtstag heute'**
  String get peopleBirthdayToday;

  /// people.birthdaysToday
  ///
  /// In de, this message translates to:
  /// **'{count} Geburtstage heute'**
  String peopleBirthdaysToday(Object count);

  /// people.bulkEdit
  ///
  /// In de, this message translates to:
  /// **'Bulk-Bearbeitung'**
  String get peopleBulkEdit;

  /// people.bulkEditHint
  ///
  /// In de, this message translates to:
  /// **'Wähle ein Feld aus, um die Werte für alle Personen zu bearbeiten.'**
  String get peopleBulkEditHint;

  /// people.candidate
  ///
  /// In de, this message translates to:
  /// **'Prüfling'**
  String get peopleCandidate;

  /// people.candidates
  ///
  /// In de, this message translates to:
  /// **'Prüflinge'**
  String get peopleCandidates;

  /// people.cannotRemoveSelf
  ///
  /// In de, this message translates to:
  /// **'Du kannst dich nicht selbst entfernen!'**
  String get peopleCannotRemoveSelf;

  /// people.cannotUndoExcl
  ///
  /// In de, this message translates to:
  /// **'Diese Aktion kann nicht rückgängig gemacht werden!'**
  String get peopleCannotUndoExcl;

  /// people.checkingData
  ///
  /// In de, this message translates to:
  /// **'Daten werden geprüft...'**
  String get peopleCheckingData;

  /// people.chooseField
  ///
  /// In de, this message translates to:
  /// **'Feld auswählen'**
  String get peopleChooseField;

  /// people.chooseFieldPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Feld wählen...'**
  String get peopleChooseFieldPlaceholder;

  /// people.chooseFile
  ///
  /// In de, this message translates to:
  /// **'Datei auswählen'**
  String get peopleChooseFile;

  /// people.chooseGroupPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Gruppe wählen...'**
  String get peopleChooseGroupPlaceholder;

  /// people.chooseInstance
  ///
  /// In de, this message translates to:
  /// **'Instanz wählen'**
  String get peopleChooseInstance;

  /// people.createAccounts
  ///
  /// In de, this message translates to:
  /// **'Konten erstellen'**
  String get peopleCreateAccounts;

  /// people.createAccountsHint
  ///
  /// In de, this message translates to:
  /// **'Für Personen mit E-Mail-Adresse werden Benutzerkonten erstellt und Einladungs-E-Mails versendet.'**
  String get peopleCreateAccountsHint;

  /// people.current
  ///
  /// In de, this message translates to:
  /// **'Aktuell'**
  String get peopleCurrent;

  /// people.demoUnavailable
  ///
  /// In de, this message translates to:
  /// **'Diese Funktion ist im Demo-Modus nicht verfügbar.'**
  String get peopleDemoUnavailable;

  /// people.downloadTemplate
  ///
  /// In de, this message translates to:
  /// **'Vorlage herunterladen'**
  String get peopleDownloadTemplate;

  /// people.duplicates
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Duplikat} other {{count} Duplikate}}'**
  String peopleDuplicates(num count);

  /// people.email
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get peopleEmail;

  /// people.enterValue
  ///
  /// In de, this message translates to:
  /// **'Wert eingeben'**
  String get peopleEnterValue;

  /// people.errorAt
  ///
  /// In de, this message translates to:
  /// **'Fehler bei {tenant}: {error}'**
  String peopleErrorAt(Object tenant, Object error);

  /// people.extraFields
  ///
  /// In de, this message translates to:
  /// **'Zusatzfelder'**
  String get peopleExtraFields;

  /// people.failedCount
  ///
  /// In de, this message translates to:
  /// **'{count} fehlgeschlagen.'**
  String peopleFailedCount(Object count);

  /// people.faulty
  ///
  /// In de, this message translates to:
  /// **'{count} fehlerhaft'**
  String peopleFaulty(Object count);

  /// people.fileEmpty
  ///
  /// In de, this message translates to:
  /// **'Die Datei enthält keine Daten.'**
  String get peopleFileEmpty;

  /// people.fileRows
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Zeile} other {{count} Zeilen}}'**
  String peopleFileRows(num count);

  /// people.fileUnreadable
  ///
  /// In de, this message translates to:
  /// **'Die Datei konnte nicht gelesen werden.'**
  String get peopleFileUnreadable;

  /// people.filter
  ///
  /// In de, this message translates to:
  /// **'Filtern'**
  String get peopleFilter;

  /// people.filtersNoMatch
  ///
  /// In de, this message translates to:
  /// **'Die aktiven Filter ergeben keine Treffer.'**
  String get peopleFiltersNoMatch;

  /// people.firstName
  ///
  /// In de, this message translates to:
  /// **'Vorname'**
  String get peopleFirstName;

  /// people.flutter.ageFrom
  ///
  /// In de, this message translates to:
  /// **'Ab'**
  String get peopleFlutterAgeFrom;

  /// people.flutter.ageSuffix
  ///
  /// In de, this message translates to:
  /// **'J.'**
  String get peopleFlutterAgeSuffix;

  /// people.flutter.ageTo
  ///
  /// In de, this message translates to:
  /// **'Bis'**
  String get peopleFlutterAgeTo;

  /// people.flutter.attention
  ///
  /// In de, this message translates to:
  /// **'Achtung'**
  String get peopleFlutterAttention;

  /// people.flutter.bulkUpdated
  ///
  /// In de, this message translates to:
  /// **'{count} Person(en) aktualisiert'**
  String peopleFlutterBulkUpdated(Object count);

  /// people.flutter.contact.call
  ///
  /// In de, this message translates to:
  /// **'Anrufen'**
  String get peopleFlutterContactCall;

  /// people.flutter.contact.mail
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get peopleFlutterContactMail;

  /// people.flutter.contact.mailHint
  ///
  /// In de, this message translates to:
  /// **'E-Mail schreiben'**
  String get peopleFlutterContactMailHint;

  /// people.flutter.contact.telegramHint
  ///
  /// In de, this message translates to:
  /// **'Per Telegram schreiben'**
  String get peopleFlutterContactTelegramHint;

  /// people.flutter.contact.whatsAppHint
  ///
  /// In de, this message translates to:
  /// **'Per WhatsApp schreiben'**
  String get peopleFlutterContactWhatsAppHint;

  /// people.flutter.createAnyway
  ///
  /// In de, this message translates to:
  /// **'Trotzdem erstellen'**
  String get peopleFlutterCreateAnyway;

  /// people.flutter.defaultView
  ///
  /// In de, this message translates to:
  /// **'Standard'**
  String get peopleFlutterDefaultView;

  /// people.flutter.deselectAll
  ///
  /// In de, this message translates to:
  /// **'Auswahl aufheben'**
  String get peopleFlutterDeselectAll;

  /// people.flutter.duplicateMessage
  ///
  /// In de, this message translates to:
  /// **'Eine Person mit dem Namen \"{name}\" existiert bereits ({count}x). Trotzdem erstellen?'**
  String peopleFlutterDuplicateMessage(Object name, Object count);

  /// people.flutter.errorWith
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String peopleFlutterErrorWith(Object error);

  /// people.flutter.firstNameRequired
  ///
  /// In de, this message translates to:
  /// **'Vorname ist erforderlich'**
  String get peopleFlutterFirstNameRequired;

  /// people.flutter.groupsLoadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Gruppen'**
  String get peopleFlutterGroupsLoadFailed;

  /// people.flutter.handover.copied
  ///
  /// In de, this message translates to:
  /// **'{count} Spieler erfolgreich kopiert'**
  String peopleFlutterHandoverCopied(Object count);

  /// people.flutter.handover.copy
  ///
  /// In de, this message translates to:
  /// **'Kopieren'**
  String get peopleFlutterHandoverCopy;

  /// people.flutter.handover.copyConfirm
  ///
  /// In de, this message translates to:
  /// **'{count} Spieler nach \"{tenant}\" kopieren?'**
  String peopleFlutterHandoverCopyConfirm(Object count, Object tenant);

  /// people.flutter.handover.copyNote
  ///
  /// In de, this message translates to:
  /// **'Die ausgewählten Spieler werden in die Ziel-Instanz kopiert. Sie bleiben in dieser Instanz aktiv. Der App-Zugang muss in der Ziel-Instanz neu verknüpft werden.'**
  String get peopleFlutterHandoverCopyNote;

  /// people.flutter.handover.copyQuestion
  ///
  /// In de, this message translates to:
  /// **'Spieler kopieren?'**
  String get peopleFlutterHandoverCopyQuestion;

  /// people.flutter.handover.copyTitle
  ///
  /// In de, this message translates to:
  /// **'Spieler kopieren'**
  String get peopleFlutterHandoverCopyTitle;

  /// people.flutter.handover.count
  ///
  /// In de, this message translates to:
  /// **'{count} von {total} Spieler'**
  String peopleFlutterHandoverCount(Object count, Object total);

  /// people.flutter.handover.mappingHint
  ///
  /// In de, this message translates to:
  /// **'Ordne die Gruppen der Quell-Instanz den Gruppen der Ziel-Instanz zu:'**
  String get peopleFlutterHandoverMappingHint;

  /// people.flutter.handover.mode
  ///
  /// In de, this message translates to:
  /// **'Modus'**
  String get peopleFlutterHandoverMode;

  /// people.flutter.handover.modeCopy
  ///
  /// In de, this message translates to:
  /// **'Spieler werden kopiert (bleiben hier aktiv)'**
  String get peopleFlutterHandoverModeCopy;

  /// people.flutter.handover.modeTransfer
  ///
  /// In de, this message translates to:
  /// **'Spieler werden übertragen (hier archiviert)'**
  String get peopleFlutterHandoverModeTransfer;

  /// people.flutter.handover.noMapping
  ///
  /// In de, this message translates to:
  /// **'-- Nicht zuordnen --'**
  String get peopleFlutterHandoverNoMapping;

  /// people.flutter.handover.noPermission
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung in der Ziel-Instanz'**
  String get peopleFlutterHandoverNoPermission;

  /// people.flutter.handover.noTenants
  ///
  /// In de, this message translates to:
  /// **'Keine anderen Instanzen verfügbar'**
  String get peopleFlutterHandoverNoTenants;

  /// people.flutter.handover.noTenantsHint
  ///
  /// In de, this message translates to:
  /// **'Du hast nur Zugriff auf eine Instanz. Um Spieler zu übertragen, benötigst du Zugriff auf mindestens zwei Instanzen.'**
  String get peopleFlutterHandoverNoTenantsHint;

  /// people.flutter.handover.partialCopied
  ///
  /// In de, this message translates to:
  /// **'{success} kopiert, {duplicate} bereits vorhanden, {error} fehlgeschlagen'**
  String peopleFlutterHandoverPartialCopied(Object success, Object duplicate, Object error);

  /// people.flutter.handover.partialTransferred
  ///
  /// In de, this message translates to:
  /// **'{success} übertragen, {duplicate} bereits vorhanden, {error} fehlgeschlagen'**
  String peopleFlutterHandoverPartialTransferred(Object success, Object duplicate, Object error);

  /// people.flutter.handover.preparing
  ///
  /// In de, this message translates to:
  /// **'Bereite Übertragung vor...'**
  String get peopleFlutterHandoverPreparing;

  /// people.flutter.handover.progress
  ///
  /// In de, this message translates to:
  /// **'Übertrage {name} ({current}/{total})...'**
  String peopleFlutterHandoverProgress(Object name, Object current, Object total);

  /// people.flutter.handover.targetNotFound
  ///
  /// In de, this message translates to:
  /// **'Ziel-Instanz nicht gefunden'**
  String get peopleFlutterHandoverTargetNotFound;

  /// people.flutter.handover.transferConfirm
  ///
  /// In de, this message translates to:
  /// **'{count} Spieler an \"{tenant}\" übertragen? Die Spieler werden in dieser Instanz archiviert. Dieser Vorgang kann nicht rückgängig gemacht werden.'**
  String peopleFlutterHandoverTransferConfirm(Object count, Object tenant);

  /// people.flutter.handover.transferNote
  ///
  /// In de, this message translates to:
  /// **'Die ausgewählten Spieler werden in die Ziel-Instanz übertragen. Sie werden in dieser Instanz archiviert und der App-Zugang wird getrennt. Dieser Vorgang kann nicht rückgängig gemacht werden.'**
  String get peopleFlutterHandoverTransferNote;

  /// people.flutter.handover.transferQuestion
  ///
  /// In de, this message translates to:
  /// **'Spieler übertragen?'**
  String get peopleFlutterHandoverTransferQuestion;

  /// people.flutter.handover.transferTitle
  ///
  /// In de, this message translates to:
  /// **'Spieler übertragen'**
  String get peopleFlutterHandoverTransferTitle;

  /// people.flutter.handover.transferred
  ///
  /// In de, this message translates to:
  /// **'{count} Spieler erfolgreich übertragen'**
  String peopleFlutterHandoverTransferred(Object count);

  /// people.flutter.handover.transferring
  ///
  /// In de, this message translates to:
  /// **'Wird übertragen...'**
  String get peopleFlutterHandoverTransferring;

  /// people.flutter.hint
  ///
  /// In de, this message translates to:
  /// **'Hinweis'**
  String get peopleFlutterHint;

  /// people.flutter.lastNameRequired
  ///
  /// In de, this message translates to:
  /// **'Nachname ist erforderlich'**
  String get peopleFlutterLastNameRequired;

  /// people.flutter.listLoadFailed
  ///
  /// In de, this message translates to:
  /// **'Die Personenliste konnte nicht geladen werden.'**
  String get peopleFlutterListLoadFailed;

  /// people.flutter.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden'**
  String get peopleFlutterLoadFailed;

  /// people.flutter.notesHint
  ///
  /// In de, this message translates to:
  /// **'Zusätzliche Informationen...'**
  String get peopleFlutterNotesHint;

  /// people.flutter.optional
  ///
  /// In de, this message translates to:
  /// **'{label} (optional)'**
  String peopleFlutterOptional(Object label);

  /// people.flutter.pausedToast
  ///
  /// In de, this message translates to:
  /// **'{name} wurde pausiert'**
  String peopleFlutterPausedToast(Object name);

  /// people.flutter.possibleDuplicate
  ///
  /// In de, this message translates to:
  /// **'Mögliches Duplikat'**
  String get peopleFlutterPossibleDuplicate;

  /// people.flutter.saveOrder
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge speichern'**
  String get peopleFlutterSaveOrder;

  /// people.flutter.selectedCount
  ///
  /// In de, this message translates to:
  /// **'{count} ausgewählt'**
  String peopleFlutterSelectedCount(Object count);

  /// people.flutter.transferCount
  ///
  /// In de, this message translates to:
  /// **'{count} übertragen'**
  String peopleFlutterTransferCount(Object count);

  /// people.flutter.transferPeople
  ///
  /// In de, this message translates to:
  /// **'Personen übertragen'**
  String get peopleFlutterTransferPeople;

  /// people.fromToday
  ///
  /// In de, this message translates to:
  /// **'Ab heute'**
  String get peopleFromToday;

  /// people.fullName
  ///
  /// In de, this message translates to:
  /// **'Name (Vor- und Nachname)'**
  String get peopleFullName;

  /// people.group
  ///
  /// In de, this message translates to:
  /// **'Gruppe'**
  String get peopleGroup;

  /// people.groupPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Gruppe...'**
  String get peopleGroupPlaceholder;

  /// people.ignore
  ///
  /// In de, this message translates to:
  /// **'Ignorieren'**
  String get peopleIgnore;

  /// people.importCount
  ///
  /// In de, this message translates to:
  /// **'{count} importieren'**
  String peopleImportCount(Object count);

  /// people.importIntro
  ///
  /// In de, this message translates to:
  /// **'Importiere Personen aus einer Excel- (.xlsx/.xls) oder CSV-Datei. Die erste Zeile muss Spaltenüberschriften enthalten. Am einfachsten ist es, die Vorlage herunterzuladen und auszufüllen.'**
  String get peopleImportIntro;

  /// people.importPeople
  ///
  /// In de, this message translates to:
  /// **'Personen importieren'**
  String get peopleImportPeople;

  /// people.importProgress
  ///
  /// In de, this message translates to:
  /// **'{done} / {total} importiert...'**
  String peopleImportProgress(Object done, Object total);

  /// people.importedCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Person importiert.} other {{count} Personen importiert.}}'**
  String peopleImportedCount(num count);

  /// people.instruments
  ///
  /// In de, this message translates to:
  /// **'Instrumente'**
  String get peopleInstruments;

  /// people.joinAsc
  ///
  /// In de, this message translates to:
  /// **'Beitrittsdatum ↑'**
  String get peopleJoinAsc;

  /// people.joinDesc
  ///
  /// In de, this message translates to:
  /// **'Beitrittsdatum ↓'**
  String get peopleJoinDesc;

  /// people.joined
  ///
  /// In de, this message translates to:
  /// **'Eingetreten'**
  String get peopleJoined;

  /// people.lastName
  ///
  /// In de, this message translates to:
  /// **'Nachname'**
  String get peopleLastName;

  /// people.leaveDate
  ///
  /// In de, this message translates to:
  /// **'Austrittsdatum'**
  String get peopleLeaveDate;

  /// people.mapNames
  ///
  /// In de, this message translates to:
  /// **'Bitte Spalten für Vor- und Nachnamen zuordnen.'**
  String get peopleMapNames;

  /// people.mappingIntro
  ///
  /// In de, this message translates to:
  /// **'Ordne die Spalten deiner Datei den Personenfeldern zu. Vorname und Nachname (oder eine kombinierte Namensspalte) sind erforderlich.'**
  String get peopleMappingIntro;

  /// people.mappingMissing
  ///
  /// In de, this message translates to:
  /// **'Bitte ordne Spalten für Vor- und Nachnamen zu (oder eine kombinierte Namensspalte).'**
  String get peopleMappingMissing;

  /// people.members
  ///
  /// In de, this message translates to:
  /// **'Mitglieder'**
  String get peopleMembers;

  /// people.membersLoadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Mitglieder.'**
  String get peopleMembersLoadFailed;

  /// people.new
  ///
  /// In de, this message translates to:
  /// **'Neu'**
  String get peopleNew;

  /// people.newPlayers
  ///
  /// In de, this message translates to:
  /// **'Neue Spieler'**
  String get peopleNewPlayers;

  /// people.nextBirthday
  ///
  /// In de, this message translates to:
  /// **'Nächster Geburtstag'**
  String get peopleNextBirthday;

  /// people.noChanges
  ///
  /// In de, this message translates to:
  /// **'Keine Änderungen'**
  String get peopleNoChanges;

  /// people.noEndDate
  ///
  /// In de, this message translates to:
  /// **'Kein Enddatum gewählt'**
  String get peopleNoEndDate;

  /// people.noGroupAssigned
  ///
  /// In de, this message translates to:
  /// **'Ohne Gruppe'**
  String get peopleNoGroupAssigned;

  /// people.noMembersFound
  ///
  /// In de, this message translates to:
  /// **'Keine Mitglieder gefunden.'**
  String get peopleNoMembersFound;

  /// people.noPeopleFound
  ///
  /// In de, this message translates to:
  /// **'Keine Personen gefunden'**
  String get peopleNoPeopleFound;

  /// people.noPeopleYet
  ///
  /// In de, this message translates to:
  /// **'Bisher wurden noch keine Personen angelegt'**
  String get peopleNoPeopleYet;

  /// people.noResult
  ///
  /// In de, this message translates to:
  /// **'Kein Ergebnis'**
  String get peopleNoResult;

  /// people.noTeacher
  ///
  /// In de, this message translates to:
  /// **'Kein Lehrer'**
  String get peopleNoTeacher;

  /// people.notImported
  ///
  /// In de, this message translates to:
  /// **'Nicht importierte Personen'**
  String get peopleNotImported;

  /// people.note
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get peopleNote;

  /// people.notePlaceholder
  ///
  /// In de, this message translates to:
  /// **'Notiz...'**
  String get peopleNotePlaceholder;

  /// people.notes
  ///
  /// In de, this message translates to:
  /// **'Notizen'**
  String get peopleNotes;

  /// people.nothingToImport
  ///
  /// In de, this message translates to:
  /// **'Keine importierbaren Personen.'**
  String get peopleNothingToImport;

  /// people.orderSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern der Reihenfolge'**
  String get peopleOrderSaveFailed;

  /// people.orderSaved
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge gespeichert'**
  String get peopleOrderSaved;

  /// people.otherDuties
  ///
  /// In de, this message translates to:
  /// **'Sonstige Dienste'**
  String get peopleOtherDuties;

  /// people.otherInstanceMember
  ///
  /// In de, this message translates to:
  /// **'Mitglied anderer Instanz'**
  String get peopleOtherInstanceMember;

  /// people.passportPhoto
  ///
  /// In de, this message translates to:
  /// **'Passbild'**
  String get peoplePassportPhoto;

  /// people.pause
  ///
  /// In de, this message translates to:
  /// **'Pausieren'**
  String get peoplePause;

  /// people.pauseHint
  ///
  /// In de, this message translates to:
  /// **'Mit einem Startdatum in der Vergangenheit wird die Person auch aus zurückliegenden Anwesenheiten ab diesem Datum entfernt. Wenn ein Enddatum angegeben wird, wird die Person automatisch reaktiviert.'**
  String get peoplePauseHint;

  /// people.pauseOthers
  ///
  /// In de, this message translates to:
  /// **'Auch in anderen Instanzen pausieren?'**
  String get peoplePauseOthers;

  /// people.pauseOthersMessage
  ///
  /// In de, this message translates to:
  /// **'{name} ist auch in anderen Instanzen aktiv. In welchen soll die Person ebenfalls pausiert werden?'**
  String peoplePauseOthersMessage(Object name);

  /// people.pauseTitle
  ///
  /// In de, this message translates to:
  /// **'{name} Pausieren'**
  String peoplePauseTitle(Object name);

  /// people.paused
  ///
  /// In de, this message translates to:
  /// **'Pausiert'**
  String get peoplePaused;

  /// people.pausedFrom
  ///
  /// In de, this message translates to:
  /// **'Pausiert ab (optional)'**
  String get peoplePausedFrom;

  /// people.pausing
  ///
  /// In de, this message translates to:
  /// **'Wird pausiert...'**
  String get peoplePausing;

  /// people.peopleCount
  ///
  /// In de, this message translates to:
  /// **'Personen ({count})'**
  String peoplePeopleCount(Object count);

  /// people.phone
  ///
  /// In de, this message translates to:
  /// **'Telefon'**
  String get peoplePhone;

  /// people.phonePlaceholder
  ///
  /// In de, this message translates to:
  /// **'Telefon...'**
  String get peoplePhonePlaceholder;

  /// people.previewFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler bei der Vorschau.'**
  String get peoplePreviewFailed;

  /// people.problemCase
  ///
  /// In de, this message translates to:
  /// **'Problemfall'**
  String get peopleProblemCase;

  /// people.problemCases
  ///
  /// In de, this message translates to:
  /// **'Problemfälle'**
  String get peopleProblemCases;

  /// people.reactivateConfirm
  ///
  /// In de, this message translates to:
  /// **'Person wieder aktivieren?'**
  String get peopleReactivateConfirm;

  /// people.readingFile
  ///
  /// In de, this message translates to:
  /// **'Datei wird gelesen...'**
  String get peopleReadingFile;

  /// people.ready
  ///
  /// In de, this message translates to:
  /// **'{count} bereit'**
  String peopleReady(Object count);

  /// people.reasonPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen Grund an...'**
  String get peopleReasonPlaceholder;

  /// people.reasonRequired
  ///
  /// In de, this message translates to:
  /// **'Grund *'**
  String get peopleReasonRequired;

  /// people.removeConfirm
  ///
  /// In de, this message translates to:
  /// **'Person wirklich entfernen?'**
  String get peopleRemoveConfirm;

  /// people.removed
  ///
  /// In de, this message translates to:
  /// **'Person wurde entfernt.'**
  String get peopleRemoved;

  /// people.removing
  ///
  /// In de, this message translates to:
  /// **'Person wird entfernt...'**
  String get peopleRemoving;

  /// people.reorder
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge anpassen'**
  String get peopleReorder;

  /// people.resetFilter
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get peopleResetFilter;

  /// people.saveChanges
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Änderung speichern} other {{count} Änderungen speichern}}'**
  String peopleSaveChanges(num count);

  /// people.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern'**
  String get peopleSaveFailed;

  /// people.saving
  ///
  /// In de, this message translates to:
  /// **'Speichern...'**
  String get peopleSaving;

  /// people.savingOrder
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge wird gespeichert...'**
  String get peopleSavingOrder;

  /// people.searchPerson
  ///
  /// In de, this message translates to:
  /// **'Person suchen...'**
  String get peopleSearchPerson;

  /// people.setForAll
  ///
  /// In de, this message translates to:
  /// **'Für alle setzen'**
  String get peopleSetForAll;

  /// people.showAll
  ///
  /// In de, this message translates to:
  /// **'Alle Anzeigen'**
  String get peopleShowAll;

  /// people.skip
  ///
  /// In de, this message translates to:
  /// **'Überspringen'**
  String get peopleSkip;

  /// people.standardFields
  ///
  /// In de, this message translates to:
  /// **'Standard-Felder'**
  String get peopleStandardFields;

  /// people.teacher
  ///
  /// In de, this message translates to:
  /// **'Lehrer'**
  String get peopleTeacher;

  /// people.teacherName
  ///
  /// In de, this message translates to:
  /// **'Lehrer: {name}'**
  String peopleTeacherName(Object name);

  /// people.testResult
  ///
  /// In de, this message translates to:
  /// **'Testergebnis'**
  String get peopleTestResult;

  /// people.testResultMissing
  ///
  /// In de, this message translates to:
  /// **'Testergebnis fehlt'**
  String get peopleTestResultMissing;

  /// people.unresolvedGroups
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Person konnte keiner Gruppe zugeordnet werden.} other {{count} Personen konnten keiner Gruppe zugeordnet werden.}} Bitte prüfe und passe die Gruppe unten an – vorerst ist die Hauptgruppe hinterlegt.'**
  String peopleUnresolvedGroups(num count);

  /// people.voiceLeader
  ///
  /// In de, this message translates to:
  /// **'Stimmführer'**
  String get peopleVoiceLeader;

  /// people.withHint
  ///
  /// In de, this message translates to:
  /// **'{count} mit Hinweis'**
  String peopleWithHint(Object count);

  /// people.withoutAccount
  ///
  /// In de, this message translates to:
  /// **'Ohne Account'**
  String get peopleWithoutAccount;

  /// people.withoutTeacher
  ///
  /// In de, this message translates to:
  /// **'Ohne Lehrer'**
  String get peopleWithoutTeacher;

  /// person.absences
  ///
  /// In de, this message translates to:
  /// **'Abwesenheiten'**
  String get personAbsences;

  /// person.absencesCount
  ///
  /// In de, this message translates to:
  /// **'Abwesenheiten ({count})'**
  String personAbsencesCount(Object count);

  /// person.account
  ///
  /// In de, this message translates to:
  /// **'Account'**
  String get personAccount;

  /// person.accountBadge
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get personAccountBadge;

  /// person.accountCreated
  ///
  /// In de, this message translates to:
  /// **'Account wurde erfolgreich angelegt'**
  String get personAccountCreated;

  /// person.accountHelp
  ///
  /// In de, this message translates to:
  /// **'Sobald die E-Mail Adresse eingeben wurde, kann ein Account erstellt werden. Der Benutzer wird per E-Mail über die Erstellung benachrichtigt. Das Passwort wird automatisch generiert und an die E-Mail Adresse gesendet.'**
  String get personAccountHelp;

  /// person.actions
  ///
  /// In de, this message translates to:
  /// **'Aktionen'**
  String get personActions;

  /// person.activeSince
  ///
  /// In de, this message translates to:
  /// **'Wieder aktiv seid {date}'**
  String personActiveSince(Object date);

  /// person.addAbsence
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit hinzufügen'**
  String get personAddAbsence;

  /// person.addFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim hinzufügen der Person: {error}'**
  String personAddFailed(Object error);

  /// person.added
  ///
  /// In de, this message translates to:
  /// **'Die Person wurde erfolgreich hinzugefügt'**
  String get personAdded;

  /// person.approvePerson
  ///
  /// In de, this message translates to:
  /// **'Person genehmigen'**
  String get personApprovePerson;

  /// person.approving
  ///
  /// In de, this message translates to:
  /// **'Die Person wird genehmigt...'**
  String get personApproving;

  /// person.archived
  ///
  /// In de, this message translates to:
  /// **'Die Person wurde erfolgreich archiviert'**
  String get personArchived;

  /// person.archivedAt
  ///
  /// In de, this message translates to:
  /// **'Archiviert am {date}'**
  String personArchivedAt(Object date);

  /// person.assignMyUser
  ///
  /// In de, this message translates to:
  /// **'Meinen Benutzer zuweisen'**
  String get personAssignMyUser;

  /// person.average
  ///
  /// In de, this message translates to:
  /// **'Durchschnitt'**
  String get personAverage;

  /// person.averageLate
  ///
  /// In de, this message translates to:
  /// **'Durchschnitt ({count}x zu spät)'**
  String personAverageLate(Object count);

  /// person.chooseEntry
  ///
  /// In de, this message translates to:
  /// **'Eintrag auswählen'**
  String get personChooseEntry;

  /// person.closeSuggestions
  ///
  /// In de, this message translates to:
  /// **'Vorschläge schließen'**
  String get personCloseSuggestions;

  /// person.copied
  ///
  /// In de, this message translates to:
  /// **'Die Person wurde erfolgreich kopiert'**
  String get personCopied;

  /// person.copiedAt
  ///
  /// In de, this message translates to:
  /// **'Kopiert am {date}'**
  String personCopiedAt(Object date);

  /// person.copyConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die Person wirklich in die andere Instanz kopieren?'**
  String get personCopyConfirm;

  /// person.copyFrom
  ///
  /// In de, this message translates to:
  /// **'Kopieren von {name}'**
  String personCopyFrom(Object name);

  /// person.copyNotPossible
  ///
  /// In de, this message translates to:
  /// **'Kopieren nicht möglich'**
  String get personCopyNotPossible;

  /// person.copyOther
  ///
  /// In de, this message translates to:
  /// **'In andere Instanz kopieren'**
  String get personCopyOther;

  /// person.copyPerson
  ///
  /// In de, this message translates to:
  /// **'Person kopieren'**
  String get personCopyPerson;

  /// person.createAccountNow
  ///
  /// In de, this message translates to:
  /// **'Möchtest du gleich ein Konto für die Person anlegen?'**
  String get personCreateAccountNow;

  /// person.dataTaken
  ///
  /// In de, this message translates to:
  /// **'Die Daten wurden erfolgreich übernommen'**
  String get personDataTaken;

  /// person.datePlaceholder
  ///
  /// In de, this message translates to:
  /// **'TT.MM.JJJJ'**
  String get personDatePlaceholder;

  /// person.decline
  ///
  /// In de, this message translates to:
  /// **'Ablehnen'**
  String get personDecline;

  /// person.declinePerson
  ///
  /// In de, this message translates to:
  /// **'Person ablehnen'**
  String get personDeclinePerson;

  /// person.declining
  ///
  /// In de, this message translates to:
  /// **'Die Person wird abgelehnt...'**
  String get personDeclining;

  /// person.deleteAbsenceMessage
  ///
  /// In de, this message translates to:
  /// **'Soll die Abwesenheit gelöscht werden? Bereits entschuldigte Termine in diesem Zeitraum werden auf \"Neutral\" zurückgesetzt.'**
  String get personDeleteAbsenceMessage;

  /// person.discardChanges
  ///
  /// In de, this message translates to:
  /// **'Änderungen verwerfen?'**
  String get personDiscardChanges;

  /// person.discardChangesMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die ungespeicherten Änderungen wirklich verwerfen?'**
  String get personDiscardChangesMessage;

  /// person.done
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get personDone;

  /// person.editName
  ///
  /// In de, this message translates to:
  /// **'Namen bearbeiten'**
  String get personEditName;

  /// person.editPerson
  ///
  /// In de, this message translates to:
  /// **'Person bearbeiten'**
  String get personEditPerson;

  /// person.emailAdded
  ///
  /// In de, this message translates to:
  /// **'E-Mail Adresse hinzugefügt'**
  String get personEmailAdded;

  /// person.emailTaken
  ///
  /// In de, this message translates to:
  /// **'E-Mail bereits vergeben'**
  String get personEmailTaken;

  /// person.emailUpdated
  ///
  /// In de, this message translates to:
  /// **'Die E-Mail Adresse wurde erfolgreich aktualisiert'**
  String get personEmailUpdated;

  /// person.emailUsedBy
  ///
  /// In de, this message translates to:
  /// **'Diese E-Mail wird in einer anderen Instanz von {name} verwendet. Daten übernehmen?'**
  String personEmailUsedBy(Object name);

  /// person.emailUsedMany
  ///
  /// In de, this message translates to:
  /// **'Diese E-Mail wird bereits in anderen Instanzen verwendet. Daten welcher Person übernehmen?'**
  String get personEmailUsedMany;

  /// person.enableVoiceLeader
  ///
  /// In de, this message translates to:
  /// **'Stimmführer aktivieren'**
  String get personEnableVoiceLeader;

  /// person.enterAbsence
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit eintragen'**
  String get personEnterAbsence;

  /// person.enterNames
  ///
  /// In de, this message translates to:
  /// **'Bitte gib den Vornamen und Nachnamen an.'**
  String get personEnterNames;

  /// person.entryRemoveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Eintrags.'**
  String get personEntryRemoveFailed;

  /// person.entryRemoved
  ///
  /// In de, this message translates to:
  /// **'Eintrag wurde erfolgreich entfernt.'**
  String get personEntryRemoved;

  /// person.existingUserHint
  ///
  /// In de, this message translates to:
  /// **'Falls schon ein Benutzer für die E-Mail Adresse existiert, wird dieser automatisch der Instanz zugewiesen.'**
  String get personExistingUserHint;

  /// person.existsWithEmail
  ///
  /// In de, this message translates to:
  /// **'In der Instanz \"{tenant}\" existiert bereits eine Person mit der E-Mail-Adresse \"{email}\".'**
  String personExistsWithEmail(Object tenant, Object email);

  /// person.existsWithName
  ///
  /// In de, this message translates to:
  /// **'In der Instanz \"{tenant}\" existiert bereits eine Person mit dem Namen \"{name}\".'**
  String personExistsWithName(Object tenant, Object name);

  /// person.flutter.absenceDeleteFailed
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit konnte nicht gelöscht werden'**
  String get personFlutterAbsenceDeleteFailed;

  /// person.flutter.absenceSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit konnte nicht gespeichert werden'**
  String get personFlutterAbsenceSaveFailed;

  /// person.flutter.accountCreatedMail
  ///
  /// In de, this message translates to:
  /// **'Account erstellt. Passwort-E-Mail wurde gesendet.'**
  String get personFlutterAccountCreatedMail;

  /// person.flutter.allEntries
  ///
  /// In de, this message translates to:
  /// **'Alle Einträge'**
  String get personFlutterAllEntries;

  /// person.flutter.approve
  ///
  /// In de, this message translates to:
  /// **'Genehmigen'**
  String get personFlutterApprove;

  /// person.flutter.approveMessage
  ///
  /// In de, this message translates to:
  /// **'{name} als Mitglied freischalten?'**
  String personFlutterApproveMessage(Object name);

  /// person.flutter.approveQuestion
  ///
  /// In de, this message translates to:
  /// **'Person genehmigen?'**
  String get personFlutterApproveQuestion;

  /// person.flutter.approved
  ///
  /// In de, this message translates to:
  /// **'Person wurde genehmigt'**
  String get personFlutterApproved;

  /// person.flutter.archiveReasonHint
  ///
  /// In de, this message translates to:
  /// **'Warum verlässt die Person?'**
  String get personFlutterArchiveReasonHint;

  /// person.flutter.attendanceLate
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit ({count}x zu spät)'**
  String personFlutterAttendanceLate(Object count);

  /// person.flutter.chooseLabel
  ///
  /// In de, this message translates to:
  /// **'{label} auswählen'**
  String personFlutterChooseLabel(Object label);

  /// person.flutter.chooseRange
  ///
  /// In de, this message translates to:
  /// **'Zeitraum wählen'**
  String get personFlutterChooseRange;

  /// person.flutter.createAccount
  ///
  /// In de, this message translates to:
  /// **'Account erstellen'**
  String get personFlutterCreateAccount;

  /// person.flutter.createAccountFailed
  ///
  /// In de, this message translates to:
  /// **'{name} - Fehler beim Erstellen des Accounts: {error}'**
  String personFlutterCreateAccountFailed(Object name, Object error);

  /// person.flutter.createAccountMessage
  ///
  /// In de, this message translates to:
  /// **'Für {name} wird ein Account mit der E-Mail {email} erstellt. Die Person erhält eine E-Mail zum Setzen des Passworts.'**
  String personFlutterCreateAccountMessage(Object name, Object email);

  /// person.flutter.createAccountQuestion
  ///
  /// In de, this message translates to:
  /// **'Account erstellen?'**
  String get personFlutterCreateAccountQuestion;

  /// person.flutter.critical
  ///
  /// In de, this message translates to:
  /// **'Kritisch'**
  String get personFlutterCritical;

  /// person.flutter.declineMessage
  ///
  /// In de, this message translates to:
  /// **'{name} wird abgelehnt und archiviert.'**
  String personFlutterDeclineMessage(Object name);

  /// person.flutter.declineReasonHint
  ///
  /// In de, this message translates to:
  /// **'Warum wird die Person abgelehnt?'**
  String get personFlutterDeclineReasonHint;

  /// person.flutter.declined
  ///
  /// In de, this message translates to:
  /// **'Person wurde abgelehnt'**
  String get personFlutterDeclined;

  /// person.flutter.emailRequiredForAccount
  ///
  /// In de, this message translates to:
  /// **'Um einen Account zu erstellen, muss eine E-Mail-Adresse hinterlegt werden.'**
  String get personFlutterEmailRequiredForAccount;

  /// person.flutter.frequentLate
  ///
  /// In de, this message translates to:
  /// **'Häufige Verspätungen'**
  String get personFlutterFrequentLate;

  /// person.flutter.fromSeasonStart
  ///
  /// In de, this message translates to:
  /// **'Ab Saisonstart ({date})'**
  String personFlutterFromSeasonStart(Object date);

  /// person.flutter.instrumentsHint
  ///
  /// In de, this message translates to:
  /// **'z.B. Klavier, Gitarre'**
  String get personFlutterInstrumentsHint;

  /// person.flutter.lateCount
  ///
  /// In de, this message translates to:
  /// **'{count}× zu spät (Schwelle: {threshold})'**
  String personFlutterLateCount(Object count, Object threshold);

  /// person.flutter.lateUnexcusedCount
  ///
  /// In de, this message translates to:
  /// **'{count}× unentschuldigt zu spät (Schwelle: {threshold})'**
  String personFlutterLateUnexcusedCount(Object count, Object threshold);

  /// person.flutter.linked
  ///
  /// In de, this message translates to:
  /// **'Verknüpft'**
  String get personFlutterLinked;

  /// person.flutter.matchFound
  ///
  /// In de, this message translates to:
  /// **'Person in anderer Instanz gefunden?'**
  String get personFlutterMatchFound;

  /// person.flutter.more
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get personFlutterMore;

  /// person.flutter.noAccountLinked
  ///
  /// In de, this message translates to:
  /// **'Kein Account verknüpft. Ein Dirigent kann einen Account erstellen.'**
  String get personFlutterNoAccountLinked;

  /// person.flutter.noEmail
  ///
  /// In de, this message translates to:
  /// **'Keine E-Mail-Adresse vorhanden'**
  String get personFlutterNoEmail;

  /// person.flutter.noHistory
  ///
  /// In de, this message translates to:
  /// **'Keine Historie vorhanden'**
  String get personFlutterNoHistory;

  /// person.flutter.noNote
  ///
  /// In de, this message translates to:
  /// **'Keine Notiz'**
  String get personFlutterNoNote;

  /// person.flutter.noNotes
  ///
  /// In de, this message translates to:
  /// **'Keine Notizen'**
  String get personFlutterNoNotes;

  /// person.flutter.noPermissionArchive
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung zum Archivieren'**
  String get personFlutterNoPermissionArchive;

  /// person.flutter.noPermissionCreateAccount
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung zum Erstellen von Accounts'**
  String get personFlutterNoPermissionCreateAccount;

  /// person.flutter.noPermissionEdit
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung zum Bearbeiten'**
  String get personFlutterNoPermissionEdit;

  /// person.flutter.noPermissionPause
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung zum Pausieren'**
  String get personFlutterNoPermissionPause;

  /// person.flutter.noPermissionReactivate
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung zum Reaktivieren'**
  String get personFlutterNoPermissionReactivate;

  /// person.flutter.noPermissionRoles
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung zum Ändern von Rollen'**
  String get personFlutterNoPermissionRoles;

  /// person.flutter.noPermissionUnlink
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung zum Aufheben von Account-Verknüpfungen'**
  String get personFlutterNoPermissionUnlink;

  /// person.flutter.noShiftPlan
  ///
  /// In de, this message translates to:
  /// **'Kein Schichtplan'**
  String get personFlutterNoShiftPlan;

  /// person.flutter.noneLabel
  ///
  /// In de, this message translates to:
  /// **'Keine {label}'**
  String personFlutterNoneLabel(Object label);

  /// person.flutter.noneLabelMasc
  ///
  /// In de, this message translates to:
  /// **'Kein {label}'**
  String personFlutterNoneLabelMasc(Object label);

  /// person.flutter.notAssigned
  ///
  /// In de, this message translates to:
  /// **'Nicht zugewiesen'**
  String get personFlutterNotAssigned;

  /// person.flutter.notFound
  ///
  /// In de, this message translates to:
  /// **'Person nicht gefunden'**
  String get personFlutterNotFound;

  /// person.flutter.notSelected
  ///
  /// In de, this message translates to:
  /// **'Nicht ausgewählt'**
  String get personFlutterNotSelected;

  /// person.flutter.notSpecified
  ///
  /// In de, this message translates to:
  /// **'Nicht angegeben'**
  String get personFlutterNotSpecified;

  /// person.flutter.notesHint
  ///
  /// In de, this message translates to:
  /// **'Notizen zur Person...'**
  String get personFlutterNotesHint;

  /// person.flutter.otherDutiesHint
  ///
  /// In de, this message translates to:
  /// **'Weitere Aufgaben...'**
  String get personFlutterOtherDutiesHint;

  /// person.flutter.otherInstancesCount
  ///
  /// In de, this message translates to:
  /// **'Andere Instanzen ({count})'**
  String personFlutterOtherInstancesCount(Object count);

  /// person.flutter.pausedUntil
  ///
  /// In de, this message translates to:
  /// **'Pausiert bis {date}'**
  String personFlutterPausedUntil(Object date);

  /// person.flutter.pending
  ///
  /// In de, this message translates to:
  /// **'Ausstehend'**
  String get personFlutterPending;

  /// person.flutter.problemSolved
  ///
  /// In de, this message translates to:
  /// **'Problemfall gelöst'**
  String get personFlutterProblemSolved;

  /// person.flutter.rangeHint
  ///
  /// In de, this message translates to:
  /// **'z.B. C3 - C5'**
  String get personFlutterRangeHint;

  /// person.flutter.remarksHint
  ///
  /// In de, this message translates to:
  /// **'Was wurde besprochen?'**
  String get personFlutterRemarksHint;

  /// person.flutter.required
  ///
  /// In de, this message translates to:
  /// **'Pflichtfeld'**
  String get personFlutterRequired;

  /// person.flutter.roleAdmin
  ///
  /// In de, this message translates to:
  /// **'Dirigent (Admin)'**
  String get personFlutterRoleAdmin;

  /// person.flutter.roleNone
  ///
  /// In de, this message translates to:
  /// **'Keine Rolle'**
  String get personFlutterRoleNone;

  /// person.flutter.roleUpdateFailed
  ///
  /// In de, this message translates to:
  /// **'Rolle konnte nicht angepasst werden: {error}'**
  String personFlutterRoleUpdateFailed(Object error);

  /// person.flutter.saveOnly
  ///
  /// In de, this message translates to:
  /// **'Nur speichern'**
  String get personFlutterSaveOnly;

  /// person.flutter.searchOtherInstance
  ///
  /// In de, this message translates to:
  /// **'In anderer Instanz suchen'**
  String get personFlutterSearchOtherInstance;

  /// person.flutter.seasonOnly
  ///
  /// In de, this message translates to:
  /// **'Nur Saison'**
  String get personFlutterSeasonOnly;

  /// person.flutter.showAll
  ///
  /// In de, this message translates to:
  /// **'Alle anzeigen'**
  String get personFlutterShowAll;

  /// person.flutter.talkedToHint
  ///
  /// In de, this message translates to:
  /// **'Bestätigen, dass das Problem besprochen wurde'**
  String get personFlutterTalkedToHint;

  /// person.flutter.testResultHint
  ///
  /// In de, this message translates to:
  /// **'Ergebnis eingeben...'**
  String get personFlutterTestResultHint;

  /// person.flutter.unlink
  ///
  /// In de, this message translates to:
  /// **'Verknüpfung aufheben'**
  String get personFlutterUnlink;

  /// person.flutter.unlinkAccount
  ///
  /// In de, this message translates to:
  /// **'Account-Verknüpfung aufheben'**
  String get personFlutterUnlinkAccount;

  /// person.flutter.unlinkMessage
  ///
  /// In de, this message translates to:
  /// **'Die Account-Verknüpfung für {name} wird aufgehoben. Die Person kann sich dann nicht mehr in der App anmelden.'**
  String personFlutterUnlinkMessage(Object name);

  /// person.flutter.unlinkQuestion
  ///
  /// In de, this message translates to:
  /// **'Account-Verknüpfung aufheben?'**
  String get personFlutterUnlinkQuestion;

  /// person.flutter.unlinked
  ///
  /// In de, this message translates to:
  /// **'Account-Verknüpfung aufgehoben'**
  String get personFlutterUnlinked;

  /// person.flutter.uploadFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hochladen: {error}'**
  String personFlutterUploadFailedWith(Object error);

  /// person.flutter.uploadingPhoto
  ///
  /// In de, this message translates to:
  /// **'Lade Passbild hoch...'**
  String get personFlutterUploadingPhoto;

  /// person.fromRequired
  ///
  /// In de, this message translates to:
  /// **'Von *'**
  String get personFromRequired;

  /// person.giveReasonShort
  ///
  /// In de, this message translates to:
  /// **'Gib einen Grund an.'**
  String get personGiveReasonShort;

  /// person.help
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get personHelp;

  /// person.history
  ///
  /// In de, this message translates to:
  /// **'Historie'**
  String get personHistory;

  /// person.invalidEmail
  ///
  /// In de, this message translates to:
  /// **'Bitte gib eine valide E-Mail Adresse ein...'**
  String get personInvalidEmail;

  /// person.joinedOn
  ///
  /// In de, this message translates to:
  /// **'Beigetreten am'**
  String get personJoinedOn;

  /// person.lateCounterReset
  ///
  /// In de, this message translates to:
  /// **'Verspätungszähler zurückgesetzt'**
  String get personLateCounterReset;

  /// person.lateExcusedExtra
  ///
  /// In de, this message translates to:
  /// **'Zusätzlich {count}x entschuldigt zu spät.'**
  String personLateExcusedExtra(Object count);

  /// person.lateWarning
  ///
  /// In de, this message translates to:
  /// **'Diese Person ist <strong>{count}x</strong> unentschuldigt zu spät gekommen.'**
  String personLateWarning(Object count);

  /// person.lateWarningTitle
  ///
  /// In de, this message translates to:
  /// **'🕐 Häufige Verspätungen'**
  String get personLateWarningTitle;

  /// person.longAbsenceHint
  ///
  /// In de, this message translates to:
  /// **'Für längere Abwesenheiten empfiehlt sich die Pausieren-Funktion, damit die Person nicht in neuen Terminen erscheint.'**
  String get personLongAbsenceHint;

  /// person.merge
  ///
  /// In de, this message translates to:
  /// **'Zusammenführen'**
  String get personMerge;

  /// person.mergeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Zusammenführen der Personen'**
  String get personMergeFailed;

  /// person.mergeMessage
  ///
  /// In de, this message translates to:
  /// **'{name} wird mit der bestehenden Person {candidate} zusammengeführt. Deren Anwesenheitsdaten bleiben erhalten, der neu registrierte Account wird {candidate} zugeordnet. Dies kann nicht rückgängig gemacht werden.'**
  String personMergeMessage(Object name, Object candidate);

  /// person.mergePeople
  ///
  /// In de, this message translates to:
  /// **'Personen zusammenführen'**
  String get personMergePeople;

  /// person.merged
  ///
  /// In de, this message translates to:
  /// **'Die Personen wurden erfolgreich zusammengeführt'**
  String get personMerged;

  /// person.merging
  ///
  /// In de, this message translates to:
  /// **'Die Personen werden zusammengeführt...'**
  String get personMerging;

  /// person.noAbsences
  ///
  /// In de, this message translates to:
  /// **'Keine Abwesenheiten eingetragen'**
  String get personNoAbsences;

  /// person.noChurchFound
  ///
  /// In de, this message translates to:
  /// **'Keine Gemeinde gefunden.'**
  String get personNoChurchFound;

  /// person.noComment
  ///
  /// In de, this message translates to:
  /// **'Keine Anmerkung'**
  String get personNoComment;

  /// person.noDateChosen
  ///
  /// In de, this message translates to:
  /// **'Kein Datum gewählt'**
  String get personNoDateChosen;

  /// person.noMatchOther
  ///
  /// In de, this message translates to:
  /// **'Es wurde keine passende Person in einer anderen Instanz gefunden'**
  String get personNoMatchOther;

  /// person.noShift
  ///
  /// In de, this message translates to:
  /// **'Keine Schicht zugewiesen'**
  String get personNoShift;

  /// person.notAvailable
  ///
  /// In de, this message translates to:
  /// **'Nicht verfügbar'**
  String get personNotAvailable;

  /// person.notListed
  ///
  /// In de, this message translates to:
  /// **'Nicht gelistet'**
  String get personNotListed;

  /// person.notSet
  ///
  /// In de, this message translates to:
  /// **'Nicht festgelegt'**
  String get personNotSet;

  /// person.noteChanged
  ///
  /// In de, this message translates to:
  /// **'Notiz geändert'**
  String get personNoteChanged;

  /// person.noteChangedAt
  ///
  /// In de, this message translates to:
  /// **'Notiz geändert am {date}'**
  String personNoteChangedAt(Object date);

  /// person.oldNote
  ///
  /// In de, this message translates to:
  /// **'Alte Notiz: {note}'**
  String personOldNote(Object note);

  /// person.otherInstances
  ///
  /// In de, this message translates to:
  /// **'Andere Instanzen'**
  String get personOtherInstances;

  /// person.otherOrchestras
  ///
  /// In de, this message translates to:
  /// **'Andere Orchester'**
  String get personOtherOrchestras;

  /// person.parents
  ///
  /// In de, this message translates to:
  /// **'Eltern'**
  String get personParents;

  /// person.pauseHintAuto
  ///
  /// In de, this message translates to:
  /// **'Mit einem Startdatum in der Vergangenheit wird die Person auch aus zurückliegenden Anwesenheiten ab diesem Datum entfernt. Wenn ein Enddatum angegeben ist, wird die Person danach automatisch wieder aktiviert.'**
  String get personPauseHintAuto;

  /// person.pauseReasonPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Gib einen Grund für die Pause an...'**
  String get personPauseReasonPlaceholder;

  /// person.pauseTitle
  ///
  /// In de, this message translates to:
  /// **'{name} pausieren'**
  String personPauseTitle(Object name);

  /// person.pausedAt
  ///
  /// In de, this message translates to:
  /// **'Pausiert am {date}'**
  String personPausedAt(Object date);

  /// person.phoneNumber
  ///
  /// In de, this message translates to:
  /// **'Telefon-/Handynummer'**
  String get personPhoneNumber;

  /// person.photoChangeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim ändern des Passbildes, versuche es später erneut'**
  String get personPhotoChangeFailed;

  /// person.photoLoadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden des Passbildes'**
  String get personPhotoLoadFailed;

  /// person.photoRemoved
  ///
  /// In de, this message translates to:
  /// **'Das Passbild wurde erfolgreich entfernt'**
  String get personPhotoRemoved;

  /// person.photoTooLarge
  ///
  /// In de, this message translates to:
  /// **'Das Bild darf maximal 2MB groß sein.'**
  String get personPhotoTooLarge;

  /// person.playsSince
  ///
  /// In de, this message translates to:
  /// **'Spielt auf dem Instrument seit'**
  String get personPlaysSince;

  /// person.playsWithTeacher
  ///
  /// In de, this message translates to:
  /// **'Spielt beim Lehrer'**
  String get personPlaysWithTeacher;

  /// person.pleaseChoose
  ///
  /// In de, this message translates to:
  /// **'Bitte auswählen'**
  String get personPleaseChoose;

  /// person.reactivate
  ///
  /// In de, this message translates to:
  /// **'Wieder aktivieren'**
  String get personReactivate;

  /// person.reactivateConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die Person wirklich reaktivieren?'**
  String get personReactivateConfirm;

  /// person.reactivatePerson
  ///
  /// In de, this message translates to:
  /// **'Person reaktivieren'**
  String get personReactivatePerson;

  /// person.reactivated
  ///
  /// In de, this message translates to:
  /// **'Die Person wurde erfolgreich wieder aktiviert'**
  String get personReactivated;

  /// person.reactivatedAt
  ///
  /// In de, this message translates to:
  /// **'Reaktiviert am {date}'**
  String personReactivatedAt(Object date);

  /// person.remarks
  ///
  /// In de, this message translates to:
  /// **'Anmerkungen'**
  String get personRemarks;

  /// person.removeAccount
  ///
  /// In de, this message translates to:
  /// **'Account entfernen'**
  String get personRemoveAccount;

  /// person.removeAccountMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du den Account wirklich aus der Instanz entfernen? Die Personendaten bleiben erhalten.'**
  String get personRemoveAccountMessage;

  /// person.removeEntry
  ///
  /// In de, this message translates to:
  /// **'Eintrag unwiderruflich entfernen?'**
  String get personRemoveEntry;

  /// person.removePersonMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die Person wirklich entfernen? Alle zugehörigen Daten (Abwesenheiten, Notizen, etc.) gehen dabei verloren!'**
  String get personRemovePersonMessage;

  /// person.removePhoto
  ///
  /// In de, this message translates to:
  /// **'Passbild entfernen'**
  String get personRemovePhoto;

  /// person.removePhotoMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du das Passbild wirklich entfernen?'**
  String get personRemovePhotoMessage;

  /// person.removed
  ///
  /// In de, this message translates to:
  /// **'Die Person wurde erfolgreich entfernt'**
  String get personRemoved;

  /// person.replace
  ///
  /// In de, this message translates to:
  /// **'Ersetzen'**
  String get personReplace;

  /// person.resetFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Zurücksetzen'**
  String get personResetFailed;

  /// person.resetTalked
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen (Gespräch geführt)'**
  String get personResetTalked;

  /// person.resetting
  ///
  /// In de, this message translates to:
  /// **'Wird zurückgesetzt...'**
  String get personResetting;

  /// person.role
  ///
  /// In de, this message translates to:
  /// **'Rolle'**
  String get personRole;

  /// person.roleUpdated
  ///
  /// In de, this message translates to:
  /// **'Die Rolle wurde erfolgreich aktualisiert.'**
  String get personRoleUpdated;

  /// person.saveWithRole
  ///
  /// In de, this message translates to:
  /// **'Mit Rolle speichern'**
  String get personSaveWithRole;

  /// person.searchChurch
  ///
  /// In de, this message translates to:
  /// **'Gemeinde suchen'**
  String get personSearchChurch;

  /// person.shift
  ///
  /// In de, this message translates to:
  /// **'Schicht'**
  String get personShift;

  /// person.shiftPlan
  ///
  /// In de, this message translates to:
  /// **'Schichtplan'**
  String get personShiftPlan;

  /// person.similarExists
  ///
  /// In de, this message translates to:
  /// **'Ähnliche Person bereits vorhanden'**
  String get personSimilarExists;

  /// person.startDate
  ///
  /// In de, this message translates to:
  /// **'Anfangsdatum'**
  String get personStartDate;

  /// person.talkedTo
  ///
  /// In de, this message translates to:
  /// **'Mit Person gesprochen'**
  String get personTalkedTo;

  /// person.talkedToAt
  ///
  /// In de, this message translates to:
  /// **'Mit Person gesprochen ({date})'**
  String personTalkedToAt(Object date);

  /// person.targetGroup
  ///
  /// In de, this message translates to:
  /// **'Ziel-Gruppe'**
  String get personTargetGroup;

  /// person.targetInstance
  ///
  /// In de, this message translates to:
  /// **'Ziel-Instanz'**
  String get personTargetInstance;

  /// person.transferConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die Person wirklich in die andere Instanz übertragen? Alle zugehörigen Daten (Abwesenheiten, Notizen, etc.) gehen dabei verloren!'**
  String get personTransferConfirm;

  /// person.transferFrom
  ///
  /// In de, this message translates to:
  /// **'Übertragen von {name}'**
  String personTransferFrom(Object name);

  /// person.transferNotPossible
  ///
  /// In de, this message translates to:
  /// **'Übertragen nicht möglich'**
  String get personTransferNotPossible;

  /// person.transferOther
  ///
  /// In de, this message translates to:
  /// **'In andere Instanz übertragen'**
  String get personTransferOther;

  /// person.transferPerson
  ///
  /// In de, this message translates to:
  /// **'Person übertragen'**
  String get personTransferPerson;

  /// person.transferred
  ///
  /// In de, this message translates to:
  /// **'Die Person wurde erfolgreich übertragen'**
  String get personTransferred;

  /// person.transferredAt
  ///
  /// In de, this message translates to:
  /// **'Übertragen am {date}'**
  String personTransferredAt(Object date);

  /// person.untilRequired
  ///
  /// In de, this message translates to:
  /// **'Bis *'**
  String get personUntilRequired;

  /// person.upcomingEvents
  ///
  /// In de, this message translates to:
  /// **'Anstehende Termine ({count})'**
  String personUpcomingEvents(Object count);

  /// person.updateFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim aktualisieren des Spielers'**
  String get personUpdateFailed;

  /// person.updateFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim aktualisieren des Spielers: {error}'**
  String personUpdateFailedWith(Object error);

  /// person.updated
  ///
  /// In de, this message translates to:
  /// **'Die Spielerdaten wurden erfolgreich aktualisiert.'**
  String get personUpdated;

  /// person.userAssigned
  ///
  /// In de, this message translates to:
  /// **'Benutzer wurde erfolgreich zugewiesen'**
  String get personUserAssigned;

  /// person.userRemoveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Entfernen des Benutzers'**
  String get personUserRemoveFailed;

  /// person.userRemoved
  ///
  /// In de, this message translates to:
  /// **'Der Benutzer wurde erfolgreich entfernt'**
  String get personUserRemoved;

  /// person.vocalRange
  ///
  /// In de, this message translates to:
  /// **'Stimmumfang'**
  String get personVocalRange;

  /// person.voiceLeaderMessage
  ///
  /// In de, this message translates to:
  /// **'Mit der Stimmführer-Rolle kann {name} die Kontaktdaten und anstehenden Termine aller Personen in der Stimme einsehen. Soll die Rolle vergeben werden?'**
  String personVoiceLeaderMessage(Object name);

  /// person.voiceLeaderStatusOnly
  ///
  /// In de, this message translates to:
  /// **'Nur Stimmführer-Status'**
  String get personVoiceLeaderStatusOnly;

  /// planning.addAnotherPlan
  ///
  /// In de, this message translates to:
  /// **'Weiteren Ablaufplan anlegen'**
  String get planningAddAnotherPlan;

  /// planning.addAnotherPlanMessage
  ///
  /// In de, this message translates to:
  /// **'Soll der neue Plan den aktuellen Ablauf übernehmen oder leer starten?'**
  String get planningAddAnotherPlanMessage;

  /// planning.addBlock
  ///
  /// In de, this message translates to:
  /// **'Programmblock hinzufügen'**
  String get planningAddBlock;

  /// planning.addCurrentSongs
  ///
  /// In de, this message translates to:
  /// **'Aktuelle Werke hinzufügen'**
  String get planningAddCurrentSongs;

  /// planning.addField
  ///
  /// In de, this message translates to:
  /// **'Feld hinzufügen'**
  String get planningAddField;

  /// planning.addNoteField
  ///
  /// In de, this message translates to:
  /// **'Notizfeld hinzufügen'**
  String get planningAddNoteField;

  /// planning.addSong
  ///
  /// In de, this message translates to:
  /// **'Werk hinzufügen'**
  String get planningAddSong;

  /// planning.addSubItem
  ///
  /// In de, this message translates to:
  /// **'Unterpunkt hinzufügen'**
  String get planningAddSubItem;

  /// planning.agenda
  ///
  /// In de, this message translates to:
  /// **'Tagesordnung'**
  String get planningAgenda;

  /// planning.agendaExists
  ///
  /// In de, this message translates to:
  /// **'Ein Tagesordnungs-Platzhalter ist bereits vorhanden'**
  String get planningAgendaExists;

  /// planning.agendaInsertPos
  ///
  /// In de, this message translates to:
  /// **'Einfügeposition Tagesordnung'**
  String get planningAgendaInsertPos;

  /// planning.allPlans
  ///
  /// In de, this message translates to:
  /// **'Alle {count} Pläne'**
  String planningAllPlans(Object count);

  /// planning.alto
  ///
  /// In de, this message translates to:
  /// **'Alt'**
  String get planningAlto;

  /// planning.asOf
  ///
  /// In de, this message translates to:
  /// **'Stand: {date}'**
  String planningAsOf(Object date);

  /// planning.assignDay
  ///
  /// In de, this message translates to:
  /// **'Tag zuordnen'**
  String get planningAssignDay;

  /// planning.assignOtherDay
  ///
  /// In de, this message translates to:
  /// **'Anderem Tag zuordnen'**
  String get planningAssignOtherDay;

  /// planning.attendanceNotes
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitsnotizen'**
  String get planningAttendanceNotes;

  /// planning.bass
  ///
  /// In de, this message translates to:
  /// **'Bass'**
  String get planningBass;

  /// planning.blockDurationHint
  ///
  /// In de, this message translates to:
  /// **'Die Dauer ergibt sich aus den Unterpunkten.'**
  String get planningBlockDurationHint;

  /// planning.blockHasItems
  ///
  /// In de, this message translates to:
  /// **'„{name}“ hat {count, plural, one {{count} Unterpunkt} other {{count} Unterpunkte}}.'**
  String planningBlockHasItems(Object name, num count);

  /// planning.blockNamePlaceholder
  ///
  /// In de, this message translates to:
  /// **'Name, z. B. Programm Jugendchor'**
  String get planningBlockNamePlaceholder;

  /// planning.blockSubHeader
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Unterpunkt} other {{count} Unterpunkte}} · {min} min'**
  String planningBlockSubHeader(num count, Object min);

  /// planning.blocks
  ///
  /// In de, this message translates to:
  /// **'Programmblöcke'**
  String get planningBlocks;

  /// planning.chooseEventFirst
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle zuerst einen Termin aus.'**
  String get planningChooseEventFirst;

  /// planning.chooseFieldMin
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle mindestens ein Feld aus.'**
  String get planningChooseFieldMin;

  /// planning.chooseSong
  ///
  /// In de, this message translates to:
  /// **'Werk auswählen'**
  String get planningChooseSong;

  /// planning.collapseBlock
  ///
  /// In de, this message translates to:
  /// **'Block einklappen'**
  String get planningCollapseBlock;

  /// planning.conductors
  ///
  /// In de, this message translates to:
  /// **'Dirigenten'**
  String get planningConductors;

  /// planning.copy
  ///
  /// In de, this message translates to:
  /// **'Kopie'**
  String get planningCopy;

  /// planning.createRunSheetFirst
  ///
  /// In de, this message translates to:
  /// **'Lege zuerst einen Ablauf für diesen Plan an.'**
  String get planningCreateRunSheetFirst;

  /// planning.createSectionalPlan
  ///
  /// In de, this message translates to:
  /// **'Registerprobenplan erstellen'**
  String get planningCreateSectionalPlan;

  /// planning.current
  ///
  /// In de, this message translates to:
  /// **'Aktuelle'**
  String get planningCurrent;

  /// planning.defaultTitle
  ///
  /// In de, this message translates to:
  /// **'Standardtitel verwenden'**
  String get planningDefaultTitle;

  /// planning.defaultWord
  ///
  /// In de, this message translates to:
  /// **'Wort '**
  String get planningDefaultWord;

  /// planning.deleteAll
  ///
  /// In de, this message translates to:
  /// **'Alles löschen'**
  String get planningDeleteAll;

  /// planning.deleteBlockConfirm
  ///
  /// In de, this message translates to:
  /// **'Block löschen?'**
  String get planningDeleteBlockConfirm;

  /// planning.deleteBlockWithItems
  ///
  /// In de, this message translates to:
  /// **'Block mit Unterpunkten löschen'**
  String get planningDeleteBlockWithItems;

  /// planning.deletePlan
  ///
  /// In de, this message translates to:
  /// **'Plan löschen'**
  String get planningDeletePlan;

  /// planning.deletePlanConfirm
  ///
  /// In de, this message translates to:
  /// **'Plan löschen?'**
  String get planningDeletePlanConfirm;

  /// planning.deletePlanMessage
  ///
  /// In de, this message translates to:
  /// **'Der Plan „{label}“ wird gelöscht.'**
  String planningDeletePlanMessage(Object label);

  /// planning.deleteTemplate
  ///
  /// In de, this message translates to:
  /// **'Vorlage löschen'**
  String get planningDeleteTemplate;

  /// planning.deleteTemplateConfirm
  ///
  /// In de, this message translates to:
  /// **'Vorlage löschen?'**
  String get planningDeleteTemplateConfirm;

  /// planning.deleteTemplateMessage
  ///
  /// In de, this message translates to:
  /// **'Die Vorlage „{name}“ wird gelöscht. Bestehende Pläne bleiben unverändert.'**
  String planningDeleteTemplateMessage(Object name);

  /// planning.dissolveBlock
  ///
  /// In de, this message translates to:
  /// **'Block auflösen'**
  String get planningDissolveBlock;

  /// planning.editBlock
  ///
  /// In de, this message translates to:
  /// **'Block bearbeiten'**
  String get planningEditBlock;

  /// planning.editField
  ///
  /// In de, this message translates to:
  /// **'Feld bearbeiten'**
  String get planningEditField;

  /// planning.editLink
  ///
  /// In de, this message translates to:
  /// **'Bearbeitungs-Link'**
  String get planningEditLink;

  /// planning.empty
  ///
  /// In de, this message translates to:
  /// **'Leer'**
  String get planningEmpty;

  /// planning.enterFreeText
  ///
  /// In de, this message translates to:
  /// **'Freitext eingeben...'**
  String get planningEnterFreeText;

  /// planning.enterItem
  ///
  /// In de, this message translates to:
  /// **'Programmpunkt eingeben...'**
  String get planningEnterItem;

  /// planning.enterItemPlease
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Programmpunkt eingeben.'**
  String get planningEnterItemPlease;

  /// planning.enterNamePlease
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Namen eingeben.'**
  String get planningEnterNamePlease;

  /// planning.enterNote
  ///
  /// In de, this message translates to:
  /// **'Notiz eingeben...'**
  String get planningEnterNote;

  /// planning.enterPerformer
  ///
  /// In de, this message translates to:
  /// **'Ausführenden eingeben...'**
  String get planningEnterPerformer;

  /// planning.expandBlock
  ///
  /// In de, this message translates to:
  /// **'Block aufklappen'**
  String get planningExpandBlock;

  /// planning.export
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get planningExport;

  /// planning.exportPdf
  ///
  /// In de, this message translates to:
  /// **'PDF exportieren'**
  String get planningExportPdf;

  /// planning.exportPdfA5
  ///
  /// In de, this message translates to:
  /// **'PDF exportieren (2x A5)'**
  String get planningExportPdfA5;

  /// planning.exportPdfAll
  ///
  /// In de, this message translates to:
  /// **'PDF exportieren (alle Pläne)'**
  String get planningExportPdfAll;

  /// planning.fields
  ///
  /// In de, this message translates to:
  /// **'Felder'**
  String get planningFields;

  /// planning.fillRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte fülle alle erforderlichen Felder aus.'**
  String get planningFillRequired;

  /// planning.firstEvent
  ///
  /// In de, this message translates to:
  /// **'Dies ist die aktuell erste Veranstaltung'**
  String get planningFirstEvent;

  /// planning.flutter.blockEntry
  ///
  /// In de, this message translates to:
  /// **'Programmblock: {name} ({min} min)'**
  String planningFlutterBlockEntry(Object name, Object min);

  /// planning.flutter.conflictDraftApply
  ///
  /// In de, this message translates to:
  /// **'Entwurf übernehmen'**
  String get planningFlutterConflictDraftApply;

  /// planning.flutter.conflictDraftDiscard
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get planningFlutterConflictDraftDiscard;

  /// planning.flutter.conflictDraftMessage
  ///
  /// In de, this message translates to:
  /// **'Ein älterer Entwurf wurde wegen eines Konflikts nicht übernommen.'**
  String get planningFlutterConflictDraftMessage;

  /// planning.flutter.conflictDraftTitle
  ///
  /// In de, this message translates to:
  /// **'Entwurf nicht übernommen'**
  String get planningFlutterConflictDraftTitle;

  /// planning.flutter.draftLost
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan konnte nicht gespeichert werden – Änderungen gehen verloren'**
  String get planningFlutterDraftLost;

  /// planning.flutter.draftRestored
  ///
  /// In de, this message translates to:
  /// **'Nicht gespeicherte Änderungen wiederhergestellt'**
  String get planningFlutterDraftRestored;

  /// planning.flutter.draftSavedLocally
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan konnte nicht gespeichert werden – Entwurf lokal gesichert'**
  String get planningFlutterDraftSavedLocally;

  /// planning.flutter.errorWith
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String planningFlutterErrorWith(Object error);

  /// planning.flutter.exportFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Export: {error}'**
  String planningFlutterExportFailed(Object error);

  /// planning.flutter.fieldEntry
  ///
  /// In de, this message translates to:
  /// **'Feld: {name} ({min} min)'**
  String planningFlutterFieldEntry(Object name, Object min);

  /// planning.flutter.live
  ///
  /// In de, this message translates to:
  /// **'Live'**
  String get planningFlutterLive;

  /// planning.flutter.liveMode
  ///
  /// In de, this message translates to:
  /// **'Live-Modus'**
  String get planningFlutterLiveMode;

  /// planning.flutter.liveModeEnd
  ///
  /// In de, this message translates to:
  /// **'Live-Modus beenden'**
  String get planningFlutterLiveModeEnd;

  /// planning.flutter.noEvents
  ///
  /// In de, this message translates to:
  /// **'Keine Termine vorhanden'**
  String get planningFlutterNoEvents;

  /// planning.flutter.noItems
  ///
  /// In de, this message translates to:
  /// **'Keine Programmpunkte'**
  String get planningFlutterNoItems;

  /// planning.flutter.pdf2xA5
  ///
  /// In de, this message translates to:
  /// **'PDF (2x A5)'**
  String get planningFlutterPdf2xA5;

  /// planning.flutter.pdfA4
  ///
  /// In de, this message translates to:
  /// **'PDF (A4)'**
  String get planningFlutterPdfA4;

  /// planning.flutter.planChanged
  ///
  /// In de, this message translates to:
  /// **'Plan wurde inzwischen geändert'**
  String get planningFlutterPlanChanged;

  /// planning.flutter.planChangedDraftLost
  ///
  /// In de, this message translates to:
  /// **'Plan wurde inzwischen geändert – Änderungen gehen verloren'**
  String get planningFlutterPlanChangedDraftLost;

  /// planning.flutter.planChangedDraftSaved
  ///
  /// In de, this message translates to:
  /// **'Plan wurde inzwischen geändert – Änderungen als Entwurf gesichert'**
  String get planningFlutterPlanChangedDraftSaved;

  /// planning.flutter.planDeleted
  ///
  /// In de, this message translates to:
  /// **'Plan wurde inzwischen gelöscht'**
  String get planningFlutterPlanDeleted;

  /// planning.flutter.planDeletedDraftLost
  ///
  /// In de, this message translates to:
  /// **'Plan wurde inzwischen gelöscht – Änderungen gehen verloren'**
  String get planningFlutterPlanDeletedDraftLost;

  /// planning.flutter.planDeletedDraftSaved
  ///
  /// In de, this message translates to:
  /// **'Plan wurde inzwischen gelöscht – Änderungen als Entwurf gesichert'**
  String get planningFlutterPlanDeletedDraftSaved;

  /// planning.flutter.planPosition
  ///
  /// In de, this message translates to:
  /// **'{index} von {total}'**
  String planningFlutterPlanPosition(Object index, Object total);

  /// planning.flutter.saveFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern: {error}'**
  String planningFlutterSaveFailedWith(Object error);

  /// planning.flutter.shareFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Teilen: {error}'**
  String planningFlutterShareFailedWith(Object error);

  /// planning.flutter.telegramNotConfigured
  ///
  /// In de, this message translates to:
  /// **'Telegram nicht konfiguriert'**
  String get planningFlutterTelegramNotConfigured;

  /// planning.flutter.telegramPdf2x
  ///
  /// In de, this message translates to:
  /// **'Per Telegram senden (PDF 2x A5)'**
  String get planningFlutterTelegramPdf2x;

  /// planning.flutter.unshareAction
  ///
  /// In de, this message translates to:
  /// **'Freigabe aufheben'**
  String get planningFlutterUnshareAction;

  /// planning.groupName
  ///
  /// In de, this message translates to:
  /// **'Gruppenname'**
  String get planningGroupName;

  /// planning.groups
  ///
  /// In de, this message translates to:
  /// **'Gruppen'**
  String get planningGroups;

  /// planning.headingLabel
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan Überschrift'**
  String get planningHeadingLabel;

  /// planning.includeBranding
  ///
  /// In de, this message translates to:
  /// **'Branding einbeziehen'**
  String get planningIncludeBranding;

  /// planning.indent
  ///
  /// In de, this message translates to:
  /// **'Einrücken'**
  String get planningIndent;

  /// planning.info
  ///
  /// In de, this message translates to:
  /// **'Info'**
  String get planningInfo;

  /// planning.infoOptional
  ///
  /// In de, this message translates to:
  /// **'Info-Text (optional)'**
  String get planningInfoOptional;

  /// planning.infoOptionalEllipsis
  ///
  /// In de, this message translates to:
  /// **'Info-Text (optional)...'**
  String get planningInfoOptionalEllipsis;

  /// planning.insertAgenda
  ///
  /// In de, this message translates to:
  /// **'Tagesordnung einfügen'**
  String get planningInsertAgenda;

  /// planning.item
  ///
  /// In de, this message translates to:
  /// **'Programmpunkt'**
  String get planningItem;

  /// planning.lastEvent
  ///
  /// In de, this message translates to:
  /// **'Dies ist die aktuell letzte Veranstaltung'**
  String get planningLastEvent;

  /// planning.linkCopied
  ///
  /// In de, this message translates to:
  /// **'Link in Zwischenablage kopiert'**
  String get planningLinkCopied;

  /// planning.minPlaceholder
  ///
  /// In de, this message translates to:
  /// **'min'**
  String get planningMinPlaceholder;

  /// planning.minShort
  ///
  /// In de, this message translates to:
  /// **'{min} min'**
  String planningMinShort(Object min);

  /// planning.minutes
  ///
  /// In de, this message translates to:
  /// **'Minuten'**
  String get planningMinutes;

  /// planning.moveLeft
  ///
  /// In de, this message translates to:
  /// **'Nach links verschieben'**
  String get planningMoveLeft;

  /// planning.moveRight
  ///
  /// In de, this message translates to:
  /// **'Nach rechts verschieben'**
  String get planningMoveRight;

  /// planning.name
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get planningName;

  /// planning.next
  ///
  /// In de, this message translates to:
  /// **'Nächste'**
  String get planningNext;

  /// planning.noPlan
  ///
  /// In de, this message translates to:
  /// **'Kein Plan verfügbar'**
  String get planningNoPlan;

  /// planning.noPlanAvailable
  ///
  /// In de, this message translates to:
  /// **'Kein Ablaufplan verfügbar.'**
  String get planningNoPlanAvailable;

  /// planning.noScoresInstrument
  ///
  /// In de, this message translates to:
  /// **'Keine Noten für dein Instrument'**
  String get planningNoScoresInstrument;

  /// planning.note
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get planningNote;

  /// planning.onlyDissolve
  ///
  /// In de, this message translates to:
  /// **'Nur Block auflösen'**
  String get planningOnlyDissolve;

  /// planning.onlyLabel
  ///
  /// In de, this message translates to:
  /// **'Nur {label}'**
  String planningOnlyLabel(Object label);

  /// planning.orgPlan
  ///
  /// In de, this message translates to:
  /// **'Organisationsplan'**
  String get planningOrgPlan;

  /// planning.outdent
  ///
  /// In de, this message translates to:
  /// **'Ausrücken'**
  String get planningOutdent;

  /// planning.performance
  ///
  /// In de, this message translates to:
  /// **'Ausführung'**
  String get planningPerformance;

  /// planning.performanceOptional
  ///
  /// In de, this message translates to:
  /// **'Ausführung (optional)'**
  String get planningPerformanceOptional;

  /// planning.performer
  ///
  /// In de, this message translates to:
  /// **'Ausführender'**
  String get planningPerformer;

  /// planning.planHeader
  ///
  /// In de, this message translates to:
  /// **'Plan „{label}“'**
  String planningPlanHeader(Object label);

  /// planning.planOptions
  ///
  /// In de, this message translates to:
  /// **'Plan-Optionen'**
  String get planningPlanOptions;

  /// planning.previous
  ///
  /// In de, this message translates to:
  /// **'Vorige'**
  String get planningPrevious;

  /// planning.readOnlyLink
  ///
  /// In de, this message translates to:
  /// **'Nur-Lesen-Link'**
  String get planningReadOnlyLink;

  /// planning.relatedAttendance
  ///
  /// In de, this message translates to:
  /// **'Zugehörige Anwesenheit'**
  String get planningRelatedAttendance;

  /// planning.rename
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get planningRename;

  /// planning.renameHint
  ///
  /// In de, this message translates to:
  /// **'Leer lassen für den automatischen Namen.'**
  String get planningRenameHint;

  /// planning.renamePlan
  ///
  /// In de, this message translates to:
  /// **'Plan umbenennen'**
  String get planningRenamePlan;

  /// planning.resetPlan
  ///
  /// In de, this message translates to:
  /// **'Plan zurücksetzen'**
  String get planningResetPlan;

  /// planning.resetPlanMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du den Plan für diese Veranstaltung wirklich zurücksetzen? Alle Änderungen gehen verloren.'**
  String get planningResetPlanMessage;

  /// planning.runSheet
  ///
  /// In de, this message translates to:
  /// **'Ablauf'**
  String get planningRunSheet;

  /// planning.saveAsTemplate
  ///
  /// In de, this message translates to:
  /// **'Als Vorlage speichern'**
  String get planningSaveAsTemplate;

  /// planning.sectionalPlan
  ///
  /// In de, this message translates to:
  /// **'Registerprobenplan'**
  String get planningSectionalPlan;

  /// planning.sectionalPlanTitle
  ///
  /// In de, this message translates to:
  /// **'{tenant} Registerprobenplan'**
  String planningSectionalPlanTitle(Object tenant);

  /// planning.sendingTelegram
  ///
  /// In de, this message translates to:
  /// **'Plan wird per Telegram gesendet...'**
  String get planningSendingTelegram;

  /// planning.shareLink
  ///
  /// In de, this message translates to:
  /// **'Link teilen'**
  String get planningShareLink;

  /// planning.shareWithMembers
  ///
  /// In de, this message translates to:
  /// **'Plan mit Mitgliedern teilen'**
  String get planningShareWithMembers;

  /// planning.soprano
  ///
  /// In de, this message translates to:
  /// **'Sopran'**
  String get planningSoprano;

  /// planning.strings
  ///
  /// In de, this message translates to:
  /// **'Streicher'**
  String get planningStrings;

  /// planning.subItemInfoPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Info-Text (optional), z. B. Liedtitel'**
  String get planningSubItemInfoPlaceholder;

  /// planning.subItemPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Programmpunkt, z. B. Gruppenlied'**
  String get planningSubItemPlaceholder;

  /// planning.telegramImageShort
  ///
  /// In de, this message translates to:
  /// **'Per Telegram (Bild)'**
  String get planningTelegramImageShort;

  /// planning.telegramPdfShort
  ///
  /// In de, this message translates to:
  /// **'Per Telegram (PDF)'**
  String get planningTelegramPdfShort;

  /// planning.templateSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Die Vorlage konnte nicht gespeichert werden.'**
  String get planningTemplateSaveFailed;

  /// planning.templateSaved
  ///
  /// In de, this message translates to:
  /// **'„{name}“ als Vorlage gespeichert'**
  String planningTemplateSaved(Object name);

  /// planning.templates
  ///
  /// In de, this message translates to:
  /// **'Vorlagen'**
  String get planningTemplates;

  /// planning.tenor
  ///
  /// In de, this message translates to:
  /// **'Tenor'**
  String get planningTenor;

  /// planning.timeMinutes
  ///
  /// In de, this message translates to:
  /// **'Zeit in Minuten'**
  String get planningTimeMinutes;

  /// planning.today
  ///
  /// In de, this message translates to:
  /// **'· heute'**
  String get planningToday;

  /// planning.unshare
  ///
  /// In de, this message translates to:
  /// **'Aufheben'**
  String get planningUnshare;

  /// planning.unshareConfirm
  ///
  /// In de, this message translates to:
  /// **'Freigabe aufheben?'**
  String get planningUnshareConfirm;

  /// planning.unshareMessage
  ///
  /// In de, this message translates to:
  /// **'Der öffentliche Link wird ungültig. Fortfahren?'**
  String get planningUnshareMessage;

  /// planning.unshared
  ///
  /// In de, this message translates to:
  /// **'Freigabe aufgehoben'**
  String get planningUnshared;

  /// planning.update
  ///
  /// In de, this message translates to:
  /// **'Updaten'**
  String get planningUpdate;

  /// planning.updateTemplate
  ///
  /// In de, this message translates to:
  /// **'Vorlage aktualisieren'**
  String get planningUpdateTemplate;

  /// planning.woodwinds
  ///
  /// In de, this message translates to:
  /// **'Holzbläser'**
  String get planningWoodwinds;

  /// plans.addFieldMin
  ///
  /// In de, this message translates to:
  /// **'Bitte mindestens ein Feld hinzufügen.'**
  String get plansAddFieldMin;

  /// plans.addOrgFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen zur Organisation'**
  String get plansAddOrgFailed;

  /// plans.addedToOrg
  ///
  /// In de, this message translates to:
  /// **'Plan zur Organisation \"{org}\" hinzugefügt'**
  String plansAddedToOrg(Object org);

  /// plans.applyTemplate
  ///
  /// In de, this message translates to:
  /// **'Vorlage anwenden'**
  String get plansApplyTemplate;

  /// plans.branding
  ///
  /// In de, this message translates to:
  /// **'Branding'**
  String get plansBranding;

  /// plans.calendarLinkMessage
  ///
  /// In de, this message translates to:
  /// **'Kopiere den folgenden Link in deine Kalender-App:\n\n{link}'**
  String plansCalendarLinkMessage(Object link);

  /// plans.copyLink
  ///
  /// In de, this message translates to:
  /// **'Link kopieren'**
  String get plansCopyLink;

  /// plans.date
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get plansDate;

  /// plans.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen'**
  String get plansDeleteFailed;

  /// plans.deletePlanForever
  ///
  /// In de, this message translates to:
  /// **'\"{title}\" endgültig löschen?'**
  String plansDeletePlanForever(Object title);

  /// plans.detailedCalendar
  ///
  /// In de, this message translates to:
  /// **'Detailliert (je Programmpunkt)'**
  String get plansDetailedCalendar;

  /// plans.discardNew
  ///
  /// In de, this message translates to:
  /// **'Aktuellen Plan verwerfen und einen neuen erstellen?'**
  String get plansDiscardNew;

  /// plans.durationMin
  ///
  /// In de, this message translates to:
  /// **'Dauer (min)'**
  String get plansDurationMin;

  /// plans.editStartTime
  ///
  /// In de, this message translates to:
  /// **'Startzeit bearbeiten'**
  String get plansEditStartTime;

  /// plans.editTitle
  ///
  /// In de, this message translates to:
  /// **'Titel bearbeiten'**
  String get plansEditTitle;

  /// plans.enterNotePlease
  ///
  /// In de, this message translates to:
  /// **'Bitte eine Notiz eingeben.'**
  String get plansEnterNotePlease;

  /// plans.fillDurations
  ///
  /// In de, this message translates to:
  /// **'Bitte alle Dauern ausfüllen.'**
  String get plansFillDurations;

  /// plans.flutter.addToOrg
  ///
  /// In de, this message translates to:
  /// **'Zur Organisation hinzufügen'**
  String get plansFlutterAddToOrg;

  /// plans.flutter.fieldsCount
  ///
  /// In de, this message translates to:
  /// **'{count} Felder'**
  String plansFlutterFieldsCount(Object count);

  /// plans.flutter.hideTab
  ///
  /// In de, this message translates to:
  /// **'Tab ausblenden'**
  String get plansFlutterHideTab;

  /// plans.flutter.inOrg
  ///
  /// In de, this message translates to:
  /// **'In Organisation \"{name}\"'**
  String plansFlutterInOrg(Object name);

  /// plans.flutter.orgPlansTitle
  ///
  /// In de, this message translates to:
  /// **'Organisationspläne'**
  String get plansFlutterOrgPlansTitle;

  /// plans.flutter.showAsTab
  ///
  /// In de, this message translates to:
  /// **'Als Tab anzeigen'**
  String get plansFlutterShowAsTab;

  /// plans.imageA4
  ///
  /// In de, this message translates to:
  /// **'Bild (A4)'**
  String get plansImageA4;

  /// plans.linkCopied
  ///
  /// In de, this message translates to:
  /// **'Link kopiert'**
  String get plansLinkCopied;

  /// plans.linkCreated
  ///
  /// In de, this message translates to:
  /// **'Link erstellt und kopiert'**
  String get plansLinkCreated;

  /// plans.linkFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen des Links'**
  String get plansLinkFailed;

  /// plans.linkInvalid
  ///
  /// In de, this message translates to:
  /// **'Link ungültig oder abgelaufen.'**
  String get plansLinkInvalid;

  /// plans.manage
  ///
  /// In de, this message translates to:
  /// **'Verwalten'**
  String get plansManage;

  /// plans.myPlans
  ///
  /// In de, this message translates to:
  /// **'Meine Pläne'**
  String get plansMyPlans;

  /// plans.newPlan
  ///
  /// In de, this message translates to:
  /// **'Neuer Plan'**
  String get plansNewPlan;

  /// plans.noOrg
  ///
  /// In de, this message translates to:
  /// **'Diese Instanz ist keiner Organisation zugeordnet.'**
  String get plansNoOrg;

  /// plans.noPlans
  ///
  /// In de, this message translates to:
  /// **'Keine Pläne vorhanden.'**
  String get plansNoPlans;

  /// plans.noTemplate
  ///
  /// In de, this message translates to:
  /// **'Keine Vorlage ausgewählt.'**
  String get plansNoTemplate;

  /// plans.noUpcomingOrgPlans
  ///
  /// In de, this message translates to:
  /// **'Keine bevorstehenden Org-Pläne. Pläne können über die Ablaufplanung zur Organisation hinzugefügt werden.'**
  String get plansNoUpcomingOrgPlans;

  /// plans.noUpcomingPlans
  ///
  /// In de, this message translates to:
  /// **'Keine bevorstehenden Org-Pläne vorhanden.'**
  String get plansNoUpcomingPlans;

  /// plans.notFound
  ///
  /// In de, this message translates to:
  /// **'Plan nicht gefunden. Der Link ist möglicherweise abgelaufen oder ungültig.'**
  String get plansNotFound;

  /// plans.openGuide
  ///
  /// In de, this message translates to:
  /// **'Anleitung öffnen'**
  String get plansOpenGuide;

  /// plans.openPlanning
  ///
  /// In de, this message translates to:
  /// **'Ablaufplanung öffnen'**
  String get plansOpenPlanning;

  /// plans.orgPlan
  ///
  /// In de, this message translates to:
  /// **'Org-Plan'**
  String get plansOrgPlan;

  /// plans.orgPlans
  ///
  /// In de, this message translates to:
  /// **'Org-Pläne'**
  String get plansOrgPlans;

  /// plans.orgSuffix
  ///
  /// In de, this message translates to:
  /// **'{title} (Org)'**
  String plansOrgSuffix(Object title);

  /// plans.orgTemplates
  ///
  /// In de, this message translates to:
  /// **'── Org-Vorlagen ──'**
  String get plansOrgTemplates;

  /// plans.pastPlans
  ///
  /// In de, this message translates to:
  /// **'Vergangene Pläne'**
  String get plansPastPlans;

  /// plans.performerOptional
  ///
  /// In de, this message translates to:
  /// **'Ausführender (optional)'**
  String get plansPerformerOptional;

  /// plans.plan
  ///
  /// In de, this message translates to:
  /// **'Plan'**
  String get plansPlan;

  /// plans.planning
  ///
  /// In de, this message translates to:
  /// **'Ablaufplanung'**
  String get plansPlanning;

  /// plans.points
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Punkt} other {{count} Punkte}}'**
  String plansPoints(num count);

  /// plans.publicLink
  ///
  /// In de, this message translates to:
  /// **'Öffentlicher Link'**
  String get plansPublicLink;

  /// plans.publicLinkActive
  ///
  /// In de, this message translates to:
  /// **'Öffentlicher Link aktiv. Alle Org-Pläne sind für jeden mit dem Link einsehbar.'**
  String get plansPublicLinkActive;

  /// plans.removeOrgFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Entfernen aus der Organisation'**
  String get plansRemoveOrgFailed;

  /// plans.removedFromOrg
  ///
  /// In de, this message translates to:
  /// **'Plan aus Organisation entfernt'**
  String get plansRemovedFromOrg;

  /// plans.replaceWithTemplate
  ///
  /// In de, this message translates to:
  /// **'Aktuellen Ablauf durch die Vorlage ersetzen?'**
  String get plansReplaceWithTemplate;

  /// plans.restore
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen'**
  String get plansRestore;

  /// plans.restoreTemplate
  ///
  /// In de, this message translates to:
  /// **'Vorlage wiederherstellen'**
  String get plansRestoreTemplate;

  /// plans.restoreTemplateMessage
  ///
  /// In de, this message translates to:
  /// **'Alle Änderungen verwerfen und die Standardwerte der Vorlage „{name}“ wiederherstellen?'**
  String plansRestoreTemplateMessage(Object name);

  /// plans.revokeLink
  ///
  /// In de, this message translates to:
  /// **'Link widerrufen'**
  String get plansRevokeLink;

  /// plans.runSheet
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan'**
  String get plansRunSheet;

  /// plans.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern'**
  String get plansSaveFailed;

  /// plans.savePlanFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern des Plans'**
  String get plansSavePlanFailed;

  /// plans.shareExport
  ///
  /// In de, this message translates to:
  /// **'Teilen & Exportieren'**
  String get plansShareExport;

  /// plans.simpleCalendar
  ///
  /// In de, this message translates to:
  /// **'Einfach (1 Termin je Plan)'**
  String get plansSimpleCalendar;

  /// plans.subscribeCalendar
  ///
  /// In de, this message translates to:
  /// **'Kalender abonnieren'**
  String get plansSubscribeCalendar;

  /// plans.template
  ///
  /// In de, this message translates to:
  /// **'Vorlage'**
  String get plansTemplate;

  /// plans.title
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get plansTitle;

  /// protocol.add
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get protocolAdd;

  /// protocol.addPoint
  ///
  /// In de, this message translates to:
  /// **'Punkt hinzufügen'**
  String get protocolAddPoint;

  /// protocol.agenda
  ///
  /// In de, this message translates to:
  /// **'Tagesordnung'**
  String get protocolAgenda;

  /// protocol.agendaItem
  ///
  /// In de, this message translates to:
  /// **'Tagesordnungspunkt'**
  String get protocolAgendaItem;

  /// protocol.alwaysVisible
  ///
  /// In de, this message translates to:
  /// **'Immer sichtbar, unabhängig vom Punkt'**
  String get protocolAlwaysVisible;

  /// protocol.autoSaved
  ///
  /// In de, this message translates to:
  /// **'Wird automatisch gespeichert'**
  String get protocolAutoSaved;

  /// protocol.autoSavedAt
  ///
  /// In de, this message translates to:
  /// **'Automatisch gespeichert · {time}'**
  String protocolAutoSavedAt(Object time);

  /// protocol.changesAutoSaved
  ///
  /// In de, this message translates to:
  /// **'Änderungen werden automatisch gespeichert'**
  String get protocolChangesAutoSaved;

  /// protocol.closeFailed
  ///
  /// In de, this message translates to:
  /// **'Nicht alle Themen konnten als erledigt markiert werden'**
  String get protocolCloseFailed;

  /// protocol.closeTopics
  ///
  /// In de, this message translates to:
  /// **'Themen als erledigt markieren'**
  String get protocolCloseTopics;

  /// protocol.createFailed
  ///
  /// In de, this message translates to:
  /// **'Protokoll konnte nicht angelegt werden'**
  String get protocolCreateFailed;

  /// protocol.decidedCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Thema} other {{count} Themen}} beschlossen'**
  String protocolDecidedCount(num count);

  /// protocol.discussedCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Thema} other {{count} Themen}} besprochen'**
  String protocolDiscussedCount(num count);

  /// protocol.dragResize
  ///
  /// In de, this message translates to:
  /// **'Ziehen, um die Breite anzupassen (Doppelklick setzt zurück)'**
  String get protocolDragResize;

  /// protocol.dueShort
  ///
  /// In de, this message translates to:
  /// **'fällig {date}'**
  String protocolDueShort(Object date);

  /// protocol.durationMinutes
  ///
  /// In de, this message translates to:
  /// **'Dauer in Minuten'**
  String get protocolDurationMinutes;

  /// protocol.earlierItem
  ///
  /// In de, this message translates to:
  /// **'Früherer Programmpunkt'**
  String get protocolEarlierItem;

  /// protocol.editAfterPublish
  ///
  /// In de, this message translates to:
  /// **'Die Leitung kann das Protokoll auch nach der Freigabe noch bearbeiten. Änderungen werden mit Datum angezeigt.'**
  String get protocolEditAfterPublish;

  /// protocol.excusedCount
  ///
  /// In de, this message translates to:
  /// **'{count} entschuldigt · '**
  String protocolExcusedCount(Object count);

  /// protocol.excusedList
  ///
  /// In de, this message translates to:
  /// **'Entschuldigt ({count})'**
  String protocolExcusedList(Object count);

  /// protocol.fileName
  ///
  /// In de, this message translates to:
  /// **'Protokoll {title} {date}'**
  String protocolFileName(Object title, Object date);

  /// protocol.flutter.chooseLeft
  ///
  /// In de, this message translates to:
  /// **'Wähle links einen Punkt aus.'**
  String get protocolFlutterChooseLeft;

  /// protocol.flutter.doneLower
  ///
  /// In de, this message translates to:
  /// **'erledigt'**
  String get protocolFlutterDoneLower;

  /// protocol.flutter.keepDraft
  ///
  /// In de, this message translates to:
  /// **'Als Entwurf lassen'**
  String get protocolFlutterKeepDraft;

  /// protocol.flutter.planEmptyShort
  ///
  /// In de, this message translates to:
  /// **'Der Ablaufplan ist noch leer.'**
  String get protocolFlutterPlanEmptyShort;

  /// protocol.flutter.publishNotify
  ///
  /// In de, this message translates to:
  /// **'Freigeben & benachrichtigen'**
  String get protocolFlutterPublishNotify;

  /// protocol.flutter.republishNotify
  ///
  /// In de, this message translates to:
  /// **'Erneut freigeben & benachrichtigen'**
  String get protocolFlutterRepublishNotify;

  /// protocol.forNames
  ///
  /// In de, this message translates to:
  /// **'für {names}'**
  String protocolForNames(Object names);

  /// protocol.fromAttendance
  ///
  /// In de, this message translates to:
  /// **'aus der Anwesenheit'**
  String get protocolFromAttendance;

  /// protocol.furtherTasks
  ///
  /// In de, this message translates to:
  /// **'Weitere Aufgaben'**
  String get protocolFurtherTasks;

  /// protocol.general
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get protocolGeneral;

  /// protocol.generalNotes
  ///
  /// In de, this message translates to:
  /// **'Allgemeine Notizen'**
  String get protocolGeneralNotes;

  /// protocol.generalTask
  ///
  /// In de, this message translates to:
  /// **'Aufgabe zu den allgemeinen Notizen'**
  String get protocolGeneralTask;

  /// protocol.hasNotes
  ///
  /// In de, this message translates to:
  /// **'Enthält Notizen'**
  String get protocolHasNotes;

  /// protocol.listFromAttendance
  ///
  /// In de, this message translates to:
  /// **'Die Liste kommt aus der Anwesenheit des Termins.'**
  String get protocolListFromAttendance;

  /// protocol.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Protokoll konnte nicht geladen werden.'**
  String get protocolLoadFailed;

  /// protocol.mayRead
  ///
  /// In de, this message translates to:
  /// **'Lesen dürfen'**
  String get protocolMayRead;

  /// protocol.moreNotes
  ///
  /// In de, this message translates to:
  /// **'Weitere Notizen'**
  String get protocolMoreNotes;

  /// protocol.moreNotesHint
  ///
  /// In de, this message translates to:
  /// **'Notizen zu Punkten, die nicht mehr im Ablaufplan stehen.'**
  String get protocolMoreNotesHint;

  /// protocol.moreNotesTitle
  ///
  /// In de, this message translates to:
  /// **'Weitere Notizen · {title}'**
  String protocolMoreNotesTitle(Object title);

  /// protocol.moreTasks
  ///
  /// In de, this message translates to:
  /// **'Weitere Aufgaben dieser Sitzung'**
  String get protocolMoreTasks;

  /// protocol.nextPoint
  ///
  /// In de, this message translates to:
  /// **'Nächster Punkt'**
  String get protocolNextPoint;

  /// protocol.noNotes
  ///
  /// In de, this message translates to:
  /// **'Keine Notizen'**
  String get protocolNoNotes;

  /// protocol.noTasksYet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Aufgaben. Lege sie direkt bei einem Punkt an.'**
  String get protocolNoTasksYet;

  /// protocol.nobodyPresent
  ///
  /// In de, this message translates to:
  /// **'Niemand als anwesend eingetragen'**
  String get protocolNobodyPresent;

  /// protocol.notInPlan
  ///
  /// In de, this message translates to:
  /// **'Dieser Punkt steht nicht mehr im Ablaufplan. Die Notizen bleiben erhalten.'**
  String get protocolNotInPlan;

  /// protocol.notPublished
  ///
  /// In de, this message translates to:
  /// **'Dieses Protokoll ist noch nicht freigegeben.'**
  String get protocolNotPublished;

  /// protocol.notPublishedHint
  ///
  /// In de, this message translates to:
  /// **'Sobald die Leitung es freigibt, kannst du es hier lesen.'**
  String get protocolNotPublishedHint;

  /// protocol.noted
  ///
  /// In de, this message translates to:
  /// **'Notiert'**
  String get protocolNoted;

  /// protocol.notes
  ///
  /// In de, this message translates to:
  /// **'Notizen'**
  String get protocolNotes;

  /// protocol.notesSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Notizen konnten nicht gespeichert werden. Prüfe deine Verbindung.'**
  String get protocolNotesSaveFailed;

  /// protocol.notified
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigt werden'**
  String get protocolNotified;

  /// protocol.open
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get protocolOpen;

  /// protocol.othersList
  ///
  /// In de, this message translates to:
  /// **'Nicht da / offen ({count})'**
  String protocolOthersList(Object count);

  /// protocol.outcome
  ///
  /// In de, this message translates to:
  /// **'Ergebnis'**
  String get protocolOutcome;

  /// protocol.outcomeSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Ergebnis konnte nicht gespeichert werden'**
  String get protocolOutcomeSaveFailed;

  /// protocol.page
  ///
  /// In de, this message translates to:
  /// **'Seite {i} von {n}'**
  String protocolPage(Object i, Object n);

  /// protocol.participants
  ///
  /// In de, this message translates to:
  /// **'Teilnehmende'**
  String get protocolParticipants;

  /// protocol.pdfFailed
  ///
  /// In de, this message translates to:
  /// **'PDF konnte nicht erstellt werden'**
  String get protocolPdfFailed;

  /// protocol.pdfFailedNotify
  ///
  /// In de, this message translates to:
  /// **'PDF konnte nicht erstellt werden, die Benachrichtigung geht ohne PDF raus'**
  String get protocolPdfFailedNotify;

  /// protocol.pdfTitle
  ///
  /// In de, this message translates to:
  /// **'Protokoll · {title}'**
  String protocolPdfTitle(Object title);

  /// protocol.planEmpty
  ///
  /// In de, this message translates to:
  /// **'Der Ablaufplan ist noch leer. Füge einen Punkt hinzu oder schreib in die Notizen.'**
  String get protocolPlanEmpty;

  /// protocol.point
  ///
  /// In de, this message translates to:
  /// **'Punkt'**
  String get protocolPoint;

  /// protocol.pointFailed
  ///
  /// In de, this message translates to:
  /// **'Punkt konnte nicht hinzugefügt werden'**
  String get protocolPointFailed;

  /// protocol.pointNotes
  ///
  /// In de, this message translates to:
  /// **'Notizen zum Punkt'**
  String get protocolPointNotes;

  /// protocol.postponedCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Thema} other {{count} Themen}} vertagt'**
  String protocolPostponedCount(num count);

  /// protocol.present
  ///
  /// In de, this message translates to:
  /// **'Anwesend'**
  String get protocolPresent;

  /// protocol.presentCount
  ///
  /// In de, this message translates to:
  /// **'{count} anwesend'**
  String protocolPresentCount(Object count);

  /// protocol.presentList
  ///
  /// In de, this message translates to:
  /// **'Anwesend ({count})'**
  String protocolPresentList(Object count);

  /// protocol.publish
  ///
  /// In de, this message translates to:
  /// **'Protokoll freigeben'**
  String get protocolPublish;

  /// protocol.publishFailed
  ///
  /// In de, this message translates to:
  /// **'Protokoll konnte nicht freigegeben werden'**
  String get protocolPublishFailed;

  /// protocol.publishShort
  ///
  /// In de, this message translates to:
  /// **'Freigeben'**
  String get protocolPublishShort;

  /// protocol.published
  ///
  /// In de, this message translates to:
  /// **'Protokoll freigegeben'**
  String get protocolPublished;

  /// protocol.readAll
  ///
  /// In de, this message translates to:
  /// **'alle Mitglieder (Termintyp „{type}“ hat keine Gruppen)'**
  String protocolReadAll(Object type);

  /// protocol.readGroups
  ///
  /// In de, this message translates to:
  /// **'die Gruppen aus dem Termintyp „{type}“'**
  String protocolReadGroups(Object type);

  /// protocol.recipients
  ///
  /// In de, this message translates to:
  /// **'{count} Anwesende'**
  String protocolRecipients(Object count);

  /// protocol.republish
  ///
  /// In de, this message translates to:
  /// **'Erneut freigeben'**
  String get protocolRepublish;

  /// protocol.resizeAgenda
  ///
  /// In de, this message translates to:
  /// **'Breite der Tagesordnung anpassen'**
  String get protocolResizeAgenda;

  /// protocol.resizeGeneral
  ///
  /// In de, this message translates to:
  /// **'Breite der allgemeinen Notizen anpassen'**
  String get protocolResizeGeneral;

  /// protocol.responsible
  ///
  /// In de, this message translates to:
  /// **'Verantwortlich: {name}'**
  String protocolResponsible(Object name);

  /// protocol.retry
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get protocolRetry;

  /// protocol.runSheet
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan'**
  String get protocolRunSheet;

  /// protocol.running
  ///
  /// In de, this message translates to:
  /// **'Läuft: {name} · noch {min} min'**
  String protocolRunning(Object name, Object min);

  /// protocol.saving
  ///
  /// In de, this message translates to:
  /// **'Speichert …'**
  String get protocolSaving;

  /// protocol.sendPdf
  ///
  /// In de, this message translates to:
  /// **'Protokoll als PDF mitschicken'**
  String get protocolSendPdf;

  /// protocol.sessionTasks
  ///
  /// In de, this message translates to:
  /// **'Aufgaben dieser Sitzung · {count}'**
  String protocolSessionTasks(Object count);

  /// protocol.sharePdf
  ///
  /// In de, this message translates to:
  /// **'Als PDF teilen'**
  String get protocolSharePdf;

  /// protocol.shortcutNext
  ///
  /// In de, this message translates to:
  /// **'⌘/Strg ↓'**
  String get protocolShortcutNext;

  /// protocol.spontaneous
  ///
  /// In de, this message translates to:
  /// **'Spontaner Punkt'**
  String get protocolSpontaneous;

  /// protocol.spontaneousHint
  ///
  /// In de, this message translates to:
  /// **'Wird als neues Thema angelegt und im Ablaufplan ergänzt.'**
  String get protocolSpontaneousHint;

  /// protocol.suggestNext
  ///
  /// In de, this message translates to:
  /// **' · wird beim nächsten Termin vorgeschlagen'**
  String get protocolSuggestNext;

  /// protocol.summary
  ///
  /// In de, this message translates to:
  /// **'Zusammenfassung'**
  String get protocolSummary;

  /// protocol.taskCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Aufgabe} other {{count} Aufgaben}}'**
  String protocolTaskCount(num count);

  /// protocol.taskOwners
  ///
  /// In de, this message translates to:
  /// **' · {count, plural, one {{count} Person} other {{count} Personen}} mit Aufgaben'**
  String protocolTaskOwners(num count);

  /// protocol.taskRef
  ///
  /// In de, this message translates to:
  /// **'Aufgabe: {title}'**
  String protocolTaskRef(Object title);

  /// protocol.title
  ///
  /// In de, this message translates to:
  /// **'Protokoll'**
  String get protocolTitle;

  /// protocol.top
  ///
  /// In de, this message translates to:
  /// **'TOP {n}'**
  String protocolTop(Object n);

  /// protocol.topicRef
  ///
  /// In de, this message translates to:
  /// **'Thema: {title}'**
  String protocolTopicRef(Object title);

  /// protocol.viaTelegram
  ///
  /// In de, this message translates to:
  /// **'Per Telegram als Dokument'**
  String get protocolViaTelegram;

  /// protocol.visibility
  ///
  /// In de, this message translates to:
  /// **'Sichtbarkeit'**
  String get protocolVisibility;

  /// protocol.wholeMeeting
  ///
  /// In de, this message translates to:
  /// **'Gilt für die ganze Sitzung, unabhängig vom Punkt.'**
  String get protocolWholeMeeting;

  /// protocol.withoutNotes
  ///
  /// In de, this message translates to:
  /// **'Noch ohne Notizen: {count}'**
  String protocolWithoutNotes(Object count);

  /// protocol.withoutOutcome
  ///
  /// In de, this message translates to:
  /// **'Ohne Ergebnis: {count}'**
  String protocolWithoutOutcome(Object count);

  /// redesign.absence.affects
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0 {In diesem Zeitraum hast du keine Termine.} one {Das betrifft 1 Termin} other {Das betrifft {count} Termine}}'**
  String redesignAbsenceAffects(num count);

  /// redesign.absence.chooseEnd
  ///
  /// In de, this message translates to:
  /// **'Tippe auf den letzten Tag.'**
  String get redesignAbsenceChooseEnd;

  /// redesign.absence.chooseStart
  ///
  /// In de, this message translates to:
  /// **'Tippe auf den ersten Tag.'**
  String get redesignAbsenceChooseStart;

  /// redesign.absence.nextMonth
  ///
  /// In de, this message translates to:
  /// **'Nächster Monat'**
  String get redesignAbsenceNextMonth;

  /// redesign.absence.pause
  ///
  /// In de, this message translates to:
  /// **'Pausieren'**
  String get redesignAbsencePause;

  /// redesign.absence.pauseButton
  ///
  /// In de, this message translates to:
  /// **'Pausieren …'**
  String get redesignAbsencePauseButton;

  /// redesign.absence.pauseHint
  ///
  /// In de, this message translates to:
  /// **'Wenn du länger nicht kannst, kannst du dich pausieren. Die Leitung sieht dann, dass du gerade nicht dabei bist.'**
  String get redesignAbsencePauseHint;

  /// redesign.absence.period
  ///
  /// In de, this message translates to:
  /// **'Zeitraum'**
  String get redesignAbsencePeriod;

  /// redesign.absence.prevMonth
  ///
  /// In de, this message translates to:
  /// **'Voriger Monat'**
  String get redesignAbsencePrevMonth;

  /// redesign.absence.range
  ///
  /// In de, this message translates to:
  /// **'Zeitraum abwesend'**
  String get redesignAbsenceRange;

  /// redesign.absence.reason
  ///
  /// In de, this message translates to:
  /// **'Grund'**
  String get redesignAbsenceReason;

  /// redesign.absence.reasonHint
  ///
  /// In de, this message translates to:
  /// **'z. B. Urlaub'**
  String get redesignAbsenceReasonHint;

  /// redesign.absence.reset
  ///
  /// In de, this message translates to:
  /// **'Zeitraum zurücksetzen'**
  String get redesignAbsenceReset;

  /// redesign.absence.submit
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit eintragen'**
  String get redesignAbsenceSubmit;

  /// redesign.absence.title
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit'**
  String get redesignAbsenceTitle;

  /// redesign.adminTitle
  ///
  /// In de, this message translates to:
  /// **'Verwaltung'**
  String get redesignAdminTitle;

  /// redesign.appearance.appIcon
  ///
  /// In de, this message translates to:
  /// **'App-Symbol'**
  String get redesignAppearanceAppIcon;

  /// redesign.appearance.appIconFollow
  ///
  /// In de, this message translates to:
  /// **'App-Symbol in Farbwelt'**
  String get redesignAppearanceAppIconFollow;

  /// redesign.appearance.appIconHint
  ///
  /// In de, this message translates to:
  /// **'Das Symbol auf dem Home-Bildschirm wechselt mit der Farbwelt.'**
  String get redesignAppearanceAppIconHint;

  /// redesign.appearance.autoHint
  ///
  /// In de, this message translates to:
  /// **'Automatisch folgt der Einstellung deines Geräts.'**
  String get redesignAppearanceAutoHint;

  /// redesign.appearance.brightness
  ///
  /// In de, this message translates to:
  /// **'Hell oder dunkel'**
  String get redesignAppearanceBrightness;

  /// redesign.appearance.deviceOnly
  ///
  /// In de, this message translates to:
  /// **'Diese Einstellungen gelten nur auf diesem Gerät.'**
  String get redesignAppearanceDeviceOnly;

  /// redesign.appearance.modeAuto
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get redesignAppearanceModeAuto;

  /// redesign.appearance.modeDark
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get redesignAppearanceModeDark;

  /// redesign.appearance.modeLight
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get redesignAppearanceModeLight;

  /// redesign.appearance.preview
  ///
  /// In de, this message translates to:
  /// **'Vorschau der gewählten Farbwelt'**
  String get redesignAppearancePreview;

  /// redesign.appearance.previewTitle
  ///
  /// In de, this message translates to:
  /// **'Probe'**
  String get redesignAppearancePreviewTitle;

  /// redesign.appearance.stageAlwaysDark
  ///
  /// In de, this message translates to:
  /// **'Bühne ist immer dunkel.'**
  String get redesignAppearanceStageAlwaysDark;

  /// redesign.appearance.title
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get redesignAppearanceTitle;

  /// redesign.appearance.world
  ///
  /// In de, this message translates to:
  /// **'Farbwelt'**
  String get redesignAppearanceWorld;

  /// redesign.appearance.worldClear
  ///
  /// In de, this message translates to:
  /// **'Klar'**
  String get redesignAppearanceWorldClear;

  /// redesign.appearance.worldClearHint
  ///
  /// In de, this message translates to:
  /// **'Schwarz auf Weiß, höchster Kontrast'**
  String get redesignAppearanceWorldClearHint;

  /// redesign.appearance.worldConcertHall
  ///
  /// In de, this message translates to:
  /// **'Konzertsaal'**
  String get redesignAppearanceWorldConcertHall;

  /// redesign.appearance.worldConcertHallHint
  ///
  /// In de, this message translates to:
  /// **'Warm, mit Serifen-Überschriften'**
  String get redesignAppearanceWorldConcertHallHint;

  /// redesign.appearance.worldNightBlue
  ///
  /// In de, this message translates to:
  /// **'Nachtblau'**
  String get redesignAppearanceWorldNightBlue;

  /// redesign.appearance.worldNightBlueHint
  ///
  /// In de, this message translates to:
  /// **'Kräftig und rund'**
  String get redesignAppearanceWorldNightBlueHint;

  /// redesign.appearance.worldPetrol
  ///
  /// In de, this message translates to:
  /// **'Petrol'**
  String get redesignAppearanceWorldPetrol;

  /// redesign.appearance.worldPetrolHint
  ///
  /// In de, this message translates to:
  /// **'Ruhig und klar (Standard)'**
  String get redesignAppearanceWorldPetrolHint;

  /// redesign.appearance.worldStage
  ///
  /// In de, this message translates to:
  /// **'Bühne'**
  String get redesignAppearanceWorldStage;

  /// redesign.appearance.worldStageHint
  ///
  /// In de, this message translates to:
  /// **'Immer dunkel, für Abende und Proben'**
  String get redesignAppearanceWorldStageHint;

  /// redesign.applicant.otherGroup
  ///
  /// In de, this message translates to:
  /// **'Andere Gruppe beitreten'**
  String get redesignApplicantOtherGroup;

  /// redesign.applicant.title
  ///
  /// In de, this message translates to:
  /// **'Bewerbung'**
  String get redesignApplicantTitle;

  /// redesign.applicant.waiting
  ///
  /// In de, this message translates to:
  /// **'Deine Anmeldung wird geprüft'**
  String get redesignApplicantWaiting;

  /// redesign.applicant.waitingFor
  ///
  /// In de, this message translates to:
  /// **'Deine Anmeldung bei {group} wird geprüft'**
  String redesignApplicantWaitingFor(Object group);

  /// redesign.bulk.actionArchive
  ///
  /// In de, this message translates to:
  /// **'Archivieren'**
  String get redesignBulkActionArchive;

  /// redesign.bulk.actionGroup
  ///
  /// In de, this message translates to:
  /// **'Register'**
  String get redesignBulkActionGroup;

  /// redesign.bulk.actionPause
  ///
  /// In de, this message translates to:
  /// **'Pausieren'**
  String get redesignBulkActionPause;

  /// redesign.bulk.archiveConfirm
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Person archivieren?} other {{count} Personen archivieren?}}'**
  String redesignBulkArchiveConfirm(num count);

  /// redesign.bulk.archiveHint
  ///
  /// In de, this message translates to:
  /// **'Archivierte Mitglieder findest du unter Archiv.'**
  String get redesignBulkArchiveHint;

  /// redesign.bulk.clear
  ///
  /// In de, this message translates to:
  /// **'Auswahl aufheben'**
  String get redesignBulkClear;

  /// redesign.bulk.done
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Person geändert} other {{count} Personen geändert}}'**
  String redesignBulkDone(num count);

  /// redesign.bulk.failed
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Änderung fehlgeschlagen} other {{count} Änderungen fehlgeschlagen}}'**
  String redesignBulkFailed(num count);

  /// redesign.bulk.hint
  ///
  /// In de, this message translates to:
  /// **'Mitglieder antippen, dann unten eine Aktion wählen.'**
  String get redesignBulkHint;

  /// redesign.bulk.noGroup
  ///
  /// In de, this message translates to:
  /// **'Ohne Register'**
  String get redesignBulkNoGroup;

  /// redesign.bulk.pauseReason
  ///
  /// In de, this message translates to:
  /// **'Grund der Pause'**
  String get redesignBulkPauseReason;

  /// redesign.bulk.pickGroup
  ///
  /// In de, this message translates to:
  /// **'Neues Register'**
  String get redesignBulkPickGroup;

  /// redesign.bulk.search
  ///
  /// In de, this message translates to:
  /// **'Mitglied suchen'**
  String get redesignBulkSearch;

  /// redesign.bulk.selectGroup
  ///
  /// In de, this message translates to:
  /// **'Alle in {group}'**
  String redesignBulkSelectGroup(Object group);

  /// redesign.bulk.selected
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0 {Keine Auswahl} one {1 ausgewählt} other {{count} ausgewählt}}'**
  String redesignBulkSelected(num count);

  /// redesign.bulk.title
  ///
  /// In de, this message translates to:
  /// **'Mitglieder bearbeiten'**
  String get redesignBulkTitle;

  /// redesign.common.all
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get redesignCommonAll;

  /// redesign.common.cancel
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get redesignCommonCancel;

  /// redesign.common.done
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get redesignCommonDone;

  /// redesign.common.retry
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get redesignCommonRetry;

  /// redesign.compose.body
  ///
  /// In de, this message translates to:
  /// **'Text'**
  String get redesignComposeBody;

  /// redesign.compose.groups
  ///
  /// In de, this message translates to:
  /// **'Register wählen'**
  String get redesignComposeGroups;

  /// redesign.compose.hint
  ///
  /// In de, this message translates to:
  /// **'Die Mitteilung erscheint bei allen Empfängern unter Mitteilungen.'**
  String get redesignComposeHint;

  /// redesign.compose.missing
  ///
  /// In de, this message translates to:
  /// **'Betreff, Text und mindestens ein Versandweg fehlen noch.'**
  String get redesignComposeMissing;

  /// redesign.compose.send
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get redesignComposeSend;

  /// redesign.compose.subject
  ///
  /// In de, this message translates to:
  /// **'Betreff'**
  String get redesignComposeSubject;

  /// redesign.compose.title
  ///
  /// In de, this message translates to:
  /// **'Mitteilung schreiben'**
  String get redesignComposeTitle;

  /// redesign.compose.to
  ///
  /// In de, this message translates to:
  /// **'An wen?'**
  String get redesignComposeTo;

  /// redesign.create.chooseType
  ///
  /// In de, this message translates to:
  /// **'Art wählen'**
  String get redesignCreateChooseType;

  /// redesign.create.date
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get redesignCreateDate;

  /// redesign.create.days
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Tag} other {{count} Tage}}'**
  String redesignCreateDays(num count);

  /// redesign.create.deadline
  ///
  /// In de, this message translates to:
  /// **'Abmeldeschluss'**
  String get redesignCreateDeadline;

  /// redesign.create.deadline24h
  ///
  /// In de, this message translates to:
  /// **'24 Std. vorher'**
  String get redesignCreateDeadline24h;

  /// redesign.create.deadline2d
  ///
  /// In de, this message translates to:
  /// **'2 Tage vorher'**
  String get redesignCreateDeadline2d;

  /// redesign.create.deadlineHint
  ///
  /// In de, this message translates to:
  /// **'Danach können sich Mitglieder nicht mehr selbst an- oder abmelden.'**
  String get redesignCreateDeadlineHint;

  /// redesign.create.deadlineNone
  ///
  /// In de, this message translates to:
  /// **'Keiner'**
  String get redesignCreateDeadlineNone;

  /// redesign.create.deadlineWeek
  ///
  /// In de, this message translates to:
  /// **'1 Woche vorher'**
  String get redesignCreateDeadlineWeek;

  /// redesign.create.discard
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get redesignCreateDiscard;

  /// redesign.create.discardBody
  ///
  /// In de, this message translates to:
  /// **'Deine Eingaben gehen verloren.'**
  String get redesignCreateDiscardBody;

  /// redesign.create.discardTitle
  ///
  /// In de, this message translates to:
  /// **'Termin verwerfen?'**
  String get redesignCreateDiscardTitle;

  /// redesign.create.duration
  ///
  /// In de, this message translates to:
  /// **'Dauer'**
  String get redesignCreateDuration;

  /// redesign.create.duty
  ///
  /// In de, this message translates to:
  /// **'Benötigt am {weekday}'**
  String redesignCreateDuty(Object weekday);

  /// redesign.create.dutyCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Termin} other {{count} Termine}}'**
  String redesignCreateDutyCount(num count);

  /// redesign.create.end
  ///
  /// In de, this message translates to:
  /// **'Ende'**
  String get redesignCreateEnd;

  /// redesign.create.fewer
  ///
  /// In de, this message translates to:
  /// **'Weniger'**
  String get redesignCreateFewer;

  /// redesign.create.fewerDays
  ///
  /// In de, this message translates to:
  /// **'Einen Tag weniger'**
  String get redesignCreateFewerDays;

  /// redesign.create.holidayHits
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Termin fällt in Ferien oder auf einen Feiertag} other {{count} Termine fallen in Ferien oder auf Feiertage}}'**
  String redesignCreateHolidayHits(num count);

  /// redesign.create.invited
  ///
  /// In de, this message translates to:
  /// **'Wer ist eingeladen?'**
  String get redesignCreateInvited;

  /// redesign.create.invitedAll
  ///
  /// In de, this message translates to:
  /// **'Alle · {count}'**
  String redesignCreateInvitedAll(Object count);

  /// redesign.create.invitedGroups
  ///
  /// In de, this message translates to:
  /// **'{groups} · {count}'**
  String redesignCreateInvitedGroups(Object groups, Object count);

  /// redesign.create.invitedHint
  ///
  /// In de, this message translates to:
  /// **'Festgelegt durch die Art'**
  String get redesignCreateInvitedHint;

  /// redesign.create.keepEditing
  ///
  /// In de, this message translates to:
  /// **'Weiter bearbeiten'**
  String get redesignCreateKeepEditing;

  /// redesign.create.laterHint
  ///
  /// In de, this message translates to:
  /// **'Infotext, Anhang, Checkliste und Ablauf bearbeitest du danach im Termin.'**
  String get redesignCreateLaterHint;

  /// redesign.create.more
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get redesignCreateMore;

  /// redesign.create.moreDates
  ///
  /// In de, this message translates to:
  /// **'Weitere Daten'**
  String get redesignCreateMoreDates;

  /// redesign.create.moreDatesNone
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get redesignCreateMoreDatesNone;

  /// redesign.create.moreDays
  ///
  /// In de, this message translates to:
  /// **'Einen Tag mehr'**
  String get redesignCreateMoreDays;

  /// redesign.create.noPermission
  ///
  /// In de, this message translates to:
  /// **'Du darfst keine Termine anlegen.'**
  String get redesignCreateNoPermission;

  /// redesign.create.noTypes
  ///
  /// In de, this message translates to:
  /// **'Es gibt noch keine Termin-Art. Lege zuerst eine in den Einstellungen an.'**
  String get redesignCreateNoTypes;

  /// redesign.create.place
  ///
  /// In de, this message translates to:
  /// **'Ort'**
  String get redesignCreatePlace;

  /// redesign.create.placeHint
  ///
  /// In de, this message translates to:
  /// **'z. B. Probenraum, Musterstr. 1'**
  String get redesignCreatePlaceHint;

  /// redesign.create.repeatBiweekly
  ///
  /// In de, this message translates to:
  /// **'Alle 2 Wochen bis {date}'**
  String redesignCreateRepeatBiweekly(Object date);

  /// redesign.create.repeatBiweeklyOption
  ///
  /// In de, this message translates to:
  /// **'Alle 2 Wochen'**
  String get redesignCreateRepeatBiweeklyOption;

  /// redesign.create.repeatCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Termin} other {{count} Termine}}'**
  String redesignCreateRepeatCount(num count);

  /// redesign.create.repeatCustom
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 weiterer Tag} other {{count} weitere Tage}}'**
  String redesignCreateRepeatCustom(num count);

  /// redesign.create.repeatCustomOption
  ///
  /// In de, this message translates to:
  /// **'Einzelne Tage'**
  String get redesignCreateRepeatCustomOption;

  /// redesign.create.repeatHoliday
  ///
  /// In de, this message translates to:
  /// **'Ferien oder Feiertag'**
  String get redesignCreateRepeatHoliday;

  /// redesign.create.repeatMax
  ///
  /// In de, this message translates to:
  /// **'Höchstens {count} Termine auf einmal.'**
  String redesignCreateRepeatMax(Object count);

  /// redesign.create.repeatOnce
  ///
  /// In de, this message translates to:
  /// **'Einmalig'**
  String get redesignCreateRepeatOnce;

  /// redesign.create.repeatPick
  ///
  /// In de, this message translates to:
  /// **'Tage im Kalender wählen'**
  String get redesignCreateRepeatPick;

  /// redesign.create.repeatSkipHolidays
  ///
  /// In de, this message translates to:
  /// **'Ferien und Feiertage auslassen'**
  String get redesignCreateRepeatSkipHolidays;

  /// redesign.create.repeatUntil
  ///
  /// In de, this message translates to:
  /// **'Bis'**
  String get redesignCreateRepeatUntil;

  /// redesign.create.repeatWeekly
  ///
  /// In de, this message translates to:
  /// **'Jeden {weekday} bis {date}'**
  String redesignCreateRepeatWeekly(Object weekday, Object date);

  /// redesign.create.repeatWeeklyOption
  ///
  /// In de, this message translates to:
  /// **'Jede Woche'**
  String get redesignCreateRepeatWeeklyOption;

  /// redesign.create.songs
  ///
  /// In de, this message translates to:
  /// **'Werke'**
  String get redesignCreateSongs;

  /// redesign.create.songsCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Werk} other {{count} Werke}}'**
  String redesignCreateSongsCount(num count);

  /// redesign.create.songsNone
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get redesignCreateSongsNone;

  /// redesign.create.start
  ///
  /// In de, this message translates to:
  /// **'Beginn'**
  String get redesignCreateStart;

  /// redesign.create.submit
  ///
  /// In de, this message translates to:
  /// **'Anlegen'**
  String get redesignCreateSubmit;

  /// redesign.create.submitMany
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {Termin anlegen} other {{count} Termine anlegen}}'**
  String redesignCreateSubmitMany(num count);

  /// redesign.create.summaryBiweekly
  ///
  /// In de, this message translates to:
  /// **'alle 2 Wochen am {weekday}'**
  String redesignCreateSummaryBiweekly(Object weekday);

  /// redesign.create.summaryCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {Es wird 1 Termin angelegt} other {Es werden {count} Termine angelegt}}'**
  String redesignCreateSummaryCount(num count);

  /// redesign.create.summaryRange
  ///
  /// In de, this message translates to:
  /// **'{from} bis {until}'**
  String redesignCreateSummaryRange(Object from, Object until);

  /// redesign.create.summaryWeekly
  ///
  /// In de, this message translates to:
  /// **'jeden {weekday}'**
  String redesignCreateSummaryWeekly(Object weekday);

  /// redesign.create.template
  ///
  /// In de, this message translates to:
  /// **'Vorlage'**
  String get redesignCreateTemplate;

  /// redesign.create.templateHint
  ///
  /// In de, this message translates to:
  /// **'Füllt Art, Titel, Zeit und Ort vor. Alles bleibt änderbar.'**
  String get redesignCreateTemplateHint;

  /// redesign.create.time
  ///
  /// In de, this message translates to:
  /// **'Zeit'**
  String get redesignCreateTime;

  /// redesign.create.title
  ///
  /// In de, this message translates to:
  /// **'Neuer Termin'**
  String get redesignCreateTitle;

  /// redesign.create.titleLabel
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get redesignCreateTitleLabel;

  /// redesign.create.type
  ///
  /// In de, this message translates to:
  /// **'Art'**
  String get redesignCreateType;

  /// redesign.event.allDone
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Person als anwesend} other {{count} Personen als anwesend}}'**
  String redesignEventAllDone(num count);

  /// redesign.event.allOpenPresent
  ///
  /// In de, this message translates to:
  /// **'Alle Offenen als anwesend'**
  String get redesignEventAllOpenPresent;

  /// redesign.event.answers
  ///
  /// In de, this message translates to:
  /// **'Rückmeldungen'**
  String get redesignEventAnswers;

  /// redesign.event.busyLeave
  ///
  /// In de, this message translates to:
  /// **'Bitte warte, bis alles gespeichert ist.'**
  String get redesignEventBusyLeave;

  /// redesign.event.countAbsent
  ///
  /// In de, this message translates to:
  /// **'{count} fehlt'**
  String redesignEventCountAbsent(Object count);

  /// redesign.event.countExcused
  ///
  /// In de, this message translates to:
  /// **'{count} entsch.'**
  String redesignEventCountExcused(Object count);

  /// redesign.event.countLate
  ///
  /// In de, this message translates to:
  /// **'{count} später'**
  String redesignEventCountLate(Object count);

  /// redesign.event.countNoAnswer
  ///
  /// In de, this message translates to:
  /// **'{count} ohne Antwort'**
  String redesignEventCountNoAnswer(Object count);

  /// redesign.event.countOpen
  ///
  /// In de, this message translates to:
  /// **'{count} offen'**
  String redesignEventCountOpen(Object count);

  /// redesign.event.countPresent
  ///
  /// In de, this message translates to:
  /// **'{count} da'**
  String redesignEventCountPresent(Object count);

  /// redesign.event.delete
  ///
  /// In de, this message translates to:
  /// **'Termin löschen'**
  String get redesignEventDelete;

  /// redesign.event.deleted
  ///
  /// In de, this message translates to:
  /// **'Termin gelöscht'**
  String get redesignEventDeleted;

  /// redesign.event.details
  ///
  /// In de, this message translates to:
  /// **'Alle Details'**
  String get redesignEventDetails;

  /// redesign.event.invited
  ///
  /// In de, this message translates to:
  /// **'{count} eingeladen'**
  String redesignEventInvited(Object count);

  /// redesign.event.keyboardHint
  ///
  /// In de, this message translates to:
  /// **'Tastatur: A anwesend · V verspätet · F fehlt · ↑↓ nächste Person · ⌘Z oder Strg+Z rückgängig'**
  String get redesignEventKeyboardHint;

  /// redesign.event.more
  ///
  /// In de, this message translates to:
  /// **'Alle Details und Bearbeiten'**
  String get redesignEventMore;

  /// redesign.event.moreHint
  ///
  /// In de, this message translates to:
  /// **'Ablauf, Checkliste, Werke und Notizen'**
  String get redesignEventMoreHint;

  /// redesign.event.moreStatus
  ///
  /// In de, this message translates to:
  /// **'Weitere Status und Notiz für {name}'**
  String redesignEventMoreStatus(Object name);

  /// redesign.event.neutralHint
  ///
  /// In de, this message translates to:
  /// **'zählt nicht'**
  String get redesignEventNeutralHint;

  /// redesign.event.noMatch
  ///
  /// In de, this message translates to:
  /// **'Niemand passt zur Suche.'**
  String get redesignEventNoMatch;

  /// redesign.event.noPersons
  ///
  /// In de, this message translates to:
  /// **'Für diesen Termin sind noch keine Personen eingetragen.'**
  String get redesignEventNoPersons;

  /// redesign.event.notFound
  ///
  /// In de, this message translates to:
  /// **'Dieser Termin wurde nicht gefunden.'**
  String get redesignEventNotFound;

  /// redesign.event.note
  ///
  /// In de, this message translates to:
  /// **'Notiz für diesen Termin'**
  String get redesignEventNote;

  /// redesign.event.noteHint
  ///
  /// In de, this message translates to:
  /// **'z. B. Grund oder Uhrzeit'**
  String get redesignEventNoteHint;

  /// redesign.event.plan
  ///
  /// In de, this message translates to:
  /// **'Ablauf ansehen'**
  String get redesignEventPlan;

  /// redesign.event.planHint
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan, am Termin-Tag live'**
  String get redesignEventPlanHint;

  /// redesign.event.registerEmpty
  ///
  /// In de, this message translates to:
  /// **'{group}: 0 von {count} da.'**
  String redesignEventRegisterEmpty(Object group, Object count);

  /// redesign.event.registerNames
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{names} hat abgesagt.} other {{names} haben abgesagt.}}'**
  String redesignEventRegisterNames(num count, Object names);

  /// redesign.event.saving
  ///
  /// In de, this message translates to:
  /// **'Wird gespeichert …'**
  String get redesignEventSaving;

  /// redesign.event.search
  ///
  /// In de, this message translates to:
  /// **'Person suchen'**
  String get redesignEventSearch;

  /// redesign.event.searchClose
  ///
  /// In de, this message translates to:
  /// **'Suche schließen'**
  String get redesignEventSearchClose;

  /// redesign.event.searchHint
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get redesignEventSearchHint;

  /// redesign.event.signouts
  ///
  /// In de, this message translates to:
  /// **'Abmeldungen'**
  String get redesignEventSignouts;

  /// redesign.event.status
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get redesignEventStatus;

  /// redesign.event.tabOverview
  ///
  /// In de, this message translates to:
  /// **'Überblick'**
  String get redesignEventTabOverview;

  /// redesign.event.tabRecord
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit'**
  String get redesignEventTabRecord;

  /// redesign.event.toastReset
  ///
  /// In de, this message translates to:
  /// **'{name}: zurückgesetzt'**
  String redesignEventToastReset(Object name);

  /// redesign.event.toastSet
  ///
  /// In de, this message translates to:
  /// **'{name}: {status}'**
  String redesignEventToastSet(Object name, Object status);

  /// redesign.event.undo
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get redesignEventUndo;

  /// redesign.event.undone
  ///
  /// In de, this message translates to:
  /// **'Rückgängig gemacht'**
  String get redesignEventUndone;

  /// redesign.events.absent
  ///
  /// In de, this message translates to:
  /// **'Abwesend …'**
  String get redesignEventsAbsent;

  /// redesign.events.createFirst
  ///
  /// In de, this message translates to:
  /// **'Ersten Termin anlegen'**
  String get redesignEventsCreateFirst;

  /// redesign.events.empty
  ///
  /// In de, this message translates to:
  /// **'Noch keine Termine. Leg die erste Probe an.'**
  String get redesignEventsEmpty;

  /// redesign.events.lastWeek
  ///
  /// In de, this message translates to:
  /// **'Letzte 7 Tage'**
  String get redesignEventsLastWeek;

  /// redesign.events.new
  ///
  /// In de, this message translates to:
  /// **'Neuer Termin'**
  String get redesignEventsNew;

  /// redesign.events.no
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get redesignEventsNo;

  /// redesign.events.noMatch
  ///
  /// In de, this message translates to:
  /// **'Keine Termine passen zur Suche.'**
  String get redesignEventsNoMatch;

  /// redesign.events.noPast
  ///
  /// In de, this message translates to:
  /// **'Noch keine vergangenen Termine.'**
  String get redesignEventsNoPast;

  /// redesign.events.past
  ///
  /// In de, this message translates to:
  /// **'Vergangen'**
  String get redesignEventsPast;

  /// redesign.events.pastAverage
  ///
  /// In de, this message translates to:
  /// **'Vergangen · Ø {percent} %'**
  String redesignEventsPastAverage(Object percent);

  /// redesign.events.pastOwn
  ///
  /// In de, this message translates to:
  /// **'Vergangen · {percent} % da'**
  String redesignEventsPastOwn(Object percent);

  /// redesign.events.percentPresent
  ///
  /// In de, this message translates to:
  /// **'{percent} % anwesend'**
  String redesignEventsPercentPresent(Object percent);

  /// redesign.events.search
  ///
  /// In de, this message translates to:
  /// **'Termine durchsuchen'**
  String get redesignEventsSearch;

  /// redesign.events.searchClose
  ///
  /// In de, this message translates to:
  /// **'Suche schließen'**
  String get redesignEventsSearchClose;

  /// redesign.events.searchHint
  ///
  /// In de, this message translates to:
  /// **'Titel oder Ort'**
  String get redesignEventsSearchHint;

  /// redesign.events.showAll
  ///
  /// In de, this message translates to:
  /// **'Wieder alle Termine zeigen'**
  String get redesignEventsShowAll;

  /// redesign.events.upcoming
  ///
  /// In de, this message translates to:
  /// **'Kommend'**
  String get redesignEventsUpcoming;

  /// redesign.events.waiting
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Termin wartet auf deine Antwort} other {{count} Termine warten auf deine Antwort}}'**
  String redesignEventsWaiting(num count);

  /// redesign.events.yes
  ///
  /// In de, this message translates to:
  /// **'Dabei'**
  String get redesignEventsYes;

  /// redesign.files.actions
  ///
  /// In de, this message translates to:
  /// **'Aktionen für {name}'**
  String redesignFilesActions(Object name);

  /// redesign.files.colName
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get redesignFilesColName;

  /// redesign.files.colPart
  ///
  /// In de, this message translates to:
  /// **'Stimme'**
  String get redesignFilesColPart;

  /// redesign.files.colType
  ///
  /// In de, this message translates to:
  /// **'Typ'**
  String get redesignFilesColType;

  /// redesign.files.conflictMessage
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {Für 1 Datei gibt es schon eine Datei mit gleichem Namen oder für dieselbe Stimme:} other {Für {count} Dateien gibt es schon eine Datei mit gleichem Namen oder für dieselbe Stimme:}}'**
  String redesignFilesConflictMessage(num count);

  /// redesign.files.conflictTitle
  ///
  /// In de, this message translates to:
  /// **'Schon vorhanden'**
  String get redesignFilesConflictTitle;

  /// redesign.files.delete
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get redesignFilesDelete;

  /// redesign.files.deletedMany
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Datei gelöscht} other {{count} Dateien gelöscht}}'**
  String redesignFilesDeletedMany(num count);

  /// redesign.files.deletedOne
  ///
  /// In de, this message translates to:
  /// **'„{name}“ gelöscht'**
  String redesignFilesDeletedOne(Object name);

  /// redesign.files.dismiss
  ///
  /// In de, this message translates to:
  /// **'Ausblenden'**
  String get redesignFilesDismiss;

  /// redesign.files.done
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get redesignFilesDone;

  /// redesign.files.download
  ///
  /// In de, this message translates to:
  /// **'Herunterladen'**
  String get redesignFilesDownload;

  /// redesign.files.downloadAll
  ///
  /// In de, this message translates to:
  /// **'Alle als ZIP'**
  String get redesignFilesDownloadAll;

  /// redesign.files.downloadZip
  ///
  /// In de, this message translates to:
  /// **'Als ZIP laden'**
  String get redesignFilesDownloadZip;

  /// redesign.files.dropHint
  ///
  /// In de, this message translates to:
  /// **'Dateien hierher ziehen oder „Hochladen“ wählen.'**
  String get redesignFilesDropHint;

  /// redesign.files.dropOverlay
  ///
  /// In de, this message translates to:
  /// **'Loslassen, um sie zu „{name}“ hochzuladen'**
  String redesignFilesDropOverlay(Object name);

  /// redesign.files.failed
  ///
  /// In de, this message translates to:
  /// **'Fehlgeschlagen'**
  String get redesignFilesFailed;

  /// redesign.files.keepBoth
  ///
  /// In de, this message translates to:
  /// **'Beide behalten'**
  String get redesignFilesKeepBoth;

  /// redesign.files.open
  ///
  /// In de, this message translates to:
  /// **'Öffnen'**
  String get redesignFilesOpen;

  /// redesign.files.otherCategory
  ///
  /// In de, this message translates to:
  /// **'Sonstige …'**
  String get redesignFilesOtherCategory;

  /// redesign.files.pickHint
  ///
  /// In de, this message translates to:
  /// **'Klicken, um Dateien auszuwählen.'**
  String get redesignFilesPickHint;

  /// redesign.files.queueDone
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Datei hochgeladen} other {{count} Dateien hochgeladen}}'**
  String redesignFilesQueueDone(num count);

  /// redesign.files.queueTitle
  ///
  /// In de, this message translates to:
  /// **'Hochladen: {done} von {total}'**
  String redesignFilesQueueTitle(Object done, Object total);

  /// redesign.files.rename
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get redesignFilesRename;

  /// redesign.files.replace
  ///
  /// In de, this message translates to:
  /// **'Ersetzen'**
  String get redesignFilesReplace;

  /// redesign.files.restored
  ///
  /// In de, this message translates to:
  /// **'Wiederhergestellt'**
  String get redesignFilesRestored;

  /// redesign.files.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Speichern fehlgeschlagen: {error}'**
  String redesignFilesSaveFailed(Object error);

  /// redesign.files.selectAll
  ///
  /// In de, this message translates to:
  /// **'Alle auswählen'**
  String get redesignFilesSelectAll;

  /// redesign.files.selected
  ///
  /// In de, this message translates to:
  /// **'{count} ausgewählt'**
  String redesignFilesSelected(Object count);

  /// redesign.files.shortcuts
  ///
  /// In de, this message translates to:
  /// **'Tastenkürzel'**
  String get redesignFilesShortcuts;

  /// redesign.files.shortcutsHelp
  ///
  /// In de, this message translates to:
  /// **'↑ ↓ auswählen · Umschalt+↑↓ mehrere · Enter öffnen · Leertaste Vorschau/Abspielen · Entf löschen · {mod}+U hochladen · {mod}+A alle · {mod}+D herunterladen · {mod}+Z rückgängig · F2 umbenennen'**
  String redesignFilesShortcutsHelp(Object mod);

  /// redesign.files.title
  ///
  /// In de, this message translates to:
  /// **'Dateien'**
  String get redesignFilesTitle;

  /// redesign.files.upload
  ///
  /// In de, this message translates to:
  /// **'Hochladen'**
  String get redesignFilesUpload;

  /// redesign.files.uploading
  ///
  /// In de, this message translates to:
  /// **'Lädt hoch …'**
  String get redesignFilesUploading;

  /// redesign.files.waiting
  ///
  /// In de, this message translates to:
  /// **'Wartet'**
  String get redesignFilesWaiting;

  /// redesign.files.zipPreparing
  ///
  /// In de, this message translates to:
  /// **'ZIP wird erstellt …'**
  String get redesignFilesZipPreparing;

  /// redesign.groups.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Deine Gruppen konnten nicht geladen werden.'**
  String get redesignGroupsLoadFailed;

  /// redesign.groups.manage
  ///
  /// In de, this message translates to:
  /// **'Gruppen verwalten'**
  String get redesignGroupsManage;

  /// redesign.groups.switchFailed
  ///
  /// In de, this message translates to:
  /// **'Wechsel fehlgeschlagen. Bitte versuche es erneut.'**
  String get redesignGroupsSwitchFailed;

  /// redesign.groups.switchHint
  ///
  /// In de, this message translates to:
  /// **'Gruppe: {name}. Tippen zum Wechseln'**
  String redesignGroupsSwitchHint(Object name);

  /// redesign.groups.title
  ///
  /// In de, this message translates to:
  /// **'Gruppe wechseln'**
  String get redesignGroupsTitle;

  /// redesign.manage.announcementsHint
  ///
  /// In de, this message translates to:
  /// **'Gesendete Mitteilungen ansehen'**
  String get redesignManageAnnouncementsHint;

  /// redesign.manage.areaCommunication
  ///
  /// In de, this message translates to:
  /// **'Kommunikation'**
  String get redesignManageAreaCommunication;

  /// redesign.manage.areaData
  ///
  /// In de, this message translates to:
  /// **'Auswertung & Daten'**
  String get redesignManageAreaData;

  /// redesign.manage.areaEvents
  ///
  /// In de, this message translates to:
  /// **'Termine & Planung'**
  String get redesignManageAreaEvents;

  /// redesign.manage.areaGroup
  ///
  /// In de, this message translates to:
  /// **'Gruppe'**
  String get redesignManageAreaGroup;

  /// redesign.manage.areaMembers
  ///
  /// In de, this message translates to:
  /// **'Mitglieder, Register & Rollen'**
  String get redesignManageAreaMembers;

  /// redesign.manage.areaWorks
  ///
  /// In de, this message translates to:
  /// **'Werke & Dateien'**
  String get redesignManageAreaWorks;

  /// redesign.manage.classic
  ///
  /// In de, this message translates to:
  /// **'Alle Einstellungen (bisherige Ansicht)'**
  String get redesignManageClassic;

  /// redesign.manage.extraFieldsHint
  ///
  /// In de, this message translates to:
  /// **'Eigene Felder für Personen und Werke'**
  String get redesignManageExtraFieldsHint;

  /// redesign.manage.footer
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {Der bisherige Eintrag steckt in diesen Bereichen und ist über die Suche direkt erreichbar.} other {Alle {count} bisherigen Einträge stecken in diesen Bereichen und sind über die Suche direkt erreichbar.}}'**
  String redesignManageFooter(num count);

  /// redesign.manage.generalHint
  ///
  /// In de, this message translates to:
  /// **'Name, Saison, Gründe, Anmeldung'**
  String get redesignManageGeneralHint;

  /// redesign.manage.generalTitle
  ///
  /// In de, this message translates to:
  /// **'Allgemeine Einstellungen'**
  String get redesignManageGeneralTitle;

  /// redesign.manage.missingHint
  ///
  /// In de, this message translates to:
  /// **'Mitglieder mit E-Mail, aber ohne Zugang'**
  String get redesignManageMissingHint;

  /// redesign.manage.noMatch
  ///
  /// In de, this message translates to:
  /// **'Keine Einstellung passt zur Suche.'**
  String get redesignManageNoMatch;

  /// redesign.manage.pending
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Person wartet auf Freigabe} other {{count} Personen warten auf Freigabe}}'**
  String redesignManagePending(num count);

  /// redesign.manage.pendingTitle
  ///
  /// In de, this message translates to:
  /// **'Freigaben'**
  String get redesignManagePendingTitle;

  /// redesign.manage.recent
  ///
  /// In de, this message translates to:
  /// **'Zuletzt geöffnet'**
  String get redesignManageRecent;

  /// redesign.manage.search
  ///
  /// In de, this message translates to:
  /// **'Einstellung suchen'**
  String get redesignManageSearch;

  /// redesign.manage.searchLabel
  ///
  /// In de, this message translates to:
  /// **'Verwaltung durchsuchen'**
  String get redesignManageSearchLabel;

  /// redesign.me.absence
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit eintragen'**
  String get redesignMeAbsence;

  /// redesign.me.account
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get redesignMeAccount;

  /// redesign.me.admin
  ///
  /// In de, this message translates to:
  /// **'Verwaltung'**
  String get redesignMeAdmin;

  /// redesign.me.adminHint
  ///
  /// In de, this message translates to:
  /// **'Mitglieder, Termintypen, Rechte und mehr'**
  String get redesignMeAdminHint;

  /// redesign.me.allSettings
  ///
  /// In de, this message translates to:
  /// **'Alle Einstellungen'**
  String get redesignMeAllSettings;

  /// redesign.me.app
  ///
  /// In de, this message translates to:
  /// **'App'**
  String get redesignMeApp;

  /// redesign.me.beta
  ///
  /// In de, this message translates to:
  /// **'Neues Design (Beta)'**
  String get redesignMeBeta;

  /// redesign.me.betaHint
  ///
  /// In de, this message translates to:
  /// **'Nur auf diesem Gerät. Jederzeit wieder ausschaltbar.'**
  String get redesignMeBetaHint;

  /// redesign.me.calendar
  ///
  /// In de, this message translates to:
  /// **'Kalender abonnieren'**
  String get redesignMeCalendar;

  /// redesign.me.feedback
  ///
  /// In de, this message translates to:
  /// **'Feedback geben'**
  String get redesignMeFeedback;

  /// redesign.me.forMe
  ///
  /// In de, this message translates to:
  /// **'Für mich'**
  String get redesignMeForMe;

  /// redesign.me.groups
  ///
  /// In de, this message translates to:
  /// **'Meine Gruppen'**
  String get redesignMeGroups;

  /// redesign.me.groupsCount
  ///
  /// In de, this message translates to:
  /// **'{count} Gruppen'**
  String redesignMeGroupsCount(Object count);

  /// redesign.me.help
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get redesignMeHelp;

  /// redesign.me.logout
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get redesignMeLogout;

  /// redesign.me.notifications
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen'**
  String get redesignMeNotifications;

  /// redesign.me.whatsNew
  ///
  /// In de, this message translates to:
  /// **'Neu in dieser Version'**
  String get redesignMeWhatsNew;

  /// redesign.members.absentFrom
  ///
  /// In de, this message translates to:
  /// **'abwesend ab {date}'**
  String redesignMembersAbsentFrom(Object date);

  /// redesign.members.absentUntil
  ///
  /// In de, this message translates to:
  /// **'abwesend bis {date}'**
  String redesignMembersAbsentUntil(Object date);

  /// redesign.members.active
  ///
  /// In de, this message translates to:
  /// **'Aktiv · {count}'**
  String redesignMembersActive(Object count);

  /// redesign.members.add
  ///
  /// In de, this message translates to:
  /// **'Person hinzufügen'**
  String get redesignMembersAdd;

  /// redesign.members.average
  ///
  /// In de, this message translates to:
  /// **'Ø {percent} %'**
  String redesignMembersAverage(Object percent);

  /// redesign.members.birthdayIn
  ///
  /// In de, this message translates to:
  /// **'Geburtstag in {count} Tagen'**
  String redesignMembersBirthdayIn(Object count);

  /// redesign.members.birthdayToday
  ///
  /// In de, this message translates to:
  /// **'Geburtstag heute'**
  String get redesignMembersBirthdayToday;

  /// redesign.members.birthdayTomorrow
  ///
  /// In de, this message translates to:
  /// **'Geburtstag morgen'**
  String get redesignMembersBirthdayTomorrow;

  /// redesign.members.empty
  ///
  /// In de, this message translates to:
  /// **'Noch keine Mitglieder.'**
  String get redesignMembersEmpty;

  /// redesign.members.emptyPaused
  ///
  /// In de, this message translates to:
  /// **'Niemand ist pausiert.'**
  String get redesignMembersEmptyPaused;

  /// redesign.members.emptyPending
  ///
  /// In de, this message translates to:
  /// **'Niemand wartet auf Freigabe.'**
  String get redesignMembersEmptyPending;

  /// redesign.members.leader
  ///
  /// In de, this message translates to:
  /// **'Stimmführung'**
  String get redesignMembersLeader;

  /// redesign.members.low
  ///
  /// In de, this message translates to:
  /// **'unter 50 %'**
  String get redesignMembersLow;

  /// redesign.members.noMatch
  ///
  /// In de, this message translates to:
  /// **'Niemand passt zur Suche.'**
  String get redesignMembersNoMatch;

  /// redesign.members.paused
  ///
  /// In de, this message translates to:
  /// **'Pausiert · {count}'**
  String redesignMembersPaused(Object count);

  /// redesign.members.pausedUntil
  ///
  /// In de, this message translates to:
  /// **'pausiert bis {date}'**
  String redesignMembersPausedUntil(Object date);

  /// redesign.members.pending
  ///
  /// In de, this message translates to:
  /// **'Wartet · {count}'**
  String redesignMembersPending(Object count);

  /// redesign.members.pendingHint
  ///
  /// In de, this message translates to:
  /// **'Tippe auf eine Person, um sie zu prüfen und freizugeben.'**
  String get redesignMembersPendingHint;

  /// redesign.members.percent
  ///
  /// In de, this message translates to:
  /// **'{percent} %'**
  String redesignMembersPercent(Object percent);

  /// redesign.members.search
  ///
  /// In de, this message translates to:
  /// **'Name, Instrument, Register'**
  String get redesignMembersSearch;

  /// redesign.members.searchLabel
  ///
  /// In de, this message translates to:
  /// **'Mitglieder suchen'**
  String get redesignMembersSearchLabel;

  /// redesign.members.section
  ///
  /// In de, this message translates to:
  /// **'{title} · {count}'**
  String redesignMembersSection(Object title, Object count);

  /// redesign.members.stats
  ///
  /// In de, this message translates to:
  /// **'Auswertung'**
  String get redesignMembersStats;

  /// redesign.notif.forMe
  ///
  /// In de, this message translates to:
  /// **'Für mich'**
  String get redesignNotifForMe;

  /// redesign.notif.groups
  ///
  /// In de, this message translates to:
  /// **'Gruppen'**
  String get redesignNotifGroups;

  /// redesign.notif.groupsHint
  ///
  /// In de, this message translates to:
  /// **'Jede Gruppe lässt sich einzeln stummschalten.'**
  String get redesignNotifGroupsHint;

  /// redesign.notif.how
  ///
  /// In de, this message translates to:
  /// **'Wie'**
  String get redesignNotifHow;

  /// redesign.notif.lead
  ///
  /// In de, this message translates to:
  /// **'Als Leitung'**
  String get redesignNotifLead;

  /// redesign.notif.telegram
  ///
  /// In de, this message translates to:
  /// **'Telegram'**
  String get redesignNotifTelegram;

  /// redesign.notif.telegramConnect
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get redesignNotifTelegramConnect;

  /// redesign.notif.telegramConnected
  ///
  /// In de, this message translates to:
  /// **'Verbunden'**
  String get redesignNotifTelegramConnected;

  /// redesign.notif.telegramDisconnect
  ///
  /// In de, this message translates to:
  /// **'Trennen'**
  String get redesignNotifTelegramDisconnect;

  /// redesign.own.infos
  ///
  /// In de, this message translates to:
  /// **'Infos zum Termin'**
  String get redesignOwnInfos;

  /// redesign.own.more
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get redesignOwnMore;

  /// redesign.own.notFound
  ///
  /// In de, this message translates to:
  /// **'Dieser Termin ist nicht mehr in deiner Liste.'**
  String get redesignOwnNotFound;

  /// redesign.own.route
  ///
  /// In de, this message translates to:
  /// **'Route'**
  String get redesignOwnRoute;

  /// redesign.person.absence
  ///
  /// In de, this message translates to:
  /// **'Abwesend'**
  String get redesignPersonAbsence;

  /// redesign.person.absenceRange
  ///
  /// In de, this message translates to:
  /// **'{from} bis {until}'**
  String redesignPersonAbsenceRange(Object from, Object until);

  /// redesign.person.allTermine
  ///
  /// In de, this message translates to:
  /// **'Alle Termine ansehen'**
  String get redesignPersonAllTermine;

  /// redesign.person.archive
  ///
  /// In de, this message translates to:
  /// **'Archivieren'**
  String get redesignPersonArchive;

  /// redesign.person.attendance
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit'**
  String get redesignPersonAttendance;

  /// redesign.person.birthday
  ///
  /// In de, this message translates to:
  /// **'Geburtstag'**
  String get redesignPersonBirthday;

  /// redesign.person.edit
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get redesignPersonEdit;

  /// redesign.person.history
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get redesignPersonHistory;

  /// redesign.person.inDays
  ///
  /// In de, this message translates to:
  /// **'in {count} Tagen'**
  String redesignPersonInDays(Object count);

  /// redesign.person.joined
  ///
  /// In de, this message translates to:
  /// **'Dabei seit'**
  String get redesignPersonJoined;

  /// redesign.person.lastTermine
  ///
  /// In de, this message translates to:
  /// **'Letzte {count} Termine, neuester rechts'**
  String redesignPersonLastTermine(Object count);

  /// redesign.person.noTermine
  ///
  /// In de, this message translates to:
  /// **'Noch keine vergangenen Termine.'**
  String get redesignPersonNoTermine;

  /// redesign.person.notFound
  ///
  /// In de, this message translates to:
  /// **'Diese Person gibt es hier nicht mehr.'**
  String get redesignPersonNotFound;

  /// redesign.person.notes
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get redesignPersonNotes;

  /// redesign.person.ofTermine
  ///
  /// In de, this message translates to:
  /// **'{attended} von {total} Terminen'**
  String redesignPersonOfTermine(Object attended, Object total);

  /// redesign.person.overall
  ///
  /// In de, this message translates to:
  /// **'Gesamt'**
  String get redesignPersonOverall;

  /// redesign.person.pause
  ///
  /// In de, this message translates to:
  /// **'Pausieren'**
  String get redesignPersonPause;

  /// redesign.person.paused
  ///
  /// In de, this message translates to:
  /// **'Pausiert'**
  String get redesignPersonPaused;

  /// redesign.person.pausedOpen
  ///
  /// In de, this message translates to:
  /// **'ohne Enddatum'**
  String get redesignPersonPausedOpen;

  /// redesign.person.pending
  ///
  /// In de, this message translates to:
  /// **'Wartet auf Freigabe.'**
  String get redesignPersonPending;

  /// redesign.person.percent
  ///
  /// In de, this message translates to:
  /// **'{percent} %'**
  String redesignPersonPercent(Object percent);

  /// redesign.person.resume
  ///
  /// In de, this message translates to:
  /// **'Wieder aktiv'**
  String get redesignPersonResume;

  /// redesign.person.review
  ///
  /// In de, this message translates to:
  /// **'Prüfen und freigeben'**
  String get redesignPersonReview;

  /// redesign.person.since
  ///
  /// In de, this message translates to:
  /// **'seit {year}'**
  String redesignPersonSince(Object year);

  /// redesign.person.sinceDate
  ///
  /// In de, this message translates to:
  /// **'seit {date}'**
  String redesignPersonSinceDate(Object date);

  /// redesign.person.today
  ///
  /// In de, this message translates to:
  /// **'heute'**
  String get redesignPersonToday;

  /// redesign.person.tomorrow
  ///
  /// In de, this message translates to:
  /// **'morgen'**
  String get redesignPersonTomorrow;

  /// redesign.pult.allOpen
  ///
  /// In de, this message translates to:
  /// **'Alle Offenen da'**
  String get redesignPultAllOpen;

  /// redesign.pult.back
  ///
  /// In de, this message translates to:
  /// **'Termin'**
  String get redesignPultBack;

  /// redesign.pult.done
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get redesignPultDone;

  /// redesign.pult.groupCount
  ///
  /// In de, this message translates to:
  /// **'{present} / {total} da'**
  String redesignPultGroupCount(Object present, Object total);

  /// redesign.pult.hint
  ///
  /// In de, this message translates to:
  /// **'Antippen = da · nochmal antippen = zurück · gedrückt halten = weitere Status'**
  String get redesignPultHint;

  /// redesign.pult.open
  ///
  /// In de, this message translates to:
  /// **'Pultmodus'**
  String get redesignPultOpen;

  /// redesign.pult.openHint
  ///
  /// In de, this message translates to:
  /// **'Große Kacheln zum Antippen, gut für das Tablet am Pult'**
  String get redesignPultOpenHint;

  /// redesign.pult.statusOpen
  ///
  /// In de, this message translates to:
  /// **'offen'**
  String get redesignPultStatusOpen;

  /// redesign.pult.title
  ///
  /// In de, this message translates to:
  /// **'{title} · Pultmodus'**
  String redesignPultTitle(Object title);

  /// redesign.signout.cannot
  ///
  /// In de, this message translates to:
  /// **'Ich kann nicht'**
  String get redesignSignoutCannot;

  /// redesign.signout.later
  ///
  /// In de, this message translates to:
  /// **'Ich komme später'**
  String get redesignSignoutLater;

  /// redesign.signout.other
  ///
  /// In de, this message translates to:
  /// **'Anderer Grund'**
  String get redesignSignoutOther;

  /// redesign.signout.otherHint
  ///
  /// In de, this message translates to:
  /// **'Kurz beschreiben (mindestens 5 Zeichen)'**
  String get redesignSignoutOtherHint;

  /// redesign.signout.privacy
  ///
  /// In de, this message translates to:
  /// **'Deinen Grund sieht nur die Leitung.'**
  String get redesignSignoutPrivacy;

  /// redesign.signout.reason
  ///
  /// In de, this message translates to:
  /// **'Grund'**
  String get redesignSignoutReason;

  /// redesign.signout.submit
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get redesignSignoutSubmit;

  /// redesign.signout.submitLate
  ///
  /// In de, this message translates to:
  /// **'Verspätung melden'**
  String get redesignSignoutSubmitLate;

  /// redesign.split.eventsEmpty
  ///
  /// In de, this message translates to:
  /// **'Wähle links einen Termin aus.'**
  String get redesignSplitEventsEmpty;

  /// redesign.split.membersEmpty
  ///
  /// In de, this message translates to:
  /// **'Wähle links eine Person aus.'**
  String get redesignSplitMembersEmpty;

  /// redesign.split.worksEmpty
  ///
  /// In de, this message translates to:
  /// **'Wähle links ein Werk aus.'**
  String get redesignSplitWorksEmpty;

  /// redesign.stats.avg
  ///
  /// In de, this message translates to:
  /// **'Ø Anwesenheit'**
  String get redesignStatsAvg;

  /// redesign.stats.bar
  ///
  /// In de, this message translates to:
  /// **'{date}: {percent} %'**
  String redesignStatsBar(Object date, Object percent);

  /// redesign.stats.empty
  ///
  /// In de, this message translates to:
  /// **'Im Zeitraum gibt es keine Termine.'**
  String get redesignStatsEmpty;

  /// redesign.stats.events
  ///
  /// In de, this message translates to:
  /// **'Termine'**
  String get redesignStatsEvents;

  /// redesign.stats.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Auswertung konnte nicht geladen werden.'**
  String get redesignStatsLoadFailed;

  /// redesign.stats.low
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Person unter 50 %} other {{count} Personen unter 50 %}}'**
  String redesignStatsLow(num count);

  /// redesign.stats.members
  ///
  /// In de, this message translates to:
  /// **'Aktive'**
  String get redesignStatsMembers;

  /// redesign.stats.perEvent
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit je Termin'**
  String get redesignStatsPerEvent;

  /// redesign.stats.perEventHint
  ///
  /// In de, this message translates to:
  /// **'Die letzten {count} Termine'**
  String redesignStatsPerEventHint(Object count);

  /// redesign.stats.perGroup
  ///
  /// In de, this message translates to:
  /// **'Je Register'**
  String get redesignStatsPerGroup;

  /// redesign.stats.range12m
  ///
  /// In de, this message translates to:
  /// **'12 Monate'**
  String get redesignStatsRange12m;

  /// redesign.stats.range3m
  ///
  /// In de, this message translates to:
  /// **'3 Monate'**
  String get redesignStatsRange3m;

  /// redesign.stats.rangeSeason
  ///
  /// In de, this message translates to:
  /// **'Saison'**
  String get redesignStatsRangeSeason;

  /// redesign.stats.title
  ///
  /// In de, this message translates to:
  /// **'Auswertung'**
  String get redesignStatsTitle;

  /// redesign.status.absent
  ///
  /// In de, this message translates to:
  /// **'Abwesend'**
  String get redesignStatusAbsent;

  /// redesign.status.excused
  ///
  /// In de, this message translates to:
  /// **'Entschuldigt'**
  String get redesignStatusExcused;

  /// redesign.status.late
  ///
  /// In de, this message translates to:
  /// **'Verspätet'**
  String get redesignStatusLate;

  /// redesign.status.later
  ///
  /// In de, this message translates to:
  /// **'Kommt später'**
  String get redesignStatusLater;

  /// redesign.status.open
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get redesignStatusOpen;

  /// redesign.status.yes
  ///
  /// In de, this message translates to:
  /// **'Zugesagt'**
  String get redesignStatusYes;

  /// redesign.tab.events
  ///
  /// In de, this message translates to:
  /// **'Termine'**
  String get redesignTabEvents;

  /// redesign.tab.me
  ///
  /// In de, this message translates to:
  /// **'Ich'**
  String get redesignTabMe;

  /// redesign.tab.members
  ///
  /// In de, this message translates to:
  /// **'Mitglieder'**
  String get redesignTabMembers;

  /// redesign.tab.today
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get redesignTabToday;

  /// redesign.tab.works
  ///
  /// In de, this message translates to:
  /// **'Werke'**
  String get redesignTabWorks;

  /// redesign.today.allEvents
  ///
  /// In de, this message translates to:
  /// **'Alle Termine'**
  String get redesignTodayAllEvents;

  /// redesign.today.answerChildren
  ///
  /// In de, this message translates to:
  /// **'Zu- und absagen'**
  String get redesignTodayAnswerChildren;

  /// redesign.today.answered
  ///
  /// In de, this message translates to:
  /// **'Alle geantwortet'**
  String get redesignTodayAnswered;

  /// redesign.today.answeredLater
  ///
  /// In de, this message translates to:
  /// **'Du hast gemeldet, dass du später kommst.'**
  String get redesignTodayAnsweredLater;

  /// redesign.today.answeredNo
  ///
  /// In de, this message translates to:
  /// **'Du bist abgemeldet.'**
  String get redesignTodayAnsweredNo;

  /// redesign.today.answeredYes
  ///
  /// In de, this message translates to:
  /// **'Schön, du bist dabei.'**
  String get redesignTodayAnsweredYes;

  /// redesign.today.attention
  ///
  /// In de, this message translates to:
  /// **'Braucht deine Aufmerksamkeit'**
  String get redesignTodayAttention;

  /// redesign.today.birthday
  ///
  /// In de, this message translates to:
  /// **'Geburtstag: {name} ({day})'**
  String redesignTodayBirthday(Object name, Object day);

  /// redesign.today.birthdayMore
  ///
  /// In de, this message translates to:
  /// **'Geburtstag: {name} ({day}) +{count}'**
  String redesignTodayBirthdayMore(Object name, Object day, Object count);

  /// redesign.today.countAbsent
  ///
  /// In de, this message translates to:
  /// **'{count} abwesend'**
  String redesignTodayCountAbsent(Object count);

  /// redesign.today.countExcused
  ///
  /// In de, this message translates to:
  /// **'{count} entschuldigt'**
  String redesignTodayCountExcused(Object count);

  /// redesign.today.countLater
  ///
  /// In de, this message translates to:
  /// **'{count} später'**
  String redesignTodayCountLater(Object count);

  /// redesign.today.countOpen
  ///
  /// In de, this message translates to:
  /// **'{count} offen'**
  String redesignTodayCountOpen(Object count);

  /// redesign.today.countYes
  ///
  /// In de, this message translates to:
  /// **'{count} zugesagt'**
  String redesignTodayCountYes(Object count);

  /// redesign.today.critical
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Mitglied fehlt oft} other {{count} Mitglieder fehlen oft}}'**
  String redesignTodayCritical(num count);

  /// redesign.today.criticalHint
  ///
  /// In de, this message translates to:
  /// **'Unter der Anwesenheitsgrenze'**
  String get redesignTodayCriticalHint;

  /// redesign.today.dayToday
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get redesignTodayDayToday;

  /// redesign.today.dayTomorrow
  ///
  /// In de, this message translates to:
  /// **'Morgen'**
  String get redesignTodayDayTomorrow;

  /// redesign.today.dutyQuestion
  ///
  /// In de, this message translates to:
  /// **'Du bist eingeteilt. Bestätigst du?'**
  String get redesignTodayDutyQuestion;

  /// redesign.today.greeting
  ///
  /// In de, this message translates to:
  /// **'Hallo {name}'**
  String redesignTodayGreeting(Object name);

  /// redesign.today.inHours
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {in {count} Std.} other {in {count} Std.}}'**
  String redesignTodayInHours(num count);

  /// redesign.today.inMinutes
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {in {count} Min.} other {in {count} Min.}}'**
  String redesignTodayInMinutes(num count);

  /// redesign.today.later
  ///
  /// In de, this message translates to:
  /// **'Ich komme später …'**
  String get redesignTodayLater;

  /// redesign.today.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Das konnte nicht geladen werden.'**
  String get redesignTodayLoadFailed;

  /// redesign.today.loading
  ///
  /// In de, this message translates to:
  /// **'Wird geladen …'**
  String get redesignTodayLoading;

  /// redesign.today.more
  ///
  /// In de, this message translates to:
  /// **'Mehr zum Termin'**
  String get redesignTodayMore;

  /// redesign.today.mySection
  ///
  /// In de, this message translates to:
  /// **'Meine Stimme'**
  String get redesignTodayMySection;

  /// redesign.today.mySectionHint
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit deiner Stimmgruppe'**
  String get redesignTodayMySectionHint;

  /// redesign.today.nextEvent
  ///
  /// In de, this message translates to:
  /// **'Nächster Termin'**
  String get redesignTodayNextEvent;

  /// redesign.today.no
  ///
  /// In de, this message translates to:
  /// **'Kann nicht'**
  String get redesignTodayNo;

  /// redesign.today.noAfterAll
  ///
  /// In de, this message translates to:
  /// **'Doch absagen'**
  String get redesignTodayNoAfterAll;

  /// redesign.today.noChildren
  ///
  /// In de, this message translates to:
  /// **'Es sind noch keine Kinder mit deinem Konto verknüpft.'**
  String get redesignTodayNoChildren;

  /// redesign.today.noDone
  ///
  /// In de, this message translates to:
  /// **'Abgemeldet'**
  String get redesignTodayNoDone;

  /// redesign.today.noMember
  ///
  /// In de, this message translates to:
  /// **'Du bist in dieser Gruppe nicht als Mitglied eingetragen.'**
  String get redesignTodayNoMember;

  /// redesign.today.noUpcoming
  ///
  /// In de, this message translates to:
  /// **'Gerade stehen keine Termine an.'**
  String get redesignTodayNoUpcoming;

  /// redesign.today.notPart
  ///
  /// In de, this message translates to:
  /// **'Du bist für diesen Termin nicht eingeteilt.'**
  String get redesignTodayNotPart;

  /// redesign.today.nothingElse
  ///
  /// In de, this message translates to:
  /// **'Danach ist noch nichts geplant.'**
  String get redesignTodayNothingElse;

  /// redesign.today.notifications
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen'**
  String get redesignTodayNotifications;

  /// redesign.today.notificationsUnread
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {Benachrichtigungen, {count} ungelesen} other {Benachrichtigungen, {count} ungelesen}}'**
  String redesignTodayNotificationsUnread(num count);

  /// redesign.today.otherReason
  ///
  /// In de, this message translates to:
  /// **'Anderer Grund …'**
  String get redesignTodayOtherReason;

  /// redesign.today.pending
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} neue Anmeldung} other {{count} neue Anmeldungen}}'**
  String redesignTodayPending(num count);

  /// redesign.today.pendingHint
  ///
  /// In de, this message translates to:
  /// **'Prüfen und freischalten'**
  String get redesignTodayPendingHint;

  /// redesign.today.question
  ///
  /// In de, this message translates to:
  /// **'Bist du dabei?'**
  String get redesignTodayQuestion;

  /// redesign.today.record
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit erfassen'**
  String get redesignTodayRecord;

  /// redesign.today.running
  ///
  /// In de, this message translates to:
  /// **'läuft'**
  String get redesignTodayRunning;

  /// redesign.today.signouts
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Abmeldung für den nächsten Termin} other {{count} Abmeldungen für den nächsten Termin}}'**
  String redesignTodaySignouts(num count);

  /// redesign.today.signoutsHint
  ///
  /// In de, this message translates to:
  /// **'Gründe ansehen'**
  String get redesignTodaySignoutsHint;

  /// redesign.today.thisWeek
  ///
  /// In de, this message translates to:
  /// **'Diese Woche'**
  String get redesignTodayThisWeek;

  /// redesign.today.upNext
  ///
  /// In de, this message translates to:
  /// **'Als Nächstes'**
  String get redesignTodayUpNext;

  /// redesign.today.weekEmpty
  ///
  /// In de, this message translates to:
  /// **'Diese Woche kommt sonst nichts.'**
  String get redesignTodayWeekEmpty;

  /// redesign.today.whyNot
  ///
  /// In de, this message translates to:
  /// **'Warum kannst du nicht?'**
  String get redesignTodayWhyNot;

  /// redesign.today.yes
  ///
  /// In de, this message translates to:
  /// **'Bin dabei'**
  String get redesignTodayYes;

  /// redesign.today.yesAfterAll
  ///
  /// In de, this message translates to:
  /// **'Doch dabei'**
  String get redesignTodayYesAfterAll;

  /// redesign.today.yesDone
  ///
  /// In de, this message translates to:
  /// **'Zugesagt'**
  String get redesignTodayYesDone;

  /// redesign.today.yourAnswer
  ///
  /// In de, this message translates to:
  /// **'Deine Zusage'**
  String get redesignTodayYourAnswer;

  /// redesign.work.allFiles
  ///
  /// In de, this message translates to:
  /// **'Alle Dateien'**
  String get redesignWorkAllFiles;

  /// redesign.work.allParts
  ///
  /// In de, this message translates to:
  /// **'Alle Stimmen'**
  String get redesignWorkAllParts;

  /// redesign.work.edit
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get redesignWorkEdit;

  /// redesign.work.fileCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {1 Datei} other {{count} Dateien}}'**
  String redesignWorkFileCount(num count);

  /// redesign.work.lastPlayed
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gespielt'**
  String get redesignWorkLastPlayed;

  /// redesign.work.lastSung
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gesungen'**
  String get redesignWorkLastSung;

  /// redesign.work.link
  ///
  /// In de, this message translates to:
  /// **'Link'**
  String get redesignWorkLink;

  /// redesign.work.lyrics
  ///
  /// In de, this message translates to:
  /// **'Liedtext'**
  String get redesignWorkLyrics;

  /// redesign.work.never
  ///
  /// In de, this message translates to:
  /// **'Noch nie'**
  String get redesignWorkNever;

  /// redesign.work.noFiles
  ///
  /// In de, this message translates to:
  /// **'Zu diesem Werk gibt es noch keine Dateien.'**
  String get redesignWorkNoFiles;

  /// redesign.work.noPart
  ///
  /// In de, this message translates to:
  /// **'Für deine Stimme gibt es noch keine Noten.'**
  String get redesignWorkNoPart;

  /// redesign.work.normalSpeed
  ///
  /// In de, this message translates to:
  /// **'Normal abspielen'**
  String get redesignWorkNormalSpeed;

  /// redesign.work.notFound
  ///
  /// In de, this message translates to:
  /// **'Dieses Werk gibt es hier nicht mehr.'**
  String get redesignWorkNotFound;

  /// redesign.work.number
  ///
  /// In de, this message translates to:
  /// **'Nr. {number}'**
  String redesignWorkNumber(Object number);

  /// redesign.work.open
  ///
  /// In de, this message translates to:
  /// **'Öffnen'**
  String get redesignWorkOpen;

  /// redesign.work.pause
  ///
  /// In de, this message translates to:
  /// **'Anhalten'**
  String get redesignWorkPause;

  /// redesign.work.planned
  ///
  /// In de, this message translates to:
  /// **'Geplant'**
  String get redesignWorkPlanned;

  /// redesign.work.play
  ///
  /// In de, this message translates to:
  /// **'Abspielen'**
  String get redesignWorkPlay;

  /// redesign.work.recording
  ///
  /// In de, this message translates to:
  /// **'Aufnahme'**
  String get redesignWorkRecording;

  /// redesign.work.recordingFrom
  ///
  /// In de, this message translates to:
  /// **'Aufnahme vom {date}'**
  String redesignWorkRecordingFrom(Object date);

  /// redesign.work.score
  ///
  /// In de, this message translates to:
  /// **'Partitur'**
  String get redesignWorkScore;

  /// redesign.work.share
  ///
  /// In de, this message translates to:
  /// **'Teilen'**
  String get redesignWorkShare;

  /// redesign.work.shareFile
  ///
  /// In de, this message translates to:
  /// **'{name} teilen'**
  String redesignWorkShareFile(Object name);

  /// redesign.work.slower
  ///
  /// In de, this message translates to:
  /// **'Langsamer abspielen'**
  String get redesignWorkSlower;

  /// redesign.work.yourPart
  ///
  /// In de, this message translates to:
  /// **'Deine Stimme'**
  String get redesignWorkYourPart;

  /// redesign.works.add
  ///
  /// In de, this message translates to:
  /// **'Werk hinzufügen'**
  String get redesignWorksAdd;

  /// redesign.works.all
  ///
  /// In de, this message translates to:
  /// **'Alle · {count}'**
  String redesignWorksAll(Object count);

  /// redesign.works.audio
  ///
  /// In de, this message translates to:
  /// **'Audio'**
  String get redesignWorksAudio;

  /// redesign.works.current
  ///
  /// In de, this message translates to:
  /// **'Gerade geprobt'**
  String get redesignWorksCurrent;

  /// redesign.works.empty
  ///
  /// In de, this message translates to:
  /// **'Noch keine Werke.'**
  String get redesignWorksEmpty;

  /// redesign.works.files
  ///
  /// In de, this message translates to:
  /// **'Dateien'**
  String get redesignWorksFiles;

  /// redesign.works.filesLabel
  ///
  /// In de, this message translates to:
  /// **'Dateien der Gruppe'**
  String get redesignWorksFilesLabel;

  /// redesign.works.filter
  ///
  /// In de, this message translates to:
  /// **'Filter & Ansicht'**
  String get redesignWorksFilter;

  /// redesign.works.filterActive
  ///
  /// In de, this message translates to:
  /// **'Filter aktiv'**
  String get redesignWorksFilterActive;

  /// redesign.works.more
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get redesignWorksMore;

  /// redesign.works.noMatch
  ///
  /// In de, this message translates to:
  /// **'Kein Werk passt zur Suche.'**
  String get redesignWorksNoMatch;

  /// redesign.works.pdf
  ///
  /// In de, this message translates to:
  /// **'PDF'**
  String get redesignWorksPdf;

  /// redesign.works.resetFilter
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get redesignWorksResetFilter;

  /// redesign.works.search
  ///
  /// In de, this message translates to:
  /// **'Titel, Komponist, Nummer'**
  String get redesignWorksSearch;

  /// redesign.works.searchLabel
  ///
  /// In de, this message translates to:
  /// **'Werke suchen'**
  String get redesignWorksSearchLabel;

  /// register.create
  ///
  /// In de, this message translates to:
  /// **'Instanz jetzt erstellen'**
  String get registerCreate;

  /// register.createFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen der Instanz: {error}'**
  String registerCreateFailed(Object error);

  /// register.creating
  ///
  /// In de, this message translates to:
  /// **'Instanz wird erstellt...'**
  String get registerCreating;

  /// register.deleteAccount
  ///
  /// In de, this message translates to:
  /// **'Konto löschen'**
  String get registerDeleteAccount;

  /// register.delete.confirm
  ///
  /// In de, this message translates to:
  /// **'Endgültig löschen'**
  String get registerDeleteConfirm;

  /// register.delete.done
  ///
  /// In de, this message translates to:
  /// **'Dein Konto wurde gelöscht.'**
  String get registerDeleteDone;

  /// register.delete.failed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen: {error}'**
  String registerDeleteFailed(Object error);

  /// register.delete.header
  ///
  /// In de, this message translates to:
  /// **'Konto wirklich löschen?'**
  String get registerDeleteHeader;

  /// register.delete.message
  ///
  /// In de, this message translates to:
  /// **'Dein Konto wird unwiderruflich entfernt. Diese Aktion kann nicht rückgängig gemacht werden.'**
  String get registerDeleteMessage;

  /// register.delete.running
  ///
  /// In de, this message translates to:
  /// **'Konto wird gelöscht...'**
  String get registerDeleteRunning;

  /// register.fillAll
  ///
  /// In de, this message translates to:
  /// **'Bitte fülle alle Felder aus, um fortzufahren.'**
  String get registerFillAll;

  /// register.fillAllToast
  ///
  /// In de, this message translates to:
  /// **'Bitte füllen Sie alle Felder aus.'**
  String get registerFillAllToast;

  /// register.flutter.mainGroupInfo
  ///
  /// In de, this message translates to:
  /// **'Was ist die Hauptgruppe?'**
  String get registerFlutterMainGroupInfo;

  /// register.fullName
  ///
  /// In de, this message translates to:
  /// **'Vollständiger Name'**
  String get registerFullName;

  /// register.fullNameHelper
  ///
  /// In de, this message translates to:
  /// **'Der Name wird in der App angezeigt'**
  String get registerFullNameHelper;

  /// register.groupType
  ///
  /// In de, this message translates to:
  /// **'Gruppentyp'**
  String get registerGroupType;

  /// register.groupTypeQuestion
  ///
  /// In de, this message translates to:
  /// **'Was beschreibt deine Gruppe am besten?'**
  String get registerGroupTypeQuestion;

  /// register.helpChoir
  ///
  /// In de, this message translates to:
  /// **'Optimiert für Chöre mit Stimmgruppen (Sopran, Alt, Tenor, Bass).'**
  String get registerHelpChoir;

  /// register.helpGeneral
  ///
  /// In de, this message translates to:
  /// **'Ideal für Vereine, Teams oder sonstige Gruppen.'**
  String get registerHelpGeneral;

  /// register.helpOrchestra
  ///
  /// In de, this message translates to:
  /// **'Optimiert für Orchester/Musikgruppen mit Instrumentengruppen.'**
  String get registerHelpOrchestra;

  /// register.introHtml
  ///
  /// In de, this message translates to:
  /// **'Eine <strong>Instanz</strong> ist dein eigener Bereich für dein Orchester, deinen Chor oder deine Gruppe. Hier verwaltest du Mitglieder, Termine und Anwesenheiten.'**
  String get registerIntroHtml;

  /// register.joinHeading
  ///
  /// In de, this message translates to:
  /// **'Du möchtest einer bestehenden Instanz beitreten?'**
  String get registerJoinHeading;

  /// register.joinText
  ///
  /// In de, this message translates to:
  /// **'Bitte deinen Verantwortlichen, dich per E-Mail einzuladen. Eine neue Instanz ist nur nötig, wenn du selbst Administrator sein möchtest.'**
  String get registerJoinText;

  /// register.logout
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get registerLogout;

  /// register.mainGroupHelper
  ///
  /// In de, this message translates to:
  /// **'z.B. Leitung, Dirigenten, Vorstand'**
  String get registerMainGroupHelper;

  /// register.mainGroupInfoHtml
  ///
  /// In de, this message translates to:
  /// **'<h3>Was ist die Hauptgruppe?</h3><p>Die Hauptgruppe ist eine besondere Gruppe für Personen mit Leitungsfunktion (z.B. Dirigenten, Chorleiter, Vorstand).</p><p><strong>Besonderheiten:</strong></p><ul><li>Kann nicht gelöscht werden</li><li>Mitglieder erhalten automatisch erweiterte Rechte</li><li>Ideal für Personen, die die Instanz verwalten</li></ul><p><em>Du kannst später weitere Gruppen (z.B. Sopran, Geigen) hinzufügen.</em></p>'**
  String get registerMainGroupInfoHtml;

  /// register.mainGroupName
  ///
  /// In de, this message translates to:
  /// **'Name der Hauptgruppe'**
  String get registerMainGroupName;

  /// register.missingMainGroup
  ///
  /// In de, this message translates to:
  /// **'Name der Hauptgruppe fehlt'**
  String get registerMissingMainGroup;

  /// register.missingName
  ///
  /// In de, this message translates to:
  /// **'Name der Instanz fehlt'**
  String get registerMissingName;

  /// register.missingShortName
  ///
  /// In de, this message translates to:
  /// **'Instanz-Kürzel fehlt'**
  String get registerMissingShortName;

  /// registerModal.acceptPrivacy
  ///
  /// In de, this message translates to:
  /// **'Datenschutzerklärung akzeptieren'**
  String get registerModalAcceptPrivacy;

  /// registerModal.acceptPrivacyToast
  ///
  /// In de, this message translates to:
  /// **'Bitte stimme der Datenschutzerklärung zu'**
  String get registerModalAcceptPrivacyToast;

  /// registerModal.confirm
  ///
  /// In de, this message translates to:
  /// **'Bestätigen'**
  String get registerModalConfirm;

  /// registerModal.confirmPassword
  ///
  /// In de, this message translates to:
  /// **'Passwort bestätigen'**
  String get registerModalConfirmPassword;

  /// registerModal.confirmPasswordPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Passwort erneut eingeben'**
  String get registerModalConfirmPasswordPlaceholder;

  /// registerModal.emailPlaceholder
  ///
  /// In de, this message translates to:
  /// **'deine@email.de'**
  String get registerModalEmailPlaceholder;

  /// registerModal.failed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Registrieren'**
  String get registerModalFailed;

  /// registerModal.hintOtp
  ///
  /// In de, this message translates to:
  /// **'Nach der Registrierung senden wir dir einen 6-stelligen Code per E-Mail. Gib ihn hier ein, um deinen Account zu aktivieren.'**
  String get registerModalHintOtp;

  /// registerModal.hintPassword
  ///
  /// In de, this message translates to:
  /// **'Nach der Registrierung senden wir dir eine Bestätigungs-E-Mail. Bitte klicke auf den Link darin, um deinen Account zu aktivieren.'**
  String get registerModalHintPassword;

  /// registerModal.intro
  ///
  /// In de, this message translates to:
  /// **'Lege einen Account an, um deine Anwesenheit zu verwalten oder eine neue Instanz für deine Gruppe, deinen Chor oder dein Orchester zu erstellen.'**
  String get registerModalIntro;

  /// registerModal.invalidEmail
  ///
  /// In de, this message translates to:
  /// **'Ungültige E-Mail-Adresse'**
  String get registerModalInvalidEmail;

  /// registerModal.passwordMismatch
  ///
  /// In de, this message translates to:
  /// **'Passwörter stimmen nicht überein'**
  String get registerModalPasswordMismatch;

  /// registerModal.passwordPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Mindestens 6 Zeichen'**
  String get registerModalPasswordPlaceholder;

  /// registerModal.passwordTooShort
  ///
  /// In de, this message translates to:
  /// **'Passwort muss mindestens 6 Zeichen lang sein'**
  String get registerModalPasswordTooShort;

  /// registerModal.privacyAfter
  ///
  /// In de, this message translates to:
  /// **' gelesen.'**
  String get registerModalPrivacyAfter;

  /// registerModal.privacyBefore
  ///
  /// In de, this message translates to:
  /// **'Ich akzeptiere die Nutzungsbedingungen und habe die'**
  String get registerModalPrivacyBefore;

  /// registerModal.privacyLink
  ///
  /// In de, this message translates to:
  /// **'Datenschutzerklärung'**
  String get registerModalPrivacyLink;

  /// registerModal.running
  ///
  /// In de, this message translates to:
  /// **'Registrierung läuft...'**
  String get registerModalRunning;

  /// registerModal.submitting
  ///
  /// In de, this message translates to:
  /// **'Wird registriert...'**
  String get registerModalSubmitting;

  /// registerModal.title
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get registerModalTitle;

  /// registerModal.welcome
  ///
  /// In de, this message translates to:
  /// **'Willkommen bei Attendix!'**
  String get registerModalWelcome;

  /// register.placeholder.choirMain
  ///
  /// In de, this message translates to:
  /// **'z.B. Chorleitung'**
  String get registerPlaceholderChoirMain;

  /// register.placeholder.choirName
  ///
  /// In de, this message translates to:
  /// **'z.B. Gospelchor Harmonie'**
  String get registerPlaceholderChoirName;

  /// register.placeholder.choirShort
  ///
  /// In de, this message translates to:
  /// **'z.B. GCH'**
  String get registerPlaceholderChoirShort;

  /// register.placeholder.generalMain
  ///
  /// In de, this message translates to:
  /// **'z.B. Vorstand'**
  String get registerPlaceholderGeneralMain;

  /// register.placeholder.generalName
  ///
  /// In de, this message translates to:
  /// **'z.B. Sportverein Musterstadt'**
  String get registerPlaceholderGeneralName;

  /// register.placeholder.generalShort
  ///
  /// In de, this message translates to:
  /// **'z.B. SVM'**
  String get registerPlaceholderGeneralShort;

  /// register.placeholder.orchestraMain
  ///
  /// In de, this message translates to:
  /// **'z.B. Dirigenten'**
  String get registerPlaceholderOrchestraMain;

  /// register.placeholder.orchestraName
  ///
  /// In de, this message translates to:
  /// **'z.B. Stadtorchester Musterstadt'**
  String get registerPlaceholderOrchestraName;

  /// register.placeholder.orchestraShort
  ///
  /// In de, this message translates to:
  /// **'z.B. SOM'**
  String get registerPlaceholderOrchestraShort;

  /// register.shortName
  ///
  /// In de, this message translates to:
  /// **'Instanz-Kürzel'**
  String get registerShortName;

  /// register.shortNameHelper
  ///
  /// In de, this message translates to:
  /// **'Wird für kompakte Darstellungen verwendet'**
  String get registerShortNameHelper;

  /// register.step1
  ///
  /// In de, this message translates to:
  /// **'Art der Gruppe wählen'**
  String get registerStep1;

  /// register.step2
  ///
  /// In de, this message translates to:
  /// **'Name deiner Instanz'**
  String get registerStep2;

  /// register.step3
  ///
  /// In de, this message translates to:
  /// **'Hauptgruppe festlegen'**
  String get registerStep3;

  /// register.summary
  ///
  /// In de, this message translates to:
  /// **'Zusammenfassung'**
  String get registerSummary;

  /// register.summaryMainGroup
  ///
  /// In de, this message translates to:
  /// **'Hauptgruppe: {name}'**
  String registerSummaryMainGroup(Object name);

  /// register.summaryType
  ///
  /// In de, this message translates to:
  /// **'Typ: {type}'**
  String registerSummaryType(Object type);

  /// register.title
  ///
  /// In de, this message translates to:
  /// **'Neue Instanz anlegen'**
  String get registerTitle;

  /// register.typeChoir
  ///
  /// In de, this message translates to:
  /// **'Chor'**
  String get registerTypeChoir;

  /// register.typeChoirOption
  ///
  /// In de, this message translates to:
  /// **'Chor / Gesangsgruppe'**
  String get registerTypeChoirOption;

  /// register.typeGeneral
  ///
  /// In de, this message translates to:
  /// **'Allgemeine Gruppe'**
  String get registerTypeGeneral;

  /// register.typeOrchestra
  ///
  /// In de, this message translates to:
  /// **'Orchester'**
  String get registerTypeOrchestra;

  /// register.typeOrchestraOption
  ///
  /// In de, this message translates to:
  /// **'Orchester / Musikgruppe'**
  String get registerTypeOrchestraOption;

  /// register.welcome
  ///
  /// In de, this message translates to:
  /// **'Willkommen!'**
  String get registerWelcome;

  /// rolePerm.absencesHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn aktiviert, können Personen mit dieser Rolle geplante Abwesenheiten für sich selbst eintragen.'**
  String get rolePermAbsencesHelper;

  /// rolePerm.allGroups
  ///
  /// In de, this message translates to:
  /// **'Alle Gruppen pflegen'**
  String get rolePermAllGroups;

  /// rolePerm.allGroupsHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn deaktiviert, können Personen mit dieser Rolle nur Anwesenheiten der ihnen zugeordneten Gruppe pflegen.'**
  String get rolePermAllGroupsHelper;

  /// rolePerm.allowPause
  ///
  /// In de, this message translates to:
  /// **'Eigene Pausierung erlauben'**
  String get rolePermAllowPause;

  /// rolePerm.checklistHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn aktiviert, können Personen mit dieser Rolle die Checkliste in der Anwesenheitsansicht sehen.'**
  String get rolePermChecklistHelper;

  /// rolePerm.createAttendance
  ///
  /// In de, this message translates to:
  /// **'Anwesenheiten erstellen'**
  String get rolePermCreateAttendance;

  /// rolePerm.createHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn deaktiviert, können Personen mit dieser Rolle keine neuen Anwesenheiten anlegen.'**
  String get rolePermCreateHelper;

  /// rolePerm.discard
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get rolePermDiscard;

  /// rolePerm.enterAbsences
  ///
  /// In de, this message translates to:
  /// **'Geplante Abwesenheiten eintragen'**
  String get rolePermEnterAbsences;

  /// rolePerm.files
  ///
  /// In de, this message translates to:
  /// **'Dateiablage'**
  String get rolePermFiles;

  /// rolePerm.filesForAll
  ///
  /// In de, this message translates to:
  /// **'Dateiablage für alle Mitglieder'**
  String get rolePermFilesForAll;

  /// rolePerm.filesHelper
  ///
  /// In de, this message translates to:
  /// **'Admins, Verantwortliche und Helfer sehen die Dateiablage immer. Wenn aktiviert, können auch alle anderen Mitglieder außer Bewerber sie lesen. Hochladen bleibt Admins und Verantwortlichen vorbehalten.'**
  String get rolePermFilesHelper;

  /// rolePerm.flutter.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Rollenberechtigungen\n{error}'**
  String rolePermFlutterLoadFailed(Object error);

  /// rolePerm.notesHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn aktiviert, können Personen mit dieser Rolle die Notizen der Mitglieder in der Anwesenheitsansicht sehen.'**
  String get rolePermNotesHelper;

  /// rolePerm.pauseHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn aktiviert, können Spieler sich selbst pausieren und reaktivieren.'**
  String get rolePermPauseHelper;

  /// rolePerm.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern der Rollenberechtigungen'**
  String get rolePermSaveFailed;

  /// rolePerm.saved
  ///
  /// In de, this message translates to:
  /// **'Rollenberechtigungen gespeichert'**
  String get rolePermSaved;

  /// rolePerm.seeChecklist
  ///
  /// In de, this message translates to:
  /// **'Checkliste sehen'**
  String get rolePermSeeChecklist;

  /// rolePerm.seeNotes
  ///
  /// In de, this message translates to:
  /// **'Spielernotizen sehen'**
  String get rolePermSeeNotes;

  /// rolePerm.title
  ///
  /// In de, this message translates to:
  /// **'Rollen & Berechtigungen'**
  String get rolePermTitle;

  /// rolePerm.unsaved
  ///
  /// In de, this message translates to:
  /// **'Ungespeicherte Änderungen'**
  String get rolePermUnsaved;

  /// rolePerm.unsavedMessage
  ///
  /// In de, this message translates to:
  /// **'Du hast ungespeicherte Änderungen. Möchtest du sie speichern bevor du die Seite verlässt?'**
  String get rolePermUnsavedMessage;

  /// roles.administrator
  ///
  /// In de, this message translates to:
  /// **'Administrator'**
  String get rolesAdministrator;

  /// roles.applicant
  ///
  /// In de, this message translates to:
  /// **'Bewerber'**
  String get rolesApplicant;

  /// roles.helper
  ///
  /// In de, this message translates to:
  /// **'Helfer'**
  String get rolesHelper;

  /// roles.member
  ///
  /// In de, this message translates to:
  /// **'Mitglied'**
  String get rolesMember;

  /// roles.parent
  ///
  /// In de, this message translates to:
  /// **'Elternteil'**
  String get rolesParent;

  /// roles.parents
  ///
  /// In de, this message translates to:
  /// **'Eltern'**
  String get rolesParents;

  /// roles.responsible
  ///
  /// In de, this message translates to:
  /// **'Verantwortlicher'**
  String get rolesResponsible;

  /// roles.viewer
  ///
  /// In de, this message translates to:
  /// **'Beobachter'**
  String get rolesViewer;

  /// roles.voiceLeader
  ///
  /// In de, this message translates to:
  /// **'Stimmführer'**
  String get rolesVoiceLeader;

  /// roles.voiceLeaderHelper
  ///
  /// In de, this message translates to:
  /// **'Stimmführer-Helfer'**
  String get rolesVoiceLeaderHelper;

  /// selfService.allEvents
  ///
  /// In de, this message translates to:
  /// **'Alle Termine'**
  String get selfServiceAllEvents;

  /// selfService.allKidsSignInOut
  ///
  /// In de, this message translates to:
  /// **'Alle Kinder an- bzw. abmelden'**
  String get selfServiceAllKidsSignInOut;

  /// selfService.attachment
  ///
  /// In de, this message translates to:
  /// **'Anhang'**
  String get selfServiceAttachment;

  /// selfService.byInstance
  ///
  /// In de, this message translates to:
  /// **'Nach Instanz'**
  String get selfServiceByInstance;

  /// selfService.chronological
  ///
  /// In de, this message translates to:
  /// **'Chronologisch'**
  String get selfServiceChronological;

  /// selfService.deadline
  ///
  /// In de, this message translates to:
  /// **'Anmeldefrist: {date}'**
  String selfServiceDeadline(Object date);

  /// selfService.flutter.child
  ///
  /// In de, this message translates to:
  /// **'Kind'**
  String get selfServiceFlutterChild;

  /// selfService.flutter.noKids
  ///
  /// In de, this message translates to:
  /// **'Keine Kinder gefunden'**
  String get selfServiceFlutterNoKids;

  /// selfService.flutter.noKidsHint
  ///
  /// In de, this message translates to:
  /// **'Es wurden keine Kinder mit Ihrem\nEltern-Account verknüpft.'**
  String get selfServiceFlutterNoKidsHint;

  /// selfService.flutter.noValidEntries
  ///
  /// In de, this message translates to:
  /// **'Keine gültigen Einträge gefunden'**
  String get selfServiceFlutterNoValidEntries;

  /// selfService.flutter.signInUntil
  ///
  /// In de, this message translates to:
  /// **'Anmelden bis {date} Uhr'**
  String selfServiceFlutterSignInUntil(Object date);

  /// selfService.flutter.switchFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Wechseln: {error}'**
  String selfServiceFlutterSwitchFailed(Object error);

  /// selfService.loadingEvents
  ///
  /// In de, this message translates to:
  /// **'Termine werden geladen...'**
  String get selfServiceLoadingEvents;

  /// selfService.noEvents
  ///
  /// In de, this message translates to:
  /// **'Keine Termine gefunden'**
  String get selfServiceNoEvents;

  /// selfService.noUpcoming
  ///
  /// In de, this message translates to:
  /// **'Keine anstehenden Termine'**
  String get selfServiceNoUpcoming;

  /// selfService.parentsThanksLate
  ///
  /// In de, this message translates to:
  /// **'Vielen Dank für die Info und Gottes Segen!'**
  String get selfServiceParentsThanksLate;

  /// selfService.parentsThanksSignout
  ///
  /// In de, this message translates to:
  /// **'Vielen Dank für die rechtzeitige Abmeldung und Gottes Segen!'**
  String get selfServiceParentsThanksSignout;

  /// selfService.shalom
  ///
  /// In de, this message translates to:
  /// **'Shalom!'**
  String get selfServiceShalom;

  /// selfService.showCurrentSongs
  ///
  /// In de, this message translates to:
  /// **'Aktuelle Werke anzeigen'**
  String get selfServiceShowCurrentSongs;

  /// selfService.thanksForSignIn
  ///
  /// In de, this message translates to:
  /// **'Danke für die Anmeldung 🙂'**
  String get selfServiceThanksForSignIn;

  /// selfService.youManageKids
  ///
  /// In de, this message translates to:
  /// **'Du verwaltest {count, plural, one {{count} Kind} other {{count} Kinder}}:'**
  String selfServiceYouManageKids(num count);

  /// settings.accountsCreated
  ///
  /// In de, this message translates to:
  /// **'Die Accounts wurden erfolgreich angelegt'**
  String get settingsAccountsCreated;

  /// settings.adHocPlanning
  ///
  /// In de, this message translates to:
  /// **'Ad-Hoc Ablaufplanung'**
  String get settingsAdHocPlanning;

  /// settings.addAdmin
  ///
  /// In de, this message translates to:
  /// **'Admin hinzufügen'**
  String get settingsAddAdmin;

  /// settings.addParent
  ///
  /// In de, this message translates to:
  /// **'Elternteil hinzufügen'**
  String get settingsAddParent;

  /// settings.addViewer
  ///
  /// In de, this message translates to:
  /// **'Beobachter hinzufügen'**
  String get settingsAddViewer;

  /// settings.adminAdded
  ///
  /// In de, this message translates to:
  /// **'Der Admin wurde erfolgreich hinzugefügt.'**
  String get settingsAdminAdded;

  /// settings.adminRemoved
  ///
  /// In de, this message translates to:
  /// **'Der Admin wurde erfolgreich entfernt.'**
  String get settingsAdminRemoved;

  /// settings.admins
  ///
  /// In de, this message translates to:
  /// **'Administratoren'**
  String get settingsAdmins;

  /// settings.adminsHint
  ///
  /// In de, this message translates to:
  /// **'Administratoren haben alle Rechte in der Instanz und können auch die Instanz löschen.'**
  String get settingsAdminsHint;

  /// settings.analyticsData
  ///
  /// In de, this message translates to:
  /// **'Auswertung & Daten'**
  String get settingsAnalyticsData;

  /// settings.announcements
  ///
  /// In de, this message translates to:
  /// **'Mitteilungen'**
  String get settingsAnnouncements;

  /// settings.anonymous
  ///
  /// In de, this message translates to:
  /// **'Anonym'**
  String get settingsAnonymous;

  /// settings.appStore
  ///
  /// In de, this message translates to:
  /// **'Im App Store laden'**
  String get settingsAppStore;

  /// settings.archive
  ///
  /// In de, this message translates to:
  /// **'Archiv'**
  String get settingsArchive;

  /// settings.asApp
  ///
  /// In de, this message translates to:
  /// **'📱 Attendix als App'**
  String get settingsAsApp;

  /// settings.asAppText
  ///
  /// In de, this message translates to:
  /// **'Attendix gibt es jetzt als native App mit Push-Benachrichtigungen und schnellerem Zugriff.'**
  String get settingsAsAppText;

  /// settings.calendarMessage
  ///
  /// In de, this message translates to:
  /// **'Kopiere den folgenden Link in deine Kalender-App, um die Termine zu abonnieren:\n\n{link}'**
  String settingsCalendarMessage(Object link);

  /// settings.cannotDeleteTenant
  ///
  /// In de, this message translates to:
  /// **'Du kannst diese Instanz nicht löschen.'**
  String get settingsCannotDeleteTenant;

  /// settings.cannotRemoveSelf
  ///
  /// In de, this message translates to:
  /// **'Du kannst dich nicht selbst entfernen.'**
  String get settingsCannotRemoveSelf;

  /// settings.certificates
  ///
  /// In de, this message translates to:
  /// **'Urkunden generieren'**
  String get settingsCertificates;

  /// settings.certificatesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen der Urkunden.'**
  String get settingsCertificatesFailed;

  /// settings.certificatesFor
  ///
  /// In de, this message translates to:
  /// **'Für welche Gruppen sollen Urkunden erstellt werden?'**
  String get settingsCertificatesFor;

  /// settings.change
  ///
  /// In de, this message translates to:
  /// **'Ändern'**
  String get settingsChange;

  /// settings.changePassword
  ///
  /// In de, this message translates to:
  /// **'Passwort ändern'**
  String get settingsChangePassword;

  /// settings.communication
  ///
  /// In de, this message translates to:
  /// **'Kommunikation'**
  String get settingsCommunication;

  /// settings.configureDashboard
  ///
  /// In de, this message translates to:
  /// **'Dashboard konfigurieren'**
  String get settingsConfigureDashboard;

  /// settings.contactOnly
  ///
  /// In de, this message translates to:
  /// **'Dient nur zur Kontaktaufnahme bei Rückfragen'**
  String get settingsContactOnly;

  /// settings.contactTelegram
  ///
  /// In de, this message translates to:
  /// **'Per Telegram kontaktieren'**
  String get settingsContactTelegram;

  /// settings.continue
  ///
  /// In de, this message translates to:
  /// **'Fortfahren'**
  String get settingsContinue;

  /// settings.copyLink
  ///
  /// In de, this message translates to:
  /// **'Link kopieren'**
  String get settingsCopyLink;

  /// settings.createAccounts
  ///
  /// In de, this message translates to:
  /// **'Accounts anlegen'**
  String get settingsCreateAccounts;

  /// settings.createAccountsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen der Accounts: {error}'**
  String settingsCreateAccountsFailed(Object error);

  /// settings.createAccountsMessage
  ///
  /// In de, this message translates to:
  /// **'Folgende Accounts werden angelegt: {names}'**
  String settingsCreateAccountsMessage(Object names);

  /// settings.createMissing
  ///
  /// In de, this message translates to:
  /// **'Fehlende Accounts anlegen'**
  String get settingsCreateMissing;

  /// settings.creatingCertificates
  ///
  /// In de, this message translates to:
  /// **'Urkunden werden erstellt...'**
  String get settingsCreatingCertificates;

  /// settings.current
  ///
  /// In de, this message translates to:
  /// **'Aktuell'**
  String get settingsCurrent;

  /// settings.deleteAccount
  ///
  /// In de, this message translates to:
  /// **'Konto löschen'**
  String get settingsDeleteAccount;

  /// settings.deleteTenant
  ///
  /// In de, this message translates to:
  /// **'Instanz löschen?'**
  String get settingsDeleteTenant;

  /// settings.deleteTenantMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die Instanz „{name}“ wirklich löschen? Dies kann nicht rückgängig gemacht werden! Wenn du die Instanz wirklich löschen willst, dann gebe den Namen der Instanz ein:'**
  String settingsDeleteTenantMessage(Object name);

  /// settings.emailAddress
  ///
  /// In de, this message translates to:
  /// **'E-Mail-Adresse'**
  String get settingsEmailAddress;

  /// settings.enableTenantSelect
  ///
  /// In de, this message translates to:
  /// **'Instanzauswahl aktivieren'**
  String get settingsEnableTenantSelect;

  /// settings.export
  ///
  /// In de, this message translates to:
  /// **'Export'**
  String get settingsExport;

  /// settings.extraFields
  ///
  /// In de, this message translates to:
  /// **'Zusatzfelder'**
  String get settingsExtraFields;

  /// settings.favoriteRemoved
  ///
  /// In de, this message translates to:
  /// **'Die Instanz „{name}“ wurde als Favorit entfernt.'**
  String settingsFavoriteRemoved(Object name);

  /// settings.favoriteSet
  ///
  /// In de, this message translates to:
  /// **'Die Instanz „{name}“ wurde als Favorit gesetzt.'**
  String settingsFavoriteSet(Object name);

  /// settings.feedback
  ///
  /// In de, this message translates to:
  /// **'Feedback'**
  String get settingsFeedback;

  /// settings.feedbackFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Senden des Feedbacks: {error}'**
  String settingsFeedbackFailed(Object error);

  /// settings.feedbackPh
  ///
  /// In de, this message translates to:
  /// **'Dein Feedback eingeben...'**
  String get settingsFeedbackPh;

  /// settings.feedbackSent
  ///
  /// In de, this message translates to:
  /// **'Dein Feedback wurde erfolgreich gesendet. Vielen Dank!'**
  String get settingsFeedbackSent;

  /// settings.fileStorage
  ///
  /// In de, this message translates to:
  /// **'Dateiablage'**
  String get settingsFileStorage;

  /// settings.files
  ///
  /// In de, this message translates to:
  /// **'Dateien'**
  String get settingsFiles;

  /// settings.flutter.addFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen'**
  String get settingsFlutterAddFailed;

  /// settings.flutter.adminAddedNotNotified
  ///
  /// In de, this message translates to:
  /// **'Der Admin wurde hinzugefügt, konnte aber nicht benachrichtigt werden.'**
  String get settingsFlutterAdminAddedNotNotified;

  /// settings.flutter.applicantText
  ///
  /// In de, this message translates to:
  /// **'Ein Administrator wird deine Registrierung prüfen.'**
  String get settingsFlutterApplicantText;

  /// settings.flutter.applicantTitle
  ///
  /// In de, this message translates to:
  /// **'Mitgliedschaft wird geprüft'**
  String get settingsFlutterApplicantTitle;

  /// settings.flutter.archiveHint
  ///
  /// In de, this message translates to:
  /// **'Hier erscheinen archivierte Mitglieder'**
  String get settingsFlutterArchiveHint;

  /// settings.flutter.batch.allHaveAccount
  ///
  /// In de, this message translates to:
  /// **'Alle Spieler mit E-Mail haben bereits einen Account.'**
  String get settingsFlutterBatchAllHaveAccount;

  /// settings.flutter.batch.createButton
  ///
  /// In de, this message translates to:
  /// **'Accounts für {count} Spieler erstellen'**
  String settingsFlutterBatchCreateButton(Object count);

  /// settings.flutter.batch.eligible
  ///
  /// In de, this message translates to:
  /// **'Account erstellbar (mit E-Mail)'**
  String get settingsFlutterBatchEligible;

  /// settings.flutter.batch.eligibleList
  ///
  /// In de, this message translates to:
  /// **'Spieler ohne Account ({count})'**
  String settingsFlutterBatchEligibleList(Object count);

  /// settings.flutter.batch.failed
  ///
  /// In de, this message translates to:
  /// **'{count} fehlgeschlagen'**
  String settingsFlutterBatchFailed(Object count);

  /// settings.flutter.batch.noEmail
  ///
  /// In de, this message translates to:
  /// **'Ohne E-Mail (manuell nötig)'**
  String get settingsFlutterBatchNoEmail;

  /// settings.flutter.batch.processed
  ///
  /// In de, this message translates to:
  /// **'{processed} / {total} verarbeitet'**
  String settingsFlutterBatchProcessed(Object processed, Object total);

  /// settings.flutter.batch.succeeded
  ///
  /// In de, this message translates to:
  /// **'{count} erfolgreich'**
  String settingsFlutterBatchSucceeded(Object count);

  /// settings.flutter.batch.title
  ///
  /// In de, this message translates to:
  /// **'Accounts erstellen'**
  String get settingsFlutterBatchTitle;

  /// settings.flutter.batch.withAccount
  ///
  /// In de, this message translates to:
  /// **'Mit Account'**
  String get settingsFlutterBatchWithAccount;

  /// settings.flutter.calendarIntro
  ///
  /// In de, this message translates to:
  /// **'Kopiere den folgenden Link in deine Kalender-App, um die Termine zu abonnieren:'**
  String get settingsFlutterCalendarIntro;

  /// settings.flutter.changeEmail
  ///
  /// In de, this message translates to:
  /// **'E-Mail ändern'**
  String get settingsFlutterChangeEmail;

  /// settings.flutter.changeEmailFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Ändern der E-Mail-Adresse: {error}'**
  String settingsFlutterChangeEmailFailed(Object error);

  /// settings.flutter.confirmEmailChange
  ///
  /// In de, this message translates to:
  /// **'Bitte bestätige die Änderung über den Link in der E-Mail an deine neue Adresse.'**
  String get settingsFlutterConfirmEmailChange;

  /// settings.flutter.copyLinkFailed
  ///
  /// In de, this message translates to:
  /// **'Link konnte nicht kopiert werden'**
  String get settingsFlutterCopyLinkFailed;

  /// settings.flutter.createFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen: {error}'**
  String settingsFlutterCreateFailed(Object error);

  /// settings.flutter.currentEmail
  ///
  /// In de, this message translates to:
  /// **'Aktuell: {email}'**
  String settingsFlutterCurrentEmail(Object email);

  /// settings.flutter.emailRequired
  ///
  /// In de, this message translates to:
  /// **'E-Mail ist erforderlich'**
  String get settingsFlutterEmailRequired;

  /// settings.flutter.errorDetail
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String settingsFlutterErrorDetail(Object error);

  /// settings.flutter.firstNameRequired
  ///
  /// In de, this message translates to:
  /// **'Vorname ist erforderlich'**
  String get settingsFlutterFirstNameRequired;

  /// settings.flutter.invalidEmail
  ///
  /// In de, this message translates to:
  /// **'Bitte gib eine gültige E-Mail-Adresse ein.'**
  String get settingsFlutterInvalidEmail;

  /// settings.flutter.lastNameRequired
  ///
  /// In de, this message translates to:
  /// **'Nachname ist erforderlich'**
  String get settingsFlutterLastNameRequired;

  /// settings.flutter.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden: {error}'**
  String settingsFlutterLoadFailed(Object error);

  /// settings.flutter.newEmailPh
  ///
  /// In de, this message translates to:
  /// **'Neue E-Mail-Adresse...'**
  String get settingsFlutterNewEmailPh;

  /// settings.flutter.noProfile
  ///
  /// In de, this message translates to:
  /// **'Kein Profil gefunden'**
  String get settingsFlutterNoProfile;

  /// settings.flutter.parentRemoved
  ///
  /// In de, this message translates to:
  /// **'Elternteil entfernt'**
  String get settingsFlutterParentRemoved;

  /// settings.flutter.pending.approve
  ///
  /// In de, this message translates to:
  /// **'Genehmigen'**
  String get settingsFlutterPendingApprove;

  /// settings.flutter.pending.approveMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du {name} als Mitglied freischalten?'**
  String settingsFlutterPendingApproveMessage(Object name);

  /// settings.flutter.pending.approveTitle
  ///
  /// In de, this message translates to:
  /// **'Registrierung genehmigen?'**
  String get settingsFlutterPendingApproveTitle;

  /// settings.flutter.pending.approved
  ///
  /// In de, this message translates to:
  /// **'{name} wurde freigeschaltet'**
  String settingsFlutterPendingApproved(Object name);

  /// settings.flutter.pending.declineMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du die Registrierung von {name} ablehnen? Der Eintrag wird gelöscht.'**
  String settingsFlutterPendingDeclineMessage(Object name);

  /// settings.flutter.pending.declineTitle
  ///
  /// In de, this message translates to:
  /// **'Registrierung ablehnen?'**
  String get settingsFlutterPendingDeclineTitle;

  /// settings.flutter.pending.declined
  ///
  /// In de, this message translates to:
  /// **'Registrierung abgelehnt'**
  String get settingsFlutterPendingDeclined;

  /// settings.flutter.pending.empty
  ///
  /// In de, this message translates to:
  /// **'Keine ausstehenden Registrierungen'**
  String get settingsFlutterPendingEmpty;

  /// settings.flutter.pending.emptyHint
  ///
  /// In de, this message translates to:
  /// **'Neue Registrierungen erscheinen hier automatisch'**
  String get settingsFlutterPendingEmptyHint;

  /// settings.flutter.pending.invalidId
  ///
  /// In de, this message translates to:
  /// **'Ungültige Spieler-ID'**
  String get settingsFlutterPendingInvalidId;

  /// settings.flutter.pwa.androidStep1
  ///
  /// In de, this message translates to:
  /// **'Tippe auf das Menü (⋮)'**
  String get settingsFlutterPwaAndroidStep1;

  /// settings.flutter.pwa.androidStep2
  ///
  /// In de, this message translates to:
  /// **'\"App installieren\" oder \"Zum Startbildschirm\"'**
  String get settingsFlutterPwaAndroidStep2;

  /// settings.flutter.pwa.iosStep1
  ///
  /// In de, this message translates to:
  /// **'Tippe auf das Teilen-Symbol'**
  String get settingsFlutterPwaIosStep1;

  /// settings.flutter.pwa.iosStep2
  ///
  /// In de, this message translates to:
  /// **'\"Zum Home-Bildschirm\"'**
  String get settingsFlutterPwaIosStep2;

  /// settings.flutter.pwa.iosStep3
  ///
  /// In de, this message translates to:
  /// **'\"Hinzufügen\"'**
  String get settingsFlutterPwaIosStep3;

  /// settings.flutter.pwa.text
  ///
  /// In de, this message translates to:
  /// **'Für ein besseres Erlebnis kannst du diese App installieren:'**
  String get settingsFlutterPwaText;

  /// settings.flutter.pwa.title
  ///
  /// In de, this message translates to:
  /// **'App installieren'**
  String get settingsFlutterPwaTitle;

  /// settings.flutter.reactivateMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du {name} wieder aktivieren?'**
  String settingsFlutterReactivateMessage(Object name);

  /// settings.flutter.reactivated
  ///
  /// In de, this message translates to:
  /// **'{name} wurde reaktiviert'**
  String settingsFlutterReactivated(Object name);

  /// settings.flutter.sameEmail
  ///
  /// In de, this message translates to:
  /// **'Das ist bereits deine E-Mail-Adresse.'**
  String get settingsFlutterSameEmail;

  /// settings.flutter.userMgmt.add
  ///
  /// In de, this message translates to:
  /// **'Benutzer hinzufügen'**
  String get settingsFlutterUserMgmtAdd;

  /// settings.flutter.userMgmt.addFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen des Benutzers'**
  String get settingsFlutterUserMgmtAddFailed;

  /// settings.flutter.userMgmt.added
  ///
  /// In de, this message translates to:
  /// **'Benutzer hinzugefügt'**
  String get settingsFlutterUserMgmtAdded;

  /// settings.flutter.userMgmt.emailPh
  ///
  /// In de, this message translates to:
  /// **'email@beispiel.de'**
  String get settingsFlutterUserMgmtEmailPh;

  /// settings.flutter.userMgmt.lastAdmin
  ///
  /// In de, this message translates to:
  /// **'Der letzte Administrator kann nicht herabgestuft werden. Bitte füge zuerst einen weiteren Admin hinzu.'**
  String get settingsFlutterUserMgmtLastAdmin;

  /// settings.flutter.userMgmt.noAdmins
  ///
  /// In de, this message translates to:
  /// **'Keine Administratoren'**
  String get settingsFlutterUserMgmtNoAdmins;

  /// settings.flutter.userMgmt.noAdminsHint
  ///
  /// In de, this message translates to:
  /// **'Füge Admins über den + Button hinzu'**
  String get settingsFlutterUserMgmtNoAdminsHint;

  /// settings.flutter.userMgmt.noParents
  ///
  /// In de, this message translates to:
  /// **'Keine Eltern'**
  String get settingsFlutterUserMgmtNoParents;

  /// settings.flutter.userMgmt.noParentsHint
  ///
  /// In de, this message translates to:
  /// **'Eltern können ihre Kinder an-/abmelden'**
  String get settingsFlutterUserMgmtNoParentsHint;

  /// settings.flutter.userMgmt.noRole
  ///
  /// In de, this message translates to:
  /// **'Keine Rolle'**
  String get settingsFlutterUserMgmtNoRole;

  /// settings.flutter.userMgmt.noUsers
  ///
  /// In de, this message translates to:
  /// **'Keine Benutzer vorhanden'**
  String get settingsFlutterUserMgmtNoUsers;

  /// settings.flutter.userMgmt.noViewers
  ///
  /// In de, this message translates to:
  /// **'Keine Betrachter'**
  String get settingsFlutterUserMgmtNoViewers;

  /// settings.flutter.userMgmt.noViewersHint
  ///
  /// In de, this message translates to:
  /// **'Betrachter können Anwesenheit sehen, aber nicht bearbeiten'**
  String get settingsFlutterUserMgmtNoViewersHint;

  /// settings.flutter.userMgmt.players
  ///
  /// In de, this message translates to:
  /// **'Spieler'**
  String get settingsFlutterUserMgmtPlayers;

  /// settings.flutter.userMgmt.responsibles
  ///
  /// In de, this message translates to:
  /// **'Verantwortliche'**
  String get settingsFlutterUserMgmtResponsibles;

  /// settings.flutter.userMgmt.roleChangeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Ändern der Rolle'**
  String get settingsFlutterUserMgmtRoleChangeFailed;

  /// settings.flutter.userMgmt.roleChanged
  ///
  /// In de, this message translates to:
  /// **'Rolle geändert zu {role}'**
  String settingsFlutterUserMgmtRoleChanged(Object role);

  /// settings.flutter.userMgmt.selfDemoteConfirm
  ///
  /// In de, this message translates to:
  /// **'Ja, Rolle ändern'**
  String get settingsFlutterUserMgmtSelfDemoteConfirm;

  /// settings.flutter.userMgmt.selfDemoteMessage
  ///
  /// In de, this message translates to:
  /// **'Du bist dabei, deine eigene Admin-Rolle zu entfernen. Du verlierst dadurch den Zugang zur Benutzerverwaltung. Möchtest du fortfahren?'**
  String get settingsFlutterUserMgmtSelfDemoteMessage;

  /// settings.flutter.userMgmt.selfDemoteTitle
  ///
  /// In de, this message translates to:
  /// **'Eigene Rolle ändern?'**
  String get settingsFlutterUserMgmtSelfDemoteTitle;

  /// settings.flutter.userMgmt.tabAdmins
  ///
  /// In de, this message translates to:
  /// **'Admins'**
  String get settingsFlutterUserMgmtTabAdmins;

  /// settings.flutter.userMgmt.tabAll
  ///
  /// In de, this message translates to:
  /// **'Alle Benutzer'**
  String get settingsFlutterUserMgmtTabAll;

  /// settings.flutter.userMgmt.title
  ///
  /// In de, this message translates to:
  /// **'Benutzerverwaltung'**
  String get settingsFlutterUserMgmtTitle;

  /// settings.flutter.users
  ///
  /// In de, this message translates to:
  /// **'Benutzer'**
  String get settingsFlutterUsers;

  /// settings.flutter.viewerRemoved
  ///
  /// In de, this message translates to:
  /// **'Beobachter entfernt'**
  String get settingsFlutterViewerRemoved;

  /// settings.generate
  ///
  /// In de, this message translates to:
  /// **'Generieren'**
  String get settingsGenerate;

  /// settings.giveFeedback
  ///
  /// In de, this message translates to:
  /// **'Feedback geben'**
  String get settingsGiveFeedback;

  /// settings.googlePlay
  ///
  /// In de, this message translates to:
  /// **'Bei Google Play laden'**
  String get settingsGooglePlay;

  /// settings.groups
  ///
  /// In de, this message translates to:
  /// **'Gruppen'**
  String get settingsGroups;

  /// settings.help
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get settingsHelp;

  /// settings.helpFeedback
  ///
  /// In de, this message translates to:
  /// **'Hilfe & Feedback'**
  String get settingsHelpFeedback;

  /// settings.helpQuestion
  ///
  /// In de, this message translates to:
  /// **'Hilfe/Frage'**
  String get settingsHelpQuestion;

  /// settings.hideCancelled
  ///
  /// In de, this message translates to:
  /// **'Abgesagte Termine ausblenden'**
  String get settingsHideCancelled;

  /// settings.imageTooBig
  ///
  /// In de, this message translates to:
  /// **'Das Bild darf maximal 2MB groß sein.'**
  String get settingsImageTooBig;

  /// settings.installUpdate
  ///
  /// In de, this message translates to:
  /// **'Update installieren'**
  String get settingsInstallUpdate;

  /// settings.invite
  ///
  /// In de, this message translates to:
  /// **'Einladen'**
  String get settingsInvite;

  /// settings.language.hint
  ///
  /// In de, this message translates to:
  /// **'Gilt für die App sowie für Push-Nachrichten, Telegram und E-Mails an dich.'**
  String get settingsLanguageHint;

  /// settings.language.title
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguageTitle;

  /// settings.leftOn
  ///
  /// In de, this message translates to:
  /// **'Ausgetreten: {date}'**
  String settingsLeftOn(Object date);

  /// settings.linkCopied
  ///
  /// In de, this message translates to:
  /// **'Der Link wurde in die Zwischenablage kopiert'**
  String get settingsLinkCopied;

  /// settings.logout
  ///
  /// In de, this message translates to:
  /// **'Ausloggen'**
  String get settingsLogout;

  /// settings.messageAll
  ///
  /// In de, this message translates to:
  /// **'Nachricht an alle senden'**
  String get settingsMessageAll;

  /// settings.mobile
  ///
  /// In de, this message translates to:
  /// **'Handynummer'**
  String get settingsMobile;

  /// settings.myData
  ///
  /// In de, this message translates to:
  /// **'Meine Stammdaten'**
  String get settingsMyData;

  /// settings.myVoice
  ///
  /// In de, this message translates to:
  /// **'Meine Stimme'**
  String get settingsMyVoice;

  /// settings.new
  ///
  /// In de, this message translates to:
  /// **'NEU'**
  String get settingsNew;

  /// settings.newPasswordPh
  ///
  /// In de, this message translates to:
  /// **'Neues Passwort eingeben...'**
  String get settingsNewPasswordPh;

  /// settings.noArchived
  ///
  /// In de, this message translates to:
  /// **'Keine archivierten Personen'**
  String get settingsNoArchived;

  /// settings.noChurch
  ///
  /// In de, this message translates to:
  /// **'Keine Gemeinde gefunden.'**
  String get settingsNoChurch;

  /// settings.noPersonsInGroups
  ///
  /// In de, this message translates to:
  /// **'Keine Personen in den gewählten Gruppen gefunden.'**
  String get settingsNoPersonsInGroups;

  /// settings.notLinked
  ///
  /// In de, this message translates to:
  /// **'Nicht verknüpft'**
  String get settingsNotLinked;

  /// settings.notListed
  ///
  /// In de, this message translates to:
  /// **'Nicht gelistet'**
  String get settingsNotListed;

  /// settings.notifications
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen'**
  String get settingsNotifications;

  /// settings.openGuide
  ///
  /// In de, this message translates to:
  /// **'Anleitung öffnen'**
  String get settingsOpenGuide;

  /// settings.or
  ///
  /// In de, this message translates to:
  /// **'oder'**
  String get settingsOr;

  /// settings.organisation
  ///
  /// In de, this message translates to:
  /// **'Organisation'**
  String get settingsOrganisation;

  /// settings.parents
  ///
  /// In de, this message translates to:
  /// **'Eltern'**
  String get settingsParents;

  /// settings.parentsHint
  ///
  /// In de, this message translates to:
  /// **'Eltern können die Anwesenheiten ihrer Kinder einsehen und Abwesenheiten pflegen.'**
  String get settingsParentsHint;

  /// settings.passPhoto
  ///
  /// In de, this message translates to:
  /// **'Passbild'**
  String get settingsPassPhoto;

  /// settings.passwordChanged
  ///
  /// In de, this message translates to:
  /// **'Das Passwort wurde erfolgreich geändert'**
  String get settingsPasswordChanged;

  /// settings.passwordFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Ändern deines Passworts. Bitte versuche es später erneut.'**
  String get settingsPasswordFailed;

  /// settings.passwordTooShort
  ///
  /// In de, this message translates to:
  /// **'Das Passwort muss mindestens 6 Zeichen lang sein.'**
  String get settingsPasswordTooShort;

  /// settings.passwordsMismatch
  ///
  /// In de, this message translates to:
  /// **'Die Passwörter stimmen nicht überein.'**
  String get settingsPasswordsMismatch;

  /// settings.pendingCount
  ///
  /// In de, this message translates to:
  /// **'{count} ausstehende Registrierung(en)'**
  String settingsPendingCount(Object count);

  /// settings.pendingPersons
  ///
  /// In de, this message translates to:
  /// **'Ausstehende Personen'**
  String get settingsPendingPersons;

  /// settings.phonePh
  ///
  /// In de, this message translates to:
  /// **'Handynummer eingeben...'**
  String get settingsPhonePh;

  /// settings.photoChangeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim ändern des Passbildes, versuche es später erneut'**
  String get settingsPhotoChangeFailed;

  /// settings.photoChanged
  ///
  /// In de, this message translates to:
  /// **'Das Passbild wurde erfolgreich geändert.'**
  String get settingsPhotoChanged;

  /// settings.photoRemoveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Entfernen des Passbildes, versuche es später erneut'**
  String get settingsPhotoRemoveFailed;

  /// settings.photoRemoved
  ///
  /// In de, this message translates to:
  /// **'Das Passbild wurde erfolgreich entfernt'**
  String get settingsPhotoRemoved;

  /// settings.planning
  ///
  /// In de, this message translates to:
  /// **'Planung'**
  String get settingsPlanning;

  /// settings.pleaseSelect
  ///
  /// In de, this message translates to:
  /// **'Bitte auswählen'**
  String get settingsPleaseSelect;

  /// settings.profilePicture
  ///
  /// In de, this message translates to:
  /// **'Profilbild'**
  String get settingsProfilePicture;

  /// settings.profileUpdated
  ///
  /// In de, this message translates to:
  /// **'Die Profildaten wurden erfolgreich aktualisiert.'**
  String get settingsProfileUpdated;

  /// settings.questionFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Senden der Anfrage: {error}'**
  String settingsQuestionFailed(Object error);

  /// settings.questionSent
  ///
  /// In de, this message translates to:
  /// **'Deine Anfrage wurde erfolgreich gesendet. Wir melden uns so schnell wie möglich bei dir.'**
  String get settingsQuestionSent;

  /// settings.ratingRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte gib eine Bewertung ab.'**
  String get settingsRatingRequired;

  /// settings.removeAdmin
  ///
  /// In de, this message translates to:
  /// **'Admin entfernen?'**
  String get settingsRemoveAdmin;

  /// settings.removeMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du {name} wirklich entfernen?'**
  String settingsRemoveMessage(Object name);

  /// settings.removeParent
  ///
  /// In de, this message translates to:
  /// **'Elternteil entfernen?'**
  String get settingsRemoveParent;

  /// settings.removePhoto
  ///
  /// In de, this message translates to:
  /// **'Passbild entfernen'**
  String get settingsRemovePhoto;

  /// settings.removePhotoConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du dein Passbild wirklich entfernen?'**
  String get settingsRemovePhotoConfirm;

  /// settings.removeViewer
  ///
  /// In de, this message translates to:
  /// **'Beobachter entfernen?'**
  String get settingsRemoveViewer;

  /// settings.removingTenant
  ///
  /// In de, this message translates to:
  /// **'Instanz wird entfernt...'**
  String get settingsRemovingTenant;

  /// settings.repeatPasswordPh
  ///
  /// In de, this message translates to:
  /// **'Passwort wiederholen...'**
  String get settingsRepeatPasswordPh;

  /// settings.replacePhoto
  ///
  /// In de, this message translates to:
  /// **'Passbild ersetzen'**
  String get settingsReplacePhoto;

  /// settings.rolesPerms
  ///
  /// In de, this message translates to:
  /// **'Rollen & Berechtigungen'**
  String get settingsRolesPerms;

  /// settings.runSheets
  ///
  /// In de, this message translates to:
  /// **'Ablaufpläne'**
  String get settingsRunSheets;

  /// settings.searchChurch
  ///
  /// In de, this message translates to:
  /// **'Gemeinde suchen'**
  String get settingsSearchChurch;

  /// settings.selectGroups
  ///
  /// In de, this message translates to:
  /// **'Gruppen auswählen'**
  String get settingsSelectGroups;

  /// settings.selectOneGroup
  ///
  /// In de, this message translates to:
  /// **'Bitte mindestens eine Gruppe auswählen.'**
  String get settingsSelectOneGroup;

  /// settings.settings
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settingsSettings;

  /// settings.songs
  ///
  /// In de, this message translates to:
  /// **'Werke'**
  String get settingsSongs;

  /// settings.songsRehearsals
  ///
  /// In de, this message translates to:
  /// **'Werke & Proben'**
  String get settingsSongsRehearsals;

  /// settings.submit
  ///
  /// In de, this message translates to:
  /// **'Absenden'**
  String get settingsSubmit;

  /// settings.subscribeCalendar
  ///
  /// In de, this message translates to:
  /// **'Kalender abonnieren'**
  String get settingsSubscribeCalendar;

  /// settings.switchTenant
  ///
  /// In de, this message translates to:
  /// **'Instanz wechseln'**
  String get settingsSwitchTenant;

  /// settings.system
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// settings.teachers
  ///
  /// In de, this message translates to:
  /// **'Lehrer'**
  String get settingsTeachers;

  /// settings.templatesFields
  ///
  /// In de, this message translates to:
  /// **'Planvorlagen & Felder'**
  String get settingsTemplatesFields;

  /// settings.tenantAdmin
  ///
  /// In de, this message translates to:
  /// **'Instanz-Verwaltung'**
  String get settingsTenantAdmin;

  /// settings.tenantNamePh
  ///
  /// In de, this message translates to:
  /// **'Name der Instanz eingeben...'**
  String get settingsTenantNamePh;

  /// settings.tenantSelectHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn diese Option aktiv ist, wirst du vor dem Öffnen der App immer gefragt, welche Instanz du öffnen möchtest.'**
  String get settingsTenantSelectHelper;

  /// settings.tenantsCount
  ///
  /// In de, this message translates to:
  /// **'Instanzen ({count})'**
  String settingsTenantsCount(Object count);

  /// settings.userCreated
  ///
  /// In de, this message translates to:
  /// **'Der Benutzer wurde erfolgreich angelegt.'**
  String get settingsUserCreated;

  /// settings.usersRoles
  ///
  /// In de, this message translates to:
  /// **'Benutzer & Rollen'**
  String get settingsUsersRoles;

  /// settings.viewPhoto
  ///
  /// In de, this message translates to:
  /// **'Passbild ansehen'**
  String get settingsViewPhoto;

  /// settings.viewers
  ///
  /// In de, this message translates to:
  /// **'Beobachter'**
  String get settingsViewers;

  /// settings.viewersHint
  ///
  /// In de, this message translates to:
  /// **'Beobachter haben nur Leserechte auf Anwesenheitsübersicht und Personendaten.'**
  String get settingsViewersHint;

  /// settings.voiceLeader
  ///
  /// In de, this message translates to:
  /// **'Stimmführer'**
  String get settingsVoiceLeader;

  /// settings.waitingApproval
  ///
  /// In de, this message translates to:
  /// **'Personen warten auf Genehmigung'**
  String get settingsWaitingApproval;

  /// settings.whatsNew
  ///
  /// In de, this message translates to:
  /// **'Was ist neu?'**
  String get settingsWhatsNew;

  /// settings.wrongName
  ///
  /// In de, this message translates to:
  /// **'Der eingegebene Name ist nicht korrekt.'**
  String get settingsWrongName;

  /// settings.yourFeedback
  ///
  /// In de, this message translates to:
  /// **'Dein Feedback'**
  String get settingsYourFeedback;

  /// settings.yourMobileOptional
  ///
  /// In de, this message translates to:
  /// **'Deine Handynummer (optional)'**
  String get settingsYourMobileOptional;

  /// settings.yourQuestion
  ///
  /// In de, this message translates to:
  /// **'Deine Frage'**
  String get settingsYourQuestion;

  /// settings.yourQuestionPh
  ///
  /// In de, this message translates to:
  /// **'Deine Frage eingeben...'**
  String get settingsYourQuestionPh;

  /// settings.yourRating
  ///
  /// In de, this message translates to:
  /// **'Deine Bewertung'**
  String get settingsYourRating;

  /// shifts.chooseTarget
  ///
  /// In de, this message translates to:
  /// **'Wähle die Ziel-Instanz, in die der Schichtplan kopiert werden soll.'**
  String get shiftsChooseTarget;

  /// shifts.computed
  ///
  /// In de, this message translates to:
  /// **'Berechnete Schichten'**
  String get shiftsComputed;

  /// shifts.computedLine
  ///
  /// In de, this message translates to:
  /// **'{start} - {end}, {hours} Stunden'**
  String shiftsComputedLine(Object start, Object end, Object hours);

  /// shifts.copied
  ///
  /// In de, this message translates to:
  /// **'Schichtplan nach „{tenant}“ kopiert.'**
  String shiftsCopied(Object tenant);

  /// shifts.copiedAssigned
  ///
  /// In de, this message translates to:
  /// **'Schichtplan nach „{tenant}“ kopiert und {count, plural, one {{count} Person} other {{count} Personen}} zugewiesen.'**
  String shiftsCopiedAssigned(Object tenant, num count);

  /// shifts.copiedNoMatch
  ///
  /// In de, this message translates to:
  /// **'Schichtplan nach „{tenant}“ kopiert. Keine passenden Personen in Ziel-Instanz gefunden.'**
  String shiftsCopiedNoMatch(Object tenant);

  /// shifts.copyAssignments
  ///
  /// In de, this message translates to:
  /// **'Zuweisungen kopieren?'**
  String get shiftsCopyAssignments;

  /// shifts.copyAssignmentsMessage
  ///
  /// In de, this message translates to:
  /// **'Der Schichtplan ist {count, plural, one {{count} Person} other {{count} Personen}} zugewiesen. Sollen diese Zuweisungen auch in „{tenant}“ übernommen werden?'**
  String shiftsCopyAssignmentsMessage(num count, Object tenant);

  /// shifts.copyFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Kopieren des Schichtplans.'**
  String get shiftsCopyFailed;

  /// shifts.copyFromOther
  ///
  /// In de, this message translates to:
  /// **'Schichtplan aus anderer Instanz übernehmen'**
  String get shiftsCopyFromOther;

  /// shifts.copyToTenant
  ///
  /// In de, this message translates to:
  /// **'In Instanz kopieren'**
  String get shiftsCopyToTenant;

  /// shifts.copying
  ///
  /// In de, this message translates to:
  /// **'Schichtplan wird kopiert...'**
  String get shiftsCopying;

  /// shifts.create
  ///
  /// In de, this message translates to:
  /// **'Schichtplan erstellen'**
  String get shiftsCreate;

  /// shifts.decimalHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn die Schichtdauer keine ganze Zahl ist, bitte Dezimalstellen mit Punkt angeben. (z.B. 8.5 für 8 1/2 Stunden)'**
  String get shiftsDecimalHelper;

  /// shifts.definition
  ///
  /// In de, this message translates to:
  /// **'Definition'**
  String get shiftsDefinition;

  /// shifts.delete
  ///
  /// In de, this message translates to:
  /// **'Schichtplan löschen'**
  String get shiftsDelete;

  /// shifts.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Schichtplans'**
  String get shiftsDeleteFailed;

  /// shifts.deleteMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du den Schichtplan wirklich löschen? Alle zugehörigen Schichten werden ebenfalls gelöscht. Personen, die diesem Schichtplan zugewiesen sind, verlieren ihre Zuordnung. Diese Aktion kann nicht rückgängig gemacht werden.'**
  String get shiftsDeleteMessage;

  /// shifts.deleted
  ///
  /// In de, this message translates to:
  /// **'Schichtplan gelöscht'**
  String get shiftsDeleted;

  /// shifts.deleting
  ///
  /// In de, this message translates to:
  /// **'Schichtplan wird gelöscht...'**
  String get shiftsDeleting;

  /// shifts.durationHours
  ///
  /// In de, this message translates to:
  /// **'Dauer (in Stunden)'**
  String get shiftsDurationHours;

  /// shifts.edit
  ///
  /// In de, this message translates to:
  /// **'Schichtplan anpassen'**
  String get shiftsEdit;

  /// shifts.editIntro
  ///
  /// In de, this message translates to:
  /// **'Füge hier die verschiedenen Schichten hinzu, aus denen sich der Schichtplan zusammensetzt. Jede Schicht entspricht einem Tag, an dem eine Person Schicht hat. Der Schichtplan beginnt wieder von vorne, wenn alle Schichten durchlaufen sind.'**
  String get shiftsEditIntro;

  /// shifts.enterName
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen Namen für den Schichtplan ein.'**
  String get shiftsEnterName;

  /// shifts.example
  ///
  /// In de, this message translates to:
  /// **'Beispiel-Rechnung'**
  String get shiftsExample;

  /// shifts.fixedIntro
  ///
  /// In de, this message translates to:
  /// **'Lege feste Schichten fest, die regelmäßig wiederkehren. Falls keine Schichten festgelegt sind, kann mein Zuweisen der Schicht einer Person, das Anfangsdatum festgelegt werden.'**
  String get shiftsFixedIntro;

  /// shifts.fixedOptional
  ///
  /// In de, this message translates to:
  /// **'Feste Schichten (optional)'**
  String get shiftsFixedOptional;

  /// shifts.flutter.addSegment
  ///
  /// In de, this message translates to:
  /// **'Segment hinzufügen'**
  String get shiftsFlutterAddSegment;

  /// shifts.flutter.addSegmentsHint
  ///
  /// In de, this message translates to:
  /// **'Füge Segmente hinzu, um die Vorschau zu sehen'**
  String get shiftsFlutterAddSegmentsHint;

  /// shifts.flutter.addShift
  ///
  /// In de, this message translates to:
  /// **'Schicht hinzufügen'**
  String get shiftsFlutterAddShift;

  /// shifts.flutter.assigningPeople
  ///
  /// In de, this message translates to:
  /// **'Weise {count} Personen zu...'**
  String shiftsFlutterAssigningPeople(Object count);

  /// shifts.flutter.copyAssignments
  ///
  /// In de, this message translates to:
  /// **'Zuweisungen kopieren'**
  String get shiftsFlutterCopyAssignments;

  /// shifts.flutter.copyAssignmentsHint
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Person nutzt} other {{count} Personen nutzen}} diesen Schichtplan. Versuche passende Personen in der Ziel-Instanz zuzuweisen.'**
  String shiftsFlutterCopyAssignmentsHint(num count);

  /// shifts.flutter.copyFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Kopieren: {error}'**
  String shiftsFlutterCopyFailedWith(Object error);

  /// shifts.flutter.copyInfo
  ///
  /// In de, this message translates to:
  /// **'Der Schichtplan \"{name}\" wird in die ausgewählte Instanz kopiert. Die Definition und feste Schichten werden übernommen.'**
  String shiftsFlutterCopyInfo(Object name);

  /// shifts.flutter.copyInfoAssignments
  ///
  /// In de, this message translates to:
  /// **'Zuweisungen werden anhand der App-ID (appId) der Personen gemappt.'**
  String get shiftsFlutterCopyInfoAssignments;

  /// shifts.flutter.copyingShort
  ///
  /// In de, this message translates to:
  /// **'Wird kopiert...'**
  String get shiftsFlutterCopyingShort;

  /// shifts.flutter.createFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen: {error}'**
  String shiftsFlutterCreateFailed(Object error);

  /// shifts.flutter.created
  ///
  /// In de, this message translates to:
  /// **'Schichtplan \"{name}\" erstellt'**
  String shiftsFlutterCreated(Object name);

  /// shifts.flutter.creatingPlan
  ///
  /// In de, this message translates to:
  /// **'Erstelle Schichtplan...'**
  String get shiftsFlutterCreatingPlan;

  /// shifts.flutter.cycle
  ///
  /// In de, this message translates to:
  /// **'Zyklus: {count} Tage'**
  String shiftsFlutterCycle(Object count);

  /// shifts.flutter.cycleDays
  ///
  /// In de, this message translates to:
  /// **'{count}-Tage-Zyklus'**
  String shiftsFlutterCycleDays(Object count);

  /// shifts.flutter.dayN
  ///
  /// In de, this message translates to:
  /// **'Tag {n}'**
  String shiftsFlutterDayN(Object n);

  /// shifts.flutter.deleteConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du diesen Schichtplan wirklich löschen?'**
  String get shiftsFlutterDeleteConfirm;

  /// shifts.flutter.deleteConfirmUsed
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Mitglied nutzen diesen Schichtplan.} other {{count} Mitglieder nutzen diesen Schichtplan.}} Möchtest du ihn trotzdem löschen?'**
  String shiftsFlutterDeleteConfirmUsed(num count);

  /// shifts.flutter.descriptionHint
  ///
  /// In de, this message translates to:
  /// **'z.B. Früh, Spät, Nacht'**
  String get shiftsFlutterDescriptionHint;

  /// shifts.flutter.durationHint
  ///
  /// In de, this message translates to:
  /// **'z.B. 8.0'**
  String get shiftsFlutterDurationHint;

  /// shifts.flutter.editSegment
  ///
  /// In de, this message translates to:
  /// **'Segment bearbeiten'**
  String get shiftsFlutterEditSegment;

  /// shifts.flutter.errorWith
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String shiftsFlutterErrorWith(Object error);

  /// shifts.flutter.firstSegment
  ///
  /// In de, this message translates to:
  /// **'Erstes Segment'**
  String get shiftsFlutterFirstSegment;

  /// shifts.flutter.fixedHint
  ///
  /// In de, this message translates to:
  /// **'Feste Schichten definieren konkrete Startdaten für den Schichtzyklus.'**
  String get shiftsFlutterFixedHint;

  /// shifts.flutter.fixedShifts
  ///
  /// In de, this message translates to:
  /// **'Feste Schichten'**
  String get shiftsFlutterFixedShifts;

  /// shifts.flutter.freeHint
  ///
  /// In de, this message translates to:
  /// **'Mitarbeiter ist an diesem Tag frei'**
  String get shiftsFlutterFreeHint;

  /// shifts.flutter.infoText
  ///
  /// In de, this message translates to:
  /// **'Schichtpläne ermöglichen automatische Entschuldigungen basierend auf Arbeitsschichten. Weise einem Mitglied einen Schichtplan zu, um Konflikte mit Terminen automatisch zu erkennen.'**
  String get shiftsFlutterInfoText;

  /// shifts.flutter.infoTitle
  ///
  /// In de, this message translates to:
  /// **'Automatische Entschuldigungen'**
  String get shiftsFlutterInfoTitle;

  /// shifts.flutter.labelHint
  ///
  /// In de, this message translates to:
  /// **'z.B. Frühdienst'**
  String get shiftsFlutterLabelHint;

  /// shifts.flutter.nameHint
  ///
  /// In de, this message translates to:
  /// **'z.B. 3-Schicht-System'**
  String get shiftsFlutterNameHint;

  /// shifts.flutter.next30From
  ///
  /// In de, this message translates to:
  /// **'Nächste 30 Tage ab {date}'**
  String shiftsFlutterNext30From(Object date);

  /// shifts.flutter.next30Today
  ///
  /// In de, this message translates to:
  /// **'Nächste 30 Tage ab heute'**
  String get shiftsFlutterNext30Today;

  /// shifts.flutter.noDefinition
  ///
  /// In de, this message translates to:
  /// **'Keine Definition'**
  String get shiftsFlutterNoDefinition;

  /// shifts.flutter.noDefinitionYet
  ///
  /// In de, this message translates to:
  /// **'Keine Definition vorhanden'**
  String get shiftsFlutterNoDefinitionYet;

  /// shifts.flutter.noFixed
  ///
  /// In de, this message translates to:
  /// **'Keine festen Schichten'**
  String get shiftsFlutterNoFixed;

  /// shifts.flutter.noSegments
  ///
  /// In de, this message translates to:
  /// **'Keine Schicht-Segmente definiert'**
  String get shiftsFlutterNoSegments;

  /// shifts.flutter.notFound
  ///
  /// In de, this message translates to:
  /// **'Schichtplan nicht gefunden'**
  String get shiftsFlutterNotFound;

  /// shifts.flutter.note
  ///
  /// In de, this message translates to:
  /// **'Hinweis'**
  String get shiftsFlutterNote;

  /// shifts.flutter.oneDay
  ///
  /// In de, this message translates to:
  /// **'1 Tag'**
  String get shiftsFlutterOneDay;

  /// shifts.flutter.plan
  ///
  /// In de, this message translates to:
  /// **'Schichtplan'**
  String get shiftsFlutterPlan;

  /// shifts.flutter.preview
  ///
  /// In de, this message translates to:
  /// **'Vorschau'**
  String get shiftsFlutterPreview;

  /// shifts.flutter.previewOf
  ///
  /// In de, this message translates to:
  /// **'Vorschau: {name}'**
  String shiftsFlutterPreviewOf(Object name);

  /// shifts.flutter.repeatTimes
  ///
  /// In de, this message translates to:
  /// **'{count}x wiederholen'**
  String shiftsFlutterRepeatTimes(Object count);

  /// shifts.flutter.repetitionsHint
  ///
  /// In de, this message translates to:
  /// **'Anzahl aufeinanderfolgender Tage'**
  String get shiftsFlutterRepetitionsHint;

  /// shifts.flutter.searchingPeople
  ///
  /// In de, this message translates to:
  /// **'Suche passende Personen in Ziel-Instanz...'**
  String get shiftsFlutterSearchingPeople;

  /// shifts.flutter.segments
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Segment} other {{count} Segmente}}'**
  String shiftsFlutterSegments(num count);

  /// shifts.flutter.shiftsCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Schicht} other {{count} Schichten}}'**
  String shiftsFlutterShiftsCount(num count);

  /// shifts.flutter.start
  ///
  /// In de, this message translates to:
  /// **'Start'**
  String get shiftsFlutterStart;

  /// shifts.flutter.startDateToday
  ///
  /// In de, this message translates to:
  /// **'Startdatum: Heute ({date})'**
  String shiftsFlutterStartDateToday(Object date);

  /// shifts.flutter.startDateWith
  ///
  /// In de, this message translates to:
  /// **'Startdatum: {date} ({name})'**
  String shiftsFlutterStartDateWith(Object date, Object name);

  /// shifts.flutter.targetTenant
  ///
  /// In de, this message translates to:
  /// **'Ziel-Instanz'**
  String get shiftsFlutterTargetTenant;

  /// shifts.flutter.usage
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Mitglied nutzen diesen Schichtplan} other {{count} Mitglieder nutzen diesen Schichtplan}}'**
  String shiftsFlutterUsage(num count);

  /// shifts.flutter.willCopy
  ///
  /// In de, this message translates to:
  /// **'Wird kopiert:'**
  String get shiftsFlutterWillCopy;

  /// shifts.free
  ///
  /// In de, this message translates to:
  /// **'Frei'**
  String get shiftsFree;

  /// shifts.important
  ///
  /// In de, this message translates to:
  /// **'WICHTIG: Die Anwesenheiten der Personen werden immer nach dem Anlegen einer neuen Anwesenheit und beim Zuweisen eines Schichtplans einer Person aktualisiert.'**
  String get shiftsImportant;

  /// shifts.intro
  ///
  /// In de, this message translates to:
  /// **'Pflege Schichtpläne um automatisiert Personen bei Anwesenheiten zu entschuldigen wenn diese aufgrund von Schichten nicht verfügbar sind. Du kannst verschiedene Schichtpläne anlegen und diese dann den Personen zuweisen. Personen werden nur dann als \"entschuldigt\" markiert, wenn sie einer Schicht zugewiesen sind und die Schicht zur Zeit des Termins stattfindet. Die Notiz \"Schichtbedingt\" wird dann automatisch bei der Anwesenheit hinzugefügt.'**
  String get shiftsIntro;

  /// shifts.label
  ///
  /// In de, this message translates to:
  /// **'Bezeichnung'**
  String get shiftsLabel;

  /// shifts.noOtherTenants
  ///
  /// In de, this message translates to:
  /// **'Keine anderen Instanzen verfügbar.'**
  String get shiftsNoOtherTenants;

  /// shifts.noShifts
  ///
  /// In de, this message translates to:
  /// **'Keine Schichten hinzugefügt.'**
  String get shiftsNoShifts;

  /// shifts.none
  ///
  /// In de, this message translates to:
  /// **'Keine Schichtpläne vorhanden.'**
  String get shiftsNone;

  /// shifts.onlyPlan
  ///
  /// In de, this message translates to:
  /// **'Nur Schichtplan'**
  String get shiftsOnlyPlan;

  /// shifts.plans
  ///
  /// In de, this message translates to:
  /// **'Schichtpläne'**
  String get shiftsPlans;

  /// shifts.repetitions
  ///
  /// In de, this message translates to:
  /// **'Wiederholungen'**
  String get shiftsRepetitions;

  /// shifts.repetitionsHelper
  ///
  /// In de, this message translates to:
  /// **'Anzahl der Wiederholungen dieser Schicht im Plan.'**
  String get shiftsRepetitionsHelper;

  /// shifts.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern des Schichtplans'**
  String get shiftsSaveFailed;

  /// shifts.saved
  ///
  /// In de, this message translates to:
  /// **'Schichtplan gespeichert'**
  String get shiftsSaved;

  /// shifts.section
  ///
  /// In de, this message translates to:
  /// **'Abschnitt {n}'**
  String shiftsSection(Object n);

  /// shifts.selectTenant
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle eine Instanz aus.'**
  String get shiftsSelectTenant;

  /// shifts.startDate
  ///
  /// In de, this message translates to:
  /// **'Anfangsdatum'**
  String get shiftsStartDate;

  /// shifts.startTime
  ///
  /// In de, this message translates to:
  /// **'Startzeit'**
  String get shiftsStartTime;

  /// shifts.warning
  ///
  /// In de, this message translates to:
  /// **'ACHTUNG: Das Ändern der Schichtdefinition kann zu Inkonsistenzen führen. Falls der Schichtplan bereits einer Person zugewiesen wurde, können feste Schichten nicht mehr geändert oder entfernt werden! Lege stattdessen einen neuen Schichtplan an.'**
  String get shiftsWarning;

  /// shifts.withAssignments
  ///
  /// In de, this message translates to:
  /// **'Mit Zuweisungen'**
  String get shiftsWithAssignments;

  /// signout.absenceDeleted
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit gelöscht'**
  String get signoutAbsenceDeleted;

  /// signout.absenceEntered
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit eingetragen'**
  String get signoutAbsenceEntered;

  /// signout.absenceEnteredCount
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit eingetragen ({count, plural, one {{count} Termin} other {{count} Termine}} entschuldigt)'**
  String signoutAbsenceEnteredCount(num count);

  /// signout.absenceTileSub
  ///
  /// In de, this message translates to:
  /// **'melden'**
  String get signoutAbsenceTileSub;

  /// signout.absenceTileTitle
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit'**
  String get signoutAbsenceTileTitle;

  /// signout.accept
  ///
  /// In de, this message translates to:
  /// **'Zusagen'**
  String get signoutAccept;

  /// signout.allCount
  ///
  /// In de, this message translates to:
  /// **'Alle {count}'**
  String signoutAllCount(Object count);

  /// signout.allDutiesFilled
  ///
  /// In de, this message translates to:
  /// **'Gerade sind alle Dienste besetzt. Danke!'**
  String get signoutAllDutiesFilled;

  /// signout.attendance
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit'**
  String get signoutAttendance;

  /// signout.attendancePercent
  ///
  /// In de, this message translates to:
  /// **'{perc}% Anwesenheit'**
  String signoutAttendancePercent(Object perc);

  /// signout.cannot
  ///
  /// In de, this message translates to:
  /// **'Kann nicht'**
  String get signoutCannot;

  /// signout.cannotAfterAll
  ///
  /// In de, this message translates to:
  /// **'Kann doch nicht'**
  String get signoutCannotAfterAll;

  /// signout.chooseEnd
  ///
  /// In de, this message translates to:
  /// **'Endtag wählen'**
  String get signoutChooseEnd;

  /// signout.chooseLyricsFor
  ///
  /// In de, this message translates to:
  /// **'Liedtext für {song} auswählen'**
  String signoutChooseLyricsFor(Object song);

  /// signout.chooseScoresFor
  ///
  /// In de, this message translates to:
  /// **'Noten für {song} auswählen'**
  String signoutChooseScoresFor(Object song);

  /// signout.chooseStart
  ///
  /// In de, this message translates to:
  /// **'Starttag wählen'**
  String get signoutChooseStart;

  /// signout.conductor
  ///
  /// In de, this message translates to:
  /// **'Dirigent: {name}'**
  String signoutConductor(Object name);

  /// signout.confirmPause
  ///
  /// In de, this message translates to:
  /// **'Pausieren bestätigen'**
  String get signoutConfirmPause;

  /// signout.confirmed
  ///
  /// In de, this message translates to:
  /// **'bestätigt'**
  String get signoutConfirmed;

  /// signout.current
  ///
  /// In de, this message translates to:
  /// **'Aktuell'**
  String get signoutCurrent;

  /// signout.currentSongs
  ///
  /// In de, this message translates to:
  /// **'Aktuelle Werke'**
  String get signoutCurrentSongs;

  /// signout.deadline
  ///
  /// In de, this message translates to:
  /// **'Anmeldefrist: {date} Uhr'**
  String signoutDeadline(Object date);

  /// signout.deadlinePassed
  ///
  /// In de, this message translates to:
  /// **'Anmeldefrist abgelaufen'**
  String get signoutDeadlinePassed;

  /// signout.decline
  ///
  /// In de, this message translates to:
  /// **'Absagen'**
  String get signoutDecline;

  /// signout.deleteAbsence
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit löschen'**
  String get signoutDeleteAbsence;

  /// signout.deleteAbsenceMessage
  ///
  /// In de, this message translates to:
  /// **'Soll die Abwesenheit gelöscht werden? Bereits entschuldigte Termine in diesem Zeitraum werden auf den Standardstatus des jeweiligen Termintyps zurückgesetzt.'**
  String get signoutDeleteAbsenceMessage;

  /// signout.description
  ///
  /// In de, this message translates to:
  /// **'Beschreibung'**
  String get signoutDescription;

  /// signout.downloadRecording
  ///
  /// In de, this message translates to:
  /// **'Aufnahme herunterladen'**
  String get signoutDownloadRecording;

  /// signout.downloadScores
  ///
  /// In de, this message translates to:
  /// **'Noten downloaden'**
  String get signoutDownloadScores;

  /// signout.dutiesThisMonth
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {Dienst} other {Dienste}} diesen Monat'**
  String signoutDutiesThisMonth(num count);

  /// signout.duty
  ///
  /// In de, this message translates to:
  /// **'Dienst'**
  String get signoutDuty;

  /// signout.dutyConfirmed
  ///
  /// In de, this message translates to:
  /// **'Danke, dein Dienst ist bestätigt 🙂'**
  String get signoutDutyConfirmed;

  /// signout.dutyFull
  ///
  /// In de, this message translates to:
  /// **'Jemand war schneller, der Dienst ist schon voll.'**
  String get signoutDutyFull;

  /// signout.dutyNotAllowed
  ///
  /// In de, this message translates to:
  /// **'Du kannst diesen Dienst nicht übernehmen.'**
  String get signoutDutyNotAllowed;

  /// signout.dutyOccupied
  ///
  /// In de, this message translates to:
  /// **'{occupied} von {required} besetzt'**
  String signoutDutyOccupied(Object occupied, Object required);

  /// signout.dutySignedUp
  ///
  /// In de, this message translates to:
  /// **'Danke, du bist eingetragen 🙂'**
  String get signoutDutySignedUp;

  /// signout.editNote
  ///
  /// In de, this message translates to:
  /// **'Notiz anpassen'**
  String get signoutEditNote;

  /// signout.editRegistrationFields
  ///
  /// In de, this message translates to:
  /// **'Anmeldefelder anpassen'**
  String get signoutEditRegistrationFields;

  /// signout.endPause
  ///
  /// In de, this message translates to:
  /// **'Pausierung beenden'**
  String get signoutEndPause;

  /// signout.endPauseMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du deine Pausierung wirklich beenden und wieder aktiv werden?'**
  String get signoutEndPauseMessage;

  /// signout.enterAbsence
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit eintragen'**
  String get signoutEnterAbsence;

  /// signout.enterLate
  ///
  /// In de, this message translates to:
  /// **'Verspätung eintragen'**
  String get signoutEnterLate;

  /// signout.enterNote
  ///
  /// In de, this message translates to:
  /// **'Gib hier deine Notiz ein'**
  String get signoutEnterNote;

  /// signout.files
  ///
  /// In de, this message translates to:
  /// **'Dateien'**
  String get signoutFiles;

  /// signout.fillField
  ///
  /// In de, this message translates to:
  /// **'Bitte \"{field}\" ausfüllen'**
  String signoutFillField(Object field);

  /// signout.fillRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte fülle alle Pflichtfelder aus'**
  String get signoutFillRequired;

  /// signout.flutter.absenceSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit konnte nicht gespeichert werden'**
  String get signoutFlutterAbsenceSaveFailed;

  /// signout.flutter.error
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String signoutFlutterError(Object error);

  /// signout.flutter.eventsCount
  ///
  /// In de, this message translates to:
  /// **'{count} Termine'**
  String signoutFlutterEventsCount(Object count);

  /// signout.flutter.fieldsSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Anmeldefelder konnten nicht gespeichert werden.'**
  String get signoutFlutterFieldsSaveFailed;

  /// signout.flutter.fileDownloadFailed
  ///
  /// In de, this message translates to:
  /// **'Datei konnte nicht heruntergeladen werden'**
  String get signoutFlutterFileDownloadFailed;

  /// signout.flutter.fileOpenFailed
  ///
  /// In de, this message translates to:
  /// **'Datei konnte nicht geöffnet werden'**
  String get signoutFlutterFileOpenFailed;

  /// signout.flutter.filesSkipped
  ///
  /// In de, this message translates to:
  /// **'{count} Datei(en) konnten nicht eingebunden werden.'**
  String signoutFlutterFilesSkipped(Object count);

  /// signout.flutter.linkOpenFailed
  ///
  /// In de, this message translates to:
  /// **'Link konnte nicht geöffnet werden'**
  String get signoutFlutterLinkOpenFailed;

  /// signout.flutter.noCurrentSongs
  ///
  /// In de, this message translates to:
  /// **'Keine aktuellen Werke'**
  String get signoutFlutterNoCurrentSongs;

  /// signout.flutter.noPerson
  ///
  /// In de, this message translates to:
  /// **'Für dein Konto wurde in dieser Instanz keine Person gefunden.'**
  String get signoutFlutterNoPerson;

  /// signout.flutter.noPrintableScores
  ///
  /// In de, this message translates to:
  /// **'Keine druckbaren Noten gefunden.'**
  String get signoutFlutterNoPrintableScores;

  /// signout.flutter.noteSaveFailed
  ///
  /// In de, this message translates to:
  /// **'Notiz konnte nicht gespeichert werden.'**
  String get signoutFlutterNoteSaveFailed;

  /// signout.flutter.printAllScores
  ///
  /// In de, this message translates to:
  /// **'Alle Noten drucken'**
  String get signoutFlutterPrintAllScores;

  /// signout.flutter.showAll
  ///
  /// In de, this message translates to:
  /// **'Alle {count} anzeigen'**
  String signoutFlutterShowAll(Object count);

  /// signout.flutter.showLess
  ///
  /// In de, this message translates to:
  /// **'Weniger anzeigen'**
  String get signoutFlutterShowLess;

  /// signout.flutter.signinFailed
  ///
  /// In de, this message translates to:
  /// **'Anmeldung fehlgeschlagen. Bitte versuche es erneut.'**
  String get signoutFlutterSigninFailed;

  /// signout.flutter.signoutFailed
  ///
  /// In de, this message translates to:
  /// **'Abmeldung fehlgeschlagen. Bitte versuche es erneut.'**
  String get signoutFlutterSignoutFailed;

  /// signout.flutter.switchTenantFailed
  ///
  /// In de, this message translates to:
  /// **'Instanz konnte nicht gewechselt werden'**
  String get signoutFlutterSwitchTenantFailed;

  /// signout.giveReason
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen Grund an!'**
  String get signoutGiveReason;

  /// signout.gladYouCome
  ///
  /// In de, this message translates to:
  /// **'Schön, dass du dabei bist 🙂'**
  String get signoutGladYouCome;

  /// signout.greeting
  ///
  /// In de, this message translates to:
  /// **'Shalom {name}!'**
  String signoutGreeting(Object name);

  /// signout.illTakeIt
  ///
  /// In de, this message translates to:
  /// **'Ich übernehme'**
  String get signoutIllTakeIt;

  /// signout.infos
  ///
  /// In de, this message translates to:
  /// **'Infos'**
  String get signoutInfos;

  /// signout.lastEventsStatus
  ///
  /// In de, this message translates to:
  /// **'Status der letzten Termine'**
  String get signoutLastEventsStatus;

  /// signout.lateButton
  ///
  /// In de, this message translates to:
  /// **'Verspätung'**
  String get signoutLateButton;

  /// signout.lateCount
  ///
  /// In de, this message translates to:
  /// **'{count}× zu spät'**
  String signoutLateCount(Object count);

  /// signout.legend
  ///
  /// In de, this message translates to:
  /// **'Legende'**
  String get signoutLegend;

  /// signout.legendAccepted
  ///
  /// In de, this message translates to:
  /// **'Zugesagt'**
  String get signoutLegendAccepted;

  /// signout.legendAcceptedPresent
  ///
  /// In de, this message translates to:
  /// **'Zugesagt / Anwesend'**
  String get signoutLegendAcceptedPresent;

  /// signout.legendLate
  ///
  /// In de, this message translates to:
  /// **'Verspätet'**
  String get signoutLegendLate;

  /// signout.legendLateReported
  ///
  /// In de, this message translates to:
  /// **'Verspätung gemeldet'**
  String get signoutLegendLateReported;

  /// signout.legendLateReportedExcused
  ///
  /// In de, this message translates to:
  /// **'Verspätung gemeldet (entschuldigt)'**
  String get signoutLegendLateReportedExcused;

  /// signout.listenRecording
  ///
  /// In de, this message translates to:
  /// **'Aufnahme anhören'**
  String get signoutListenRecording;

  /// signout.longAbsenceHint
  ///
  /// In de, this message translates to:
  /// **'Für längere Abwesenheiten empfiehlt sich die Pausieren-Funktion, damit du nicht in neuen Terminen erscheinst.'**
  String get signoutLongAbsenceHint;

  /// signout.moreEvents
  ///
  /// In de, this message translates to:
  /// **'Weitere Termine'**
  String get signoutMoreEvents;

  /// signout.moreOptions
  ///
  /// In de, this message translates to:
  /// **'Weitere Optionen'**
  String get signoutMoreOptions;

  /// signout.myDuties
  ///
  /// In de, this message translates to:
  /// **'Meine Dienste'**
  String get signoutMyDuties;

  /// signout.nextDuty
  ///
  /// In de, this message translates to:
  /// **'Nächster Dienst'**
  String get signoutNextDuty;

  /// signout.noActions
  ///
  /// In de, this message translates to:
  /// **'Für diesen Termin sind keine Aktionen verfügbar.'**
  String get signoutNoActions;

  /// signout.noEndDate
  ///
  /// In de, this message translates to:
  /// **'Kein Enddatum gewählt'**
  String get signoutNoEndDate;

  /// signout.noScoresForInstrument
  ///
  /// In de, this message translates to:
  /// **'Für dein Instrument sind leider keine Noten verfügbar.'**
  String get signoutNoScoresForInstrument;

  /// signout.noScoresFound
  ///
  /// In de, this message translates to:
  /// **'Keine Noten für dein Instrument gefunden.'**
  String get signoutNoScoresFound;

  /// signout.noSongActions
  ///
  /// In de, this message translates to:
  /// **'Für dieses Werk sind keine Aktionen verfügbar.'**
  String get signoutNoSongActions;

  /// signout.noteChip
  ///
  /// In de, this message translates to:
  /// **'Notiz: {note}'**
  String signoutNoteChip(Object note);

  /// signout.noteForSignin
  ///
  /// In de, this message translates to:
  /// **'Notiz für Anmeldung'**
  String get signoutNoteForSignin;

  /// signout.noteUpdated
  ///
  /// In de, this message translates to:
  /// **'Notiz erfolgreich aktualisiert.'**
  String get signoutNoteUpdated;

  /// signout.openAttachment
  ///
  /// In de, this message translates to:
  /// **'Anhang öffnen'**
  String get signoutOpenAttachment;

  /// signout.openDuties
  ///
  /// In de, this message translates to:
  /// **'Offene Dienste'**
  String get signoutOpenDuties;

  /// signout.openFiles
  ///
  /// In de, this message translates to:
  /// **'Dateiablage öffnen'**
  String get signoutOpenFiles;

  /// signout.openInTeam
  ///
  /// In de, this message translates to:
  /// **'offen im Team'**
  String get signoutOpenInTeam;

  /// signout.openNavigation
  ///
  /// In de, this message translates to:
  /// **'Navigation öffnen'**
  String get signoutOpenNavigation;

  /// signout.openScoreLink
  ///
  /// In de, this message translates to:
  /// **'Notenlink öffnen'**
  String get signoutOpenScoreLink;

  /// signout.past
  ///
  /// In de, this message translates to:
  /// **'Vergangen'**
  String get signoutPast;

  /// signout.pause
  ///
  /// In de, this message translates to:
  /// **'Pausieren'**
  String get signoutPause;

  /// signout.pauseReasonPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Warum möchtest du pausieren?'**
  String get signoutPauseReasonPlaceholder;

  /// signout.paused
  ///
  /// In de, this message translates to:
  /// **'Pausiert'**
  String get signoutPaused;

  /// signout.pausedUntil
  ///
  /// In de, this message translates to:
  /// **'Pausiert bis (optional)'**
  String get signoutPausedUntil;

  /// signout.plannedAbsences
  ///
  /// In de, this message translates to:
  /// **'Geplante Abwesenheiten'**
  String get signoutPlannedAbsences;

  /// signout.pleaseConfirm
  ///
  /// In de, this message translates to:
  /// **'Bitte bestätigen'**
  String get signoutPleaseConfirm;

  /// signout.printScores
  ///
  /// In de, this message translates to:
  /// **'Noten drucken'**
  String get signoutPrintScores;

  /// signout.printScoresFor
  ///
  /// In de, this message translates to:
  /// **'Noten für {song} drucken'**
  String signoutPrintScoresFor(Object song);

  /// signout.reactivate
  ///
  /// In de, this message translates to:
  /// **'Reaktivieren'**
  String get signoutReactivate;

  /// signout.reasonPlaceholder
  ///
  /// In de, this message translates to:
  /// **'z.B. Urlaub, Krankheit...'**
  String get signoutReasonPlaceholder;

  /// signout.reasonRequired
  ///
  /// In de, this message translates to:
  /// **'Grund *'**
  String get signoutReasonRequired;

  /// signout.registrationFieldsSaved
  ///
  /// In de, this message translates to:
  /// **'Anmeldefelder gespeichert.'**
  String get signoutRegistrationFieldsSaved;

  /// signout.registrationSubmitted
  ///
  /// In de, this message translates to:
  /// **'Deine Registrierung wurde erfolgreich übermittelt. Du wirst benachrichtigt, sobald diese bearbeitet wurde.'**
  String get signoutRegistrationSubmitted;

  /// signout.regularlyUnavailable
  ///
  /// In de, this message translates to:
  /// **'Regelmäßig verhindert'**
  String get signoutRegularlyUnavailable;

  /// signout.regularlyUnavailableHint
  ///
  /// In de, this message translates to:
  /// **'z. B. jeden Mittwoch wegen der Kinderstunde'**
  String get signoutRegularlyUnavailableHint;

  /// signout.reportAbsence
  ///
  /// In de, this message translates to:
  /// **'Abwesenheit melden'**
  String get signoutReportAbsence;

  /// signout.route
  ///
  /// In de, this message translates to:
  /// **'Route'**
  String get signoutRoute;

  /// signout.runSheet
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan'**
  String get signoutRunSheet;

  /// signout.showDescription
  ///
  /// In de, this message translates to:
  /// **'Beschreibung anzeigen'**
  String get signoutShowDescription;

  /// signout.showRunSheet
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan anzeigen'**
  String get signoutShowRunSheet;

  /// signout.showScores
  ///
  /// In de, this message translates to:
  /// **'Noten anzeigen'**
  String get signoutShowScores;

  /// signout.signIn
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get signoutSignIn;

  /// signout.signInWithNote
  ///
  /// In de, this message translates to:
  /// **'Anmelden mit Notiz'**
  String get signoutSignInWithNote;

  /// signout.signOut
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get signoutSignOut;

  /// signout.thanksLate
  ///
  /// In de, this message translates to:
  /// **'Vielen Dank für die Info und Gottes Segen dir!'**
  String get signoutThanksLate;

  /// signout.thanksSignout
  ///
  /// In de, this message translates to:
  /// **'Vielen Dank für deine rechtzeitige Abmeldung und Gottes Segen dir.'**
  String get signoutThanksSignout;

  /// signout.toConfirm
  ///
  /// In de, this message translates to:
  /// **'zu bestätigen'**
  String get signoutToConfirm;

  /// signout.undoSignout
  ///
  /// In de, this message translates to:
  /// **'Abmeldung zurücknehmen'**
  String get signoutUndoSignout;

  /// signout.upcoming
  ///
  /// In de, this message translates to:
  /// **'Anstehend'**
  String get signoutUpcoming;

  /// signout.urgent
  ///
  /// In de, this message translates to:
  /// **'Dringend'**
  String get signoutUrgent;

  /// signout.viewLyrics
  ///
  /// In de, this message translates to:
  /// **'Liedtext ansehen'**
  String get signoutViewLyrics;

  /// signout.withTeam
  ///
  /// In de, this message translates to:
  /// **' · mit {names}'**
  String signoutWithTeam(Object names);

  /// signout.you
  ///
  /// In de, this message translates to:
  /// **'Du'**
  String get signoutYou;

  /// signout.youAreAssigned
  ///
  /// In de, this message translates to:
  /// **'Du bist eingeteilt'**
  String get signoutYouAreAssigned;

  /// signout.yourDutyRoster
  ///
  /// In de, this message translates to:
  /// **'Dein Dienstplan'**
  String get signoutYourDutyRoster;

  /// songs.addCategory
  ///
  /// In de, this message translates to:
  /// **'Kategorie hinzufügen'**
  String get songsAddCategory;

  /// songs.addSong
  ///
  /// In de, this message translates to:
  /// **'Werk hinzufügen'**
  String get songsAddSong;

  /// songs.addWithoutReplace
  ///
  /// In de, this message translates to:
  /// **'Ohne Ersetzen hinzufügen'**
  String get songsAddWithoutReplace;

  /// songs.allSongs
  ///
  /// In de, this message translates to:
  /// **'Alle Werke'**
  String get songsAllSongs;

  /// songs.catalogPdf
  ///
  /// In de, this message translates to:
  /// **'Werkverzeichnis als PDF'**
  String get songsCatalogPdf;

  /// songs.catalogTitle
  ///
  /// In de, this message translates to:
  /// **'{tenant} Werkverzeichnis'**
  String songsCatalogTitle(Object tenant);

  /// songs.categories
  ///
  /// In de, this message translates to:
  /// **'Kategorien'**
  String get songsCategories;

  /// songs.categoryAdded
  ///
  /// In de, this message translates to:
  /// **'Kategorie hinzugefügt'**
  String get songsCategoryAdded;

  /// songs.categoryDeleted
  ///
  /// In de, this message translates to:
  /// **'Kategorie gelöscht'**
  String get songsCategoryDeleted;

  /// songs.categoryName
  ///
  /// In de, this message translates to:
  /// **'Name der Kategorie'**
  String get songsCategoryName;

  /// songs.categoryNameEmpty
  ///
  /// In de, this message translates to:
  /// **'Der Name der Kategorie darf nicht leer sein'**
  String get songsCategoryNameEmpty;

  /// songs.categorySaved
  ///
  /// In de, this message translates to:
  /// **'Kategorie gespeichert'**
  String get songsCategorySaved;

  /// songs.changeCategory
  ///
  /// In de, this message translates to:
  /// **'Kategorie ändern'**
  String get songsChangeCategory;

  /// songs.choir
  ///
  /// In de, this message translates to:
  /// **'Chor'**
  String get songsChoir;

  /// songs.choirOrchShort
  ///
  /// In de, this message translates to:
  /// **'Chor/Orch.'**
  String get songsChoirOrchShort;

  /// songs.choirOrchestra
  ///
  /// In de, this message translates to:
  /// **'Chor & Orchester'**
  String get songsChoirOrchestra;

  /// songs.chooseGroup
  ///
  /// In de, this message translates to:
  /// **'Gruppe wählen'**
  String get songsChooseGroup;

  /// songs.chooseGroupPlease
  ///
  /// In de, this message translates to:
  /// **'Bitte eine Gruppe auswählen.'**
  String get songsChooseGroupPlease;

  /// songs.chooseGroups
  ///
  /// In de, this message translates to:
  /// **'Gruppen wählen'**
  String get songsChooseGroups;

  /// songs.conductors
  ///
  /// In de, this message translates to:
  /// **'Dirigenten'**
  String get songsConductors;

  /// songs.copied
  ///
  /// In de, this message translates to:
  /// **'Werk wurde erfolgreich kopiert'**
  String get songsCopied;

  /// songs.copiesPerGroup
  ///
  /// In de, this message translates to:
  /// **'Wie viele Ausdrucke pro Gruppe?'**
  String get songsCopiesPerGroup;

  /// songs.copy
  ///
  /// In de, this message translates to:
  /// **'Kopieren'**
  String get songsCopy;

  /// songs.copyFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Kopieren des Werks: {error}'**
  String songsCopyFailed(Object error);

  /// songs.copyInfo
  ///
  /// In de, this message translates to:
  /// **'Das Werk \"{name}\" wird in die ausgewählte Instanz kopiert. Alle Dateien werden ebenfalls kopiert. Die Kategorie wird nicht übernommen. Instrumentenzuordnungen werden automatisch anhand des Namens gemappt.'**
  String songsCopyInfo(Object name);

  /// songs.copyLink
  ///
  /// In de, this message translates to:
  /// **'Link kopieren'**
  String get songsCopyLink;

  /// songs.copySong
  ///
  /// In de, this message translates to:
  /// **'Werk kopieren'**
  String get songsCopySong;

  /// songs.copyToOther
  ///
  /// In de, this message translates to:
  /// **'Werk in andere Instanz kopieren'**
  String get songsCopyToOther;

  /// songs.copying
  ///
  /// In de, this message translates to:
  /// **'Werk wird kopiert...'**
  String get songsCopying;

  /// songs.copyingFile
  ///
  /// In de, this message translates to:
  /// **'Datei {current} von {total} wird kopiert...'**
  String songsCopyingFile(Object current, Object total);

  /// songs.creatingPdf
  ///
  /// In de, this message translates to:
  /// **'PDF wird erstellt...'**
  String get songsCreatingPdf;

  /// songs.current
  ///
  /// In de, this message translates to:
  /// **'Aktuelle Werke'**
  String get songsCurrent;

  /// songs.deleteAll
  ///
  /// In de, this message translates to:
  /// **'Alle Dateien löschen'**
  String get songsDeleteAll;

  /// songs.deleteAllConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchten Sie wirklich alle Dateien dieses Werks löschen?'**
  String get songsDeleteAllConfirm;

  /// songs.deleteCategory
  ///
  /// In de, this message translates to:
  /// **'Kategorie löschen'**
  String get songsDeleteCategory;

  /// songs.deleteCategoryMessage
  ///
  /// In de, this message translates to:
  /// **'Möchten Sie diese Kategorie wirklich löschen? Alle Werke in dieser Kategorie werden keiner neuen Kategorie zugewiesen.'**
  String get songsDeleteCategoryMessage;

  /// songs.deleteConfirm
  ///
  /// In de, this message translates to:
  /// **'Soll das Werk wirklich gelöscht werden?'**
  String get songsDeleteConfirm;

  /// songs.deleteFile
  ///
  /// In de, this message translates to:
  /// **'Datei löschen'**
  String get songsDeleteFile;

  /// songs.deleteFileConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchten Sie die Datei \"{name}\" wirklich löschen?'**
  String songsDeleteFileConfirm(Object name);

  /// songs.deleteSong
  ///
  /// In de, this message translates to:
  /// **'Werk löschen'**
  String get songsDeleteSong;

  /// songs.deleteSyncedMessage
  ///
  /// In de, this message translates to:
  /// **'Die Werke werden mit {names} geteilt. Das Werk wird dort ebenfalls gelöscht, inklusive der Historie aller beteiligten Instanzen. Soll das Werk wirklich gelöscht werden?'**
  String songsDeleteSyncedMessage(Object names);

  /// songs.deleting
  ///
  /// In de, this message translates to:
  /// **'Werk wird gelöscht...'**
  String get songsDeleting;

  /// songs.deletingFiles
  ///
  /// In de, this message translates to:
  /// **'Dateien werden gelöscht...'**
  String get songsDeletingFiles;

  /// songs.difficulty
  ///
  /// In de, this message translates to:
  /// **'Schwierigkeitsgrad'**
  String get songsDifficulty;

  /// songs.difficulty123
  ///
  /// In de, this message translates to:
  /// **'Schwierigkeit (1/2/3)'**
  String get songsDifficulty123;

  /// songs.difficultyShort
  ///
  /// In de, this message translates to:
  /// **'Schwierigkeit'**
  String get songsDifficultyShort;

  /// songs.dontClose
  ///
  /// In de, this message translates to:
  /// **'Bitte das Fenster nicht schließen, bis der Upload abgeschlossen ist.'**
  String get songsDontClose;

  /// songs.downloadAll
  ///
  /// In de, this message translates to:
  /// **'Alle Dateien herunterladen'**
  String get songsDownloadAll;

  /// songs.downloadFile
  ///
  /// In de, this message translates to:
  /// **'Datei herunterladen'**
  String get songsDownloadFile;

  /// songs.downloadRecording
  ///
  /// In de, this message translates to:
  /// **'Aufnahme herunterladen'**
  String get songsDownloadRecording;

  /// songs.downloadingFiles
  ///
  /// In de, this message translates to:
  /// **'Dateien werden heruntergeladen...'**
  String get songsDownloadingFiles;

  /// songs.dropHere
  ///
  /// In de, this message translates to:
  /// **'Dateien hierher ziehen oder tippen zum Auswählen'**
  String get songsDropHere;

  /// songs.easy
  ///
  /// In de, this message translates to:
  /// **'1 - Leicht'**
  String get songsEasy;

  /// songs.editCategory
  ///
  /// In de, this message translates to:
  /// **'Kategorie bearbeiten'**
  String get songsEditCategory;

  /// songs.editSong
  ///
  /// In de, this message translates to:
  /// **'Werk bearbeiten'**
  String get songsEditSong;

  /// songs.enterCategory
  ///
  /// In de, this message translates to:
  /// **'Kategorie eingeben...'**
  String get songsEnterCategory;

  /// songs.every2
  ///
  /// In de, this message translates to:
  /// **'Jede 2. Person'**
  String get songsEvery2;

  /// songs.every3
  ///
  /// In de, this message translates to:
  /// **'Jede 3. Person'**
  String get songsEvery3;

  /// songs.every4
  ///
  /// In de, this message translates to:
  /// **'Jede 4. Person'**
  String get songsEvery4;

  /// songs.fileActions
  ///
  /// In de, this message translates to:
  /// **'Datei Aktionen'**
  String get songsFileActions;

  /// songs.fileTooLarge
  ///
  /// In de, this message translates to:
  /// **'Die Datei {name} überschreitet die maximale Größe von 20MB.'**
  String songsFileTooLarge(Object name);

  /// songs.files
  ///
  /// In de, this message translates to:
  /// **'Dateien'**
  String get songsFiles;

  /// songs.flutter.copiesCount
  ///
  /// In de, this message translates to:
  /// **'{count} Kopien'**
  String songsFlutterCopiesCount(Object count);

  /// songs.flutter.copiesPerInstrument
  ///
  /// In de, this message translates to:
  /// **'Kopien pro Instrument:'**
  String get songsFlutterCopiesPerInstrument;

  /// songs.flutter.createFailed
  ///
  /// In de, this message translates to:
  /// **'Werk konnte nicht erstellt werden'**
  String get songsFlutterCreateFailed;

  /// songs.flutter.creatingInTarget
  ///
  /// In de, this message translates to:
  /// **'Erstelle Werk in Ziel-Instanz...'**
  String get songsFlutterCreatingInTarget;

  /// songs.flutter.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Werk konnte nicht gelöscht werden'**
  String get songsFlutterDeleteFailed;

  /// songs.flutter.detectNone
  ///
  /// In de, this message translates to:
  /// **'Nicht erkannt – bitte zuordnen'**
  String get songsFlutterDetectNone;

  /// songs.flutter.detectUnsure
  ///
  /// In de, this message translates to:
  /// **'Unsicher erkannt – bitte prüfen'**
  String get songsFlutterDetectUnsure;

  /// songs.flutter.downloadFileFailed
  ///
  /// In de, this message translates to:
  /// **'Datei konnte nicht heruntergeladen werden'**
  String get songsFlutterDownloadFileFailed;

  /// songs.flutter.errorWith
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String songsFlutterErrorWith(Object error);

  /// songs.flutter.fileDownloadFailed
  ///
  /// In de, this message translates to:
  /// **'Datei konnte nicht heruntergeladen werden: {name}'**
  String songsFlutterFileDownloadFailed(Object name);

  /// songs.flutter.filesSkipped
  ///
  /// In de, this message translates to:
  /// **'{count} Datei(en) konnten nicht eingebunden werden.'**
  String songsFlutterFilesSkipped(Object count);

  /// songs.flutter.filesWillBeCopied
  ///
  /// In de, this message translates to:
  /// **'{count} Dateien werden kopiert:'**
  String songsFlutterFilesWillBeCopied(Object count);

  /// songs.flutter.filterAndView
  ///
  /// In de, this message translates to:
  /// **'Filter & Ansicht'**
  String get songsFlutterFilterAndView;

  /// songs.flutter.firstPage
  ///
  /// In de, this message translates to:
  /// **'Erste Seite'**
  String get songsFlutterFirstPage;

  /// songs.flutter.fullscreen
  ///
  /// In de, this message translates to:
  /// **'Vollbild'**
  String get songsFlutterFullscreen;

  /// songs.flutter.hideTab
  ///
  /// In de, this message translates to:
  /// **'Tab ausblenden'**
  String get songsFlutterHideTab;

  /// songs.flutter.invalidId
  ///
  /// In de, this message translates to:
  /// **'Ungültige Werk-ID'**
  String get songsFlutterInvalidId;

  /// songs.flutter.lastPage
  ///
  /// In de, this message translates to:
  /// **'Letzte Seite'**
  String get songsFlutterLastPage;

  /// songs.flutter.learnFailed
  ///
  /// In de, this message translates to:
  /// **'Die Begriffe konnten nicht gemerkt werden'**
  String get songsFlutterLearnFailed;

  /// songs.flutter.learnTerm
  ///
  /// In de, this message translates to:
  /// **'„{term}“ künftig als {group} erkennen'**
  String songsFlutterLearnTerm(Object term, Object group);

  /// songs.flutter.listAnd
  ///
  /// In de, this message translates to:
  /// **'{rest} und {last}'**
  String songsFlutterListAnd(Object rest, Object last);

  /// songs.flutter.loadingTargetGroups
  ///
  /// In de, this message translates to:
  /// **'Lade Ziel-Instrumente...'**
  String get songsFlutterLoadingTargetGroups;

  /// songs.flutter.menu
  ///
  /// In de, this message translates to:
  /// **'Menü'**
  String get songsFlutterMenu;

  /// songs.flutter.nextPage
  ///
  /// In de, this message translates to:
  /// **'Nächste Seite'**
  String get songsFlutterNextPage;

  /// songs.flutter.noPlayers
  ///
  /// In de, this message translates to:
  /// **'Keine Spieler gefunden'**
  String get songsFlutterNoPlayers;

  /// songs.flutter.noSongs
  ///
  /// In de, this message translates to:
  /// **'Keine Werke vorhanden'**
  String get songsFlutterNoSongs;

  /// songs.flutter.notFound
  ///
  /// In de, this message translates to:
  /// **'Werk nicht gefunden'**
  String get songsFlutterNotFound;

  /// songs.flutter.oneEach
  ///
  /// In de, this message translates to:
  /// **'Je 1'**
  String get songsFlutterOneEach;

  /// songs.flutter.openFileFailed
  ///
  /// In de, this message translates to:
  /// **'Konnte Datei nicht öffnen'**
  String get songsFlutterOpenFileFailed;

  /// songs.flutter.pdfCreateFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen der PDF: {error}'**
  String songsFlutterPdfCreateFailed(Object error);

  /// songs.flutter.pdfLoadFailed
  ///
  /// In de, this message translates to:
  /// **'PDF konnte nicht geladen werden'**
  String get songsFlutterPdfLoadFailed;

  /// songs.flutter.pdfLoading
  ///
  /// In de, this message translates to:
  /// **'PDF wird geladen...'**
  String get songsFlutterPdfLoading;

  /// songs.flutter.pdfPagedMode
  ///
  /// In de, this message translates to:
  /// **'Seitenweise blättern'**
  String get songsFlutterPdfPagedMode;

  /// songs.flutter.pdfScrollMode
  ///
  /// In de, this message translates to:
  /// **'Durchgehend scrollen'**
  String get songsFlutterPdfScrollMode;

  /// songs.flutter.previousPage
  ///
  /// In de, this message translates to:
  /// **'Vorherige Seite'**
  String get songsFlutterPreviousPage;

  /// songs.flutter.printFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Drucken: {error}'**
  String songsFlutterPrintFailed(Object error);

  /// songs.flutter.printFileFailed
  ///
  /// In de, this message translates to:
  /// **'Datei konnte nicht gedruckt werden'**
  String get songsFlutterPrintFileFailed;

  /// songs.flutter.printJobSent
  ///
  /// In de, this message translates to:
  /// **'Druckauftrag gesendet'**
  String get songsFlutterPrintJobSent;

  /// songs.flutter.printing
  ///
  /// In de, this message translates to:
  /// **'Wird gedruckt...'**
  String get songsFlutterPrinting;

  /// songs.flutter.reorderCategoriesHint
  ///
  /// In de, this message translates to:
  /// **'Ziehe Kategorien um sie neu zu sortieren'**
  String get songsFlutterReorderCategoriesHint;

  /// songs.flutter.reviewHint
  ///
  /// In de, this message translates to:
  /// **'Bei diesen Dateien ist die Stimme nicht eindeutig. Bitte prüfe die Zuordnung vor dem Hochladen.'**
  String get songsFlutterReviewHint;

  /// songs.flutter.reviewTitle
  ///
  /// In de, this message translates to:
  /// **'Zuordnung prüfen'**
  String get songsFlutterReviewTitle;

  /// songs.flutter.reviewUpload
  ///
  /// In de, this message translates to:
  /// **'Hochladen'**
  String get songsFlutterReviewUpload;

  /// songs.flutter.showAsTab
  ///
  /// In de, this message translates to:
  /// **'Als Tab anzeigen'**
  String get songsFlutterShowAsTab;

  /// songs.flutter.song
  ///
  /// In de, this message translates to:
  /// **'Werk'**
  String get songsFlutterSong;

  /// songs.flutter.telegramSent
  ///
  /// In de, this message translates to:
  /// **'Datei per Telegram gesendet'**
  String get songsFlutterTelegramSent;

  /// songs.flutter.uploadFailedWith
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hochladen: {error}'**
  String songsFlutterUploadFailedWith(Object error);

  /// songs.flutter.visionReading
  ///
  /// In de, this message translates to:
  /// **'Erste Seite wird gelesen …'**
  String get songsFlutterVisionReading;

  /// songs.flutter.visionSure
  ///
  /// In de, this message translates to:
  /// **'Auf Seite 1 erkannt: {label}'**
  String songsFlutterVisionSure(Object label);

  /// songs.flutter.visionUnsure
  ///
  /// In de, this message translates to:
  /// **'Auf Seite 1 vermutet – bitte prüfen'**
  String get songsFlutterVisionUnsure;

  /// songs.freeText
  ///
  /// In de, this message translates to:
  /// **'Freitext'**
  String get songsFreeText;

  /// songs.group
  ///
  /// In de, this message translates to:
  /// **'Gruppe'**
  String get songsGroup;

  /// songs.groupDirectory
  ///
  /// In de, this message translates to:
  /// **'Gruppenverzeichnis'**
  String get songsGroupDirectory;

  /// songs.hard
  ///
  /// In de, this message translates to:
  /// **'3 - Schwer'**
  String get songsHard;

  /// songs.historyCount
  ///
  /// In de, this message translates to:
  /// **'Historie ({count}x)'**
  String songsHistoryCount(Object count);

  /// songs.importIntro
  ///
  /// In de, this message translates to:
  /// **'Importiere Werke aus einer Excel- (.xlsx/.xls) oder CSV-Datei. Die erste Zeile muss Spaltenüberschriften enthalten. Am einfachsten ist es, die Vorlage herunterzuladen und auszufüllen.'**
  String get songsImportIntro;

  /// songs.importSongs
  ///
  /// In de, this message translates to:
  /// **'Werke importieren'**
  String get songsImportSongs;

  /// songs.importantInfo
  ///
  /// In de, this message translates to:
  /// **'Wichtige Infos'**
  String get songsImportantInfo;

  /// songs.importedCount
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Werk importiert.} other {{count} Werke importiert.}}'**
  String songsImportedCount(num count);

  /// songs.instrument
  ///
  /// In de, this message translates to:
  /// **'Instrument'**
  String get songsInstrument;

  /// songs.instrumentation
  ///
  /// In de, this message translates to:
  /// **'Besetzung'**
  String get songsInstrumentation;

  /// songs.invalidLink
  ///
  /// In de, this message translates to:
  /// **'Der angegebene Link ist nicht valide'**
  String get songsInvalidLink;

  /// songs.invalidShareLink
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Freigabe-Link.'**
  String get songsInvalidShareLink;

  /// songs.lastPlayed
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gespielt'**
  String get songsLastPlayed;

  /// songs.lastPlayedOn
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gespielt am {date} | {conductor}'**
  String songsLastPlayedOn(Object date, Object conductor);

  /// songs.lastSung
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gesungen'**
  String get songsLastSung;

  /// songs.lastSungOn
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gesungen am {date} | {conductor}'**
  String songsLastSungOn(Object date, Object conductor);

  /// songs.link
  ///
  /// In de, this message translates to:
  /// **'Link'**
  String get songsLink;

  /// songs.linkCopied
  ///
  /// In de, this message translates to:
  /// **'Der Link wurde in die Zwischenablage kopiert'**
  String get songsLinkCopied;

  /// songs.lyrics
  ///
  /// In de, this message translates to:
  /// **'Liedtext'**
  String get songsLyrics;

  /// songs.lyricsWarning
  ///
  /// In de, this message translates to:
  /// **'Warnung: Liedtext-Format'**
  String get songsLyricsWarning;

  /// songs.lyricsWarningMessage
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Datei wurde} other {{count} Dateien wurden}} als \"Liedtext\" kategorisiert, {count, plural, one {ist aber keine PDF-Datei} other {sind aber keine PDF-Dateien}}. Die Spieler und Sänger können diese Dateien daher nicht in ihrer Übersicht bei den aktuellen Werken sehen.'**
  String songsLyricsWarningMessage(num count);

  /// songs.mapNumberName
  ///
  /// In de, this message translates to:
  /// **'Bitte Spalten für Nummer und Name zuordnen.'**
  String get songsMapNumberName;

  /// songs.mappingIntro
  ///
  /// In de, this message translates to:
  /// **'Ordne die Spalten deiner Datei den Werkfeldern zu. Nummer und Name sind erforderlich.'**
  String get songsMappingIntro;

  /// songs.medium
  ///
  /// In de, this message translates to:
  /// **'2 - Mittel'**
  String get songsMedium;

  /// songs.missingInstruments
  ///
  /// In de, this message translates to:
  /// **'Fehlende Instrumente'**
  String get songsMissingInstruments;

  /// songs.name
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get songsName;

  /// songs.nameAsc
  ///
  /// In de, this message translates to:
  /// **'Name ↑'**
  String get songsNameAsc;

  /// songs.nameDesc
  ///
  /// In de, this message translates to:
  /// **'Name ↓'**
  String get songsNameDesc;

  /// songs.noCategories
  ///
  /// In de, this message translates to:
  /// **'Es wurden noch keine Kategorien angelegt.'**
  String get songsNoCategories;

  /// songs.noCategory
  ///
  /// In de, this message translates to:
  /// **'Keine Kategorie'**
  String get songsNoCategory;

  /// songs.noFiles
  ///
  /// In de, this message translates to:
  /// **'Keine Dateien vorhanden.'**
  String get songsNoFiles;

  /// songs.noGroupPdfs
  ///
  /// In de, this message translates to:
  /// **'Keine Gruppen-PDFs zum Drucken gefunden'**
  String get songsNoGroupPdfs;

  /// songs.noGroupsWithPeople
  ///
  /// In de, this message translates to:
  /// **'Keine Gruppen mit zugewiesenen Personen gefunden'**
  String get songsNoGroupsWithPeople;

  /// songs.noScoresCurrent
  ///
  /// In de, this message translates to:
  /// **'Keine Noten für diese Gruppe in den aktuellen Werken gefunden.'**
  String get songsNoScoresCurrent;

  /// songs.noScoresGroup
  ///
  /// In de, this message translates to:
  /// **'Keine Noten für diese Gruppe vorhanden.'**
  String get songsNoScoresGroup;

  /// songs.notDefined
  ///
  /// In de, this message translates to:
  /// **'Nicht definiert'**
  String get songsNotDefined;

  /// songs.notImported
  ///
  /// In de, this message translates to:
  /// **'Nicht importierte Werke'**
  String get songsNotImported;

  /// songs.notPlayedYet
  ///
  /// In de, this message translates to:
  /// **'Noch nicht gespielt · '**
  String get songsNotPlayedYet;

  /// songs.notSungYet
  ///
  /// In de, this message translates to:
  /// **'Noch nicht gesungen · '**
  String get songsNotSungYet;

  /// songs.nothingToImport
  ///
  /// In de, this message translates to:
  /// **'Keine importierbaren Werke.'**
  String get songsNothingToImport;

  /// songs.number
  ///
  /// In de, this message translates to:
  /// **'Nummer'**
  String get songsNumber;

  /// songs.numberAsc
  ///
  /// In de, this message translates to:
  /// **'Nummer ↑'**
  String get songsNumberAsc;

  /// songs.numberDesc
  ///
  /// In de, this message translates to:
  /// **'Nummer ↓'**
  String get songsNumberDesc;

  /// songs.numberShort
  ///
  /// In de, this message translates to:
  /// **'Nr.'**
  String get songsNumberShort;

  /// songs.numberTaken
  ///
  /// In de, this message translates to:
  /// **'Die Liednummer ist bereits vergeben'**
  String get songsNumberTaken;

  /// songs.onlyGroupsWithFiles
  ///
  /// In de, this message translates to:
  /// **'Es werden nur Gruppen angezeigt, für die Dateien vorhanden sind.'**
  String get songsOnlyGroupsWithFiles;

  /// songs.openExternalLink
  ///
  /// In de, this message translates to:
  /// **'Externen Noten-Link öffnen'**
  String get songsOpenExternalLink;

  /// songs.openFile
  ///
  /// In de, this message translates to:
  /// **'Datei öffnen'**
  String get songsOpenFile;

  /// songs.orchestra
  ///
  /// In de, this message translates to:
  /// **'Orchester'**
  String get songsOrchestra;

  /// songs.other
  ///
  /// In de, this message translates to:
  /// **'Sonstige'**
  String get songsOther;

  /// songs.otherFreeText
  ///
  /// In de, this message translates to:
  /// **'Sonstige (Freitext)'**
  String get songsOtherFreeText;

  /// songs.perGroup
  ///
  /// In de, this message translates to:
  /// **'1 pro Gruppe'**
  String get songsPerGroup;

  /// songs.perPerson
  ///
  /// In de, this message translates to:
  /// **'Alle Personen (1 pro Person)'**
  String get songsPerPerson;

  /// songs.plannedOn
  ///
  /// In de, this message translates to:
  /// **'Geplant am {date}'**
  String songsPlannedOn(Object date);

  /// songs.playRecording
  ///
  /// In de, this message translates to:
  /// **'Aufnahme abspielen'**
  String get songsPlayRecording;

  /// songs.prefix
  ///
  /// In de, this message translates to:
  /// **'Präfix'**
  String get songsPrefix;

  /// songs.prefixHelper
  ///
  /// In de, this message translates to:
  /// **'Bspw. um Weihnachtslieder kennzeichnen zu können (z.B. W für Weihnachten -> W1)'**
  String get songsPrefixHelper;

  /// songs.prefixOptional
  ///
  /// In de, this message translates to:
  /// **'Präfix (optional)'**
  String get songsPrefixOptional;

  /// songs.print
  ///
  /// In de, this message translates to:
  /// **'Drucken'**
  String get songsPrint;

  /// songs.printFile
  ///
  /// In de, this message translates to:
  /// **'Datei drucken'**
  String get songsPrintFile;

  /// songs.printGroupPdfs
  ///
  /// In de, this message translates to:
  /// **'Gruppen-PDFs drucken'**
  String get songsPrintGroupPdfs;

  /// songs.printOptions
  ///
  /// In de, this message translates to:
  /// **'Druckoptionen'**
  String get songsPrintOptions;

  /// songs.printPrepared
  ///
  /// In de, this message translates to:
  /// **'Druck vorbereitet: {summary}'**
  String songsPrintPrepared(Object summary);

  /// songs.printScores
  ///
  /// In de, this message translates to:
  /// **'Noten drucken'**
  String get songsPrintScores;

  /// songs.recording
  ///
  /// In de, this message translates to:
  /// **'Aufnahme'**
  String get songsRecording;

  /// songs.replaceAndAdd
  ///
  /// In de, this message translates to:
  /// **'Ersetzen & Hinzufügen'**
  String get songsReplaceAndAdd;

  /// songs.replaces
  ///
  /// In de, this message translates to:
  /// **'Ersetzt: {name}'**
  String songsReplaces(Object name);

  /// songs.sendTelegram
  ///
  /// In de, this message translates to:
  /// **'Per Telegram senden'**
  String get songsSendTelegram;

  /// songs.sendingFile
  ///
  /// In de, this message translates to:
  /// **'Datei wird versendet...'**
  String get songsSendingFile;

  /// songs.showCurrent
  ///
  /// In de, this message translates to:
  /// **'Aktuelle Werke anzeigen'**
  String get songsShowCurrent;

  /// songs.solo
  ///
  /// In de, this message translates to:
  /// **'Solo'**
  String get songsSolo;

  /// songs.songCategories
  ///
  /// In de, this message translates to:
  /// **'Werk-Kategorien'**
  String get songsSongCategories;

  /// songs.songsCount
  ///
  /// In de, this message translates to:
  /// **'Werke ({count})'**
  String songsSongsCount(Object count);

  /// songs.sourceInstance
  ///
  /// In de, this message translates to:
  /// **'der Quellinstanz'**
  String get songsSourceInstance;

  /// songs.unknownCategory
  ///
  /// In de, this message translates to:
  /// **'Unbekannte Kategorie'**
  String get songsUnknownCategory;

  /// songs.upload
  ///
  /// In de, this message translates to:
  /// **'Hochladen'**
  String get songsUpload;

  /// songs.uploadAnyway
  ///
  /// In de, this message translates to:
  /// **'Trotzdem hochladen'**
  String get songsUploadAnyway;

  /// songs.uploadDone
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Datei erfolgreich hochgeladen.} other {{count} Dateien erfolgreich hochgeladen.}}'**
  String songsUploadDone(num count);

  /// songs.uploadFile
  ///
  /// In de, this message translates to:
  /// **'Datei hochladen'**
  String get songsUploadFile;

  /// songs.uploadFiles
  ///
  /// In de, this message translates to:
  /// **'Dateien hochladen'**
  String get songsUploadFiles;

  /// songs.uploadInfo
  ///
  /// In de, this message translates to:
  /// **'- Die Besetzung wird nach dem Hochladen automatisch anhand der ausgewählten Instrumente aktualisiert.<br>- Füge den Instrumenten Synonyme hinzu (<a href=\"/tabs/settings/instruments\">Gruppeneinstellungen</a>), um die automatische Zuordnung der Dateien zu verbessern.<br>- Beim Hochladen mehrerer Dateien kann es je nach Dateigröße und Internetverbindung einige Zeit dauern, bis alle Dateien vollständig hochgeladen sind. Bitte schließen Sie das Fenster nicht, bis der Upload abgeschlossen ist.'**
  String get songsUploadInfo;

  /// songs.uploadPartialFail
  ///
  /// In de, this message translates to:
  /// **'{failed} von {total} Datei(en) konnten nicht hochgeladen werden.'**
  String songsUploadPartialFail(Object failed, Object total);

  /// songs.uploadProgress
  ///
  /// In de, this message translates to:
  /// **'{done} von {total} Dateien hochgeladen'**
  String songsUploadProgress(Object done, Object total);

  /// songs.uploading
  ///
  /// In de, this message translates to:
  /// **'Datei wird hochgeladen...'**
  String get songsUploading;

  /// songs.whichReplace
  ///
  /// In de, this message translates to:
  /// **'Welche Dateien sollen ersetzt werden?'**
  String get songsWhichReplace;

  /// songs.withSolo
  ///
  /// In de, this message translates to:
  /// **'Mit Solo'**
  String get songsWithSolo;

  /// songs.withSoloSinging
  ///
  /// In de, this message translates to:
  /// **'Mit Solo-Gesang'**
  String get songsWithSoloSinging;

  /// stats.activeMembers
  ///
  /// In de, this message translates to:
  /// **'Aktive Mitglieder'**
  String get statsActiveMembers;

  /// stats.ageChart
  ///
  /// In de, this message translates to:
  /// **'Altersverteilung 🎂'**
  String get statsAgeChart;

  /// stats.ageDistribution
  ///
  /// In de, this message translates to:
  /// **'🎂 Altersverteilung'**
  String get statsAgeDistribution;

  /// stats.allCount
  ///
  /// In de, this message translates to:
  /// **'Alle ({count})'**
  String statsAllCount(Object count);

  /// stats.attendancePercent
  ///
  /// In de, this message translates to:
  /// **'Anwesenheit %'**
  String get statsAttendancePercent;

  /// stats.avgAgeChart
  ///
  /// In de, this message translates to:
  /// **'Durchschnittsalter pro Instrument'**
  String get statsAvgAgeChart;

  /// stats.avgAgeInstrument
  ///
  /// In de, this message translates to:
  /// **'📊 Durchschnittsalter pro Instrument'**
  String get statsAvgAgeInstrument;

  /// stats.avgAttendance
  ///
  /// In de, this message translates to:
  /// **'Ø Anwesenheit'**
  String get statsAvgAttendance;

  /// stats.best
  ///
  /// In de, this message translates to:
  /// **'Beste Anwesenheit'**
  String get statsBest;

  /// stats.count
  ///
  /// In de, this message translates to:
  /// **'Anzahl'**
  String get statsCount;

  /// stats.eventsInPeriod
  ///
  /// In de, this message translates to:
  /// **'Termine im Zeitraum'**
  String get statsEventsInPeriod;

  /// stats.filterTenants
  ///
  /// In de, this message translates to:
  /// **'Instanzen filtern'**
  String get statsFilterTenants;

  /// stats.flutter.absencesCount
  ///
  /// In de, this message translates to:
  /// **'{count} Fehlzeiten'**
  String statsFlutterAbsencesCount(Object count);

  /// stats.flutter.noBirthdays
  ///
  /// In de, this message translates to:
  /// **'Keine Geburtsdaten vorhanden'**
  String get statsFlutterNoBirthdays;

  /// stats.flutter.noData
  ///
  /// In de, this message translates to:
  /// **'Keine Daten verfügbar'**
  String get statsFlutterNoData;

  /// stats.flutter.noDataInPeriod
  ///
  /// In de, this message translates to:
  /// **'Keine Daten im ausgewählten Zeitraum'**
  String get statsFlutterNoDataInPeriod;

  /// stats.flutter.noUnexcused
  ///
  /// In de, this message translates to:
  /// **'Keine unentschuldigten Abwesenheiten'**
  String get statsFlutterNoUnexcused;

  /// stats.flutter.organisation
  ///
  /// In de, this message translates to:
  /// **'Organisation: {name}'**
  String statsFlutterOrganisation(Object name);

  /// stats.flutter.selectedOf
  ///
  /// In de, this message translates to:
  /// **'{selected} von {total} ausgewählt'**
  String statsFlutterSelectedOf(Object selected, Object total);

  /// stats.flutter.tenantsCount
  ///
  /// In de, this message translates to:
  /// **'{count} Instanzen'**
  String statsFlutterTenantsCount(Object count);

  /// stats.historyChart
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitsverlauf (letzte 20 Termine)'**
  String get statsHistoryChart;

  /// stats.instrumentChart
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitsquote nach Instrument'**
  String get statsInstrumentChart;

  /// stats.left
  ///
  /// In de, this message translates to:
  /// **'Ausgetreten'**
  String get statsLeft;

  /// stats.members
  ///
  /// In de, this message translates to:
  /// **'👥 Mitglieder'**
  String get statsMembers;

  /// stats.orgTenants
  ///
  /// In de, this message translates to:
  /// **'Instanzen der Organisation'**
  String get statsOrgTenants;

  /// stats.overview
  ///
  /// In de, this message translates to:
  /// **'📊 Anwesenheits-Übersicht'**
  String get statsOverview;

  /// stats.pausing
  ///
  /// In de, this message translates to:
  /// **'Pausierend'**
  String get statsPausing;

  /// stats.perInstrument
  ///
  /// In de, this message translates to:
  /// **'🎻 Anwesenheit pro Instrument'**
  String get statsPerInstrument;

  /// stats.period
  ///
  /// In de, this message translates to:
  /// **'📅 Zeitraum'**
  String get statsPeriod;

  /// stats.personCount
  ///
  /// In de, this message translates to:
  /// **'Anzahl Personen'**
  String get statsPersonCount;

  /// stats.personsAllTenants
  ///
  /// In de, this message translates to:
  /// **'Personen über alle Instanzen'**
  String get statsPersonsAllTenants;

  /// stats.personsCount
  ///
  /// In de, this message translates to:
  /// **'Personen ({count})'**
  String statsPersonsCount(Object count);

  /// stats.pieLabel
  ///
  /// In de, this message translates to:
  /// **'{label} ({perc}%)'**
  String statsPieLabel(Object label, Object perc);

  /// stats.statusChart
  ///
  /// In de, this message translates to:
  /// **'Statusverteilung (in %)'**
  String get statsStatusChart;

  /// stats.statusDistribution
  ///
  /// In de, this message translates to:
  /// **'📉 Statusverteilung'**
  String get statsStatusDistribution;

  /// stats.tenants
  ///
  /// In de, this message translates to:
  /// **'Instanzen'**
  String get statsTenants;

  /// stats.title
  ///
  /// In de, this message translates to:
  /// **'Statistiken'**
  String get statsTitle;

  /// stats.top20
  ///
  /// In de, this message translates to:
  /// **'🏆 Top 20 Anwesenheit'**
  String get statsTop20;

  /// stats.top20Chart
  ///
  /// In de, this message translates to:
  /// **'Top 20 - Anwesenheits-Elite 🏆'**
  String get statsTop20Chart;

  /// stats.trend
  ///
  /// In de, this message translates to:
  /// **'📈 Anwesenheits-Trend'**
  String get statsTrend;

  /// stats.unexcused
  ///
  /// In de, this message translates to:
  /// **'⚠️ Unentschuldigte Abwesenheiten'**
  String get statsUnexcused;

  /// stats.unexcusedAbsences
  ///
  /// In de, this message translates to:
  /// **'Unentschuldigte Abwesenheiten'**
  String get statsUnexcusedAbsences;

  /// stats.unexcusedChart
  ///
  /// In de, this message translates to:
  /// **'Unentschuldigte Fehlzeiten'**
  String get statsUnexcusedChart;

  /// stats.worst
  ///
  /// In de, this message translates to:
  /// **'Schlechteste Anwesenheit'**
  String get statsWorst;

  /// stats.years
  ///
  /// In de, this message translates to:
  /// **'Jahre'**
  String get statsYears;

  /// svc.activate
  ///
  /// In de, this message translates to:
  /// **'Aktivieren'**
  String get svcActivate;

  /// svc.addAttendanceFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen der Anwesenheit'**
  String get svcAddAttendanceFailed;

  /// svc.addCategoryFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen der Kategorie'**
  String get svcAddCategoryFailed;

  /// svc.addGroupCategoryFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim hinzufügen der Gruppenkategorie'**
  String get svcAddGroupCategoryFailed;

  /// svc.addPersonAttendancesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen der Person-Anwesenheiten'**
  String get svcAddPersonAttendancesFailed;

  /// svc.addShiftFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen der Schicht'**
  String get svcAddShiftFailed;

  /// svc.addSongCategoryFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim hinzufügen der Werkkategorie'**
  String get svcAddSongCategoryFailed;

  /// svc.addSongHistoryFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen der Lieder zur Historie'**
  String get svcAddSongHistoryFailed;

  /// svc.addTypeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen des Anwesenheitstyps'**
  String get svcAddTypeFailed;

  /// svc.addUserToTenantFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Hinzufügen des Benutzers zum Mandanten'**
  String get svcAddUserToTenantFailed;

  /// svc.applyToPlannedFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Übernehmen in geplante Termine'**
  String get svcApplyToPlannedFailed;

  /// svc.assignFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Einteilen'**
  String get svcAssignFailed;

  /// svc.checkShiftUsageFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Überprüfen der Schichtverwendung'**
  String get svcCheckShiftUsageFailed;

  /// svc.cleanupAttendancesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Bereinigen der Person-Anwesenheiten'**
  String get svcCleanupAttendancesFailed;

  /// svc.confirmFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Bestätigen'**
  String get svcConfirmFailed;

  /// svc.createChurchFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen der Kirche'**
  String get svcCreateChurchFailed;

  /// svc.createOrgFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen der Organisation'**
  String get svcCreateOrgFailed;

  /// svc.createPublicLinkFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen des öffentlichen Links'**
  String get svcCreatePublicLinkFailed;

  /// svc.createTenantFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen des Mandanten'**
  String get svcCreateTenantFailed;

  /// svc.deleteAbsenceFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen der Abwesenheit'**
  String get svcDeleteAbsenceFailed;

  /// svc.deleteCategoryFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen der Kategorie'**
  String get svcDeleteCategoryFailed;

  /// svc.deleteChurchFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen der Gemeinde'**
  String get svcDeleteChurchFailed;

  /// svc.deleteEntryFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Eintrags'**
  String get svcDeleteEntryFailed;

  /// svc.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen'**
  String get svcDeleteFailed;

  /// svc.deletePersonAttendanceFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen der Person-Anwesenheit'**
  String get svcDeletePersonAttendanceFailed;

  /// svc.deletePersonAttendancesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen der Person-Anwesenheiten'**
  String get svcDeletePersonAttendancesFailed;

  /// svc.deleteSharedFieldValuesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen der gemeinsamen Zusatzfeldwerte'**
  String get svcDeleteSharedFieldValuesFailed;

  /// svc.deleteShiftFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen der Schicht'**
  String get svcDeleteShiftFailed;

  /// svc.deleteSongFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Werks'**
  String get svcDeleteSongFailed;

  /// svc.deleteTenantFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Mandanten'**
  String get svcDeleteTenantFailed;

  /// svc.deleteTypeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Anwesenheitstyps'**
  String get svcDeleteTypeFailed;

  /// svc.fileLoading
  ///
  /// In de, this message translates to:
  /// **'Datei wird geladen...'**
  String get svcFileLoading;

  /// svc.folderIntoItself
  ///
  /// In de, this message translates to:
  /// **'Ordner kann nicht in sich selbst verschoben werden.'**
  String get svcFolderIntoItself;

  /// svc.invalidFileName
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Dateiname.'**
  String get svcInvalidFileName;

  /// svc.invalidFolderName
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Ordnername.'**
  String get svcInvalidFolderName;

  /// svc.invalidName
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Name.'**
  String get svcInvalidName;

  /// svc.later
  ///
  /// In de, this message translates to:
  /// **'Später'**
  String get svcLater;

  /// svc.linkFailed
  ///
  /// In de, this message translates to:
  /// **'Verknüpfung fehlgeschlagen'**
  String get svcLinkFailed;

  /// svc.linkOrgFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Verknüpfen der Organisation'**
  String get svcLinkOrgFailed;

  /// svc.linkPeopleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Verknüpfen der Personen'**
  String get svcLinkPeopleFailed;

  /// svc.loadAbsencesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Abwesenheiten'**
  String get svcLoadAbsencesFailed;

  /// svc.loadAdminsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Admins'**
  String get svcLoadAdminsFailed;

  /// svc.loadAttendancesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Anwesenheiten'**
  String get svcLoadAttendancesFailed;

  /// svc.loadAvailabilityFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Verfügbarkeit'**
  String get svcLoadAvailabilityFailed;

  /// svc.loadCategoriesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Kategorien'**
  String get svcLoadCategoriesFailed;

  /// svc.loadChurchesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Kirchen'**
  String get svcLoadChurchesFailed;

  /// svc.loadGroupMembersFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Gruppenmitglieder'**
  String get svcLoadGroupMembersFailed;

  /// svc.loadMainGroupPeopleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Hauptgruppen-Personen'**
  String get svcLoadMainGroupPeopleFailed;

  /// svc.loadOrgFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Organisation'**
  String get svcLoadOrgFailed;

  /// svc.loadOrgPlansFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Organisationspläne'**
  String get svcLoadOrgPlansFailed;

  /// svc.loadOrgsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Organisationen'**
  String get svcLoadOrgsFailed;

  /// svc.loadParentsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Elternteile'**
  String get svcLoadParentsFailed;

  /// svc.loadPersonAttendancesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Person-Anwesenheiten'**
  String get svcLoadPersonAttendancesFailed;

  /// svc.loadPlayersFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Spieler'**
  String get svcLoadPlayersFailed;

  /// svc.loadRolePermissionsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Rollenberechtigungen'**
  String get svcLoadRolePermissionsFailed;

  /// svc.loadSharedFieldsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der gemeinsamen Zusatzfelder'**
  String get svcLoadSharedFieldsFailed;

  /// svc.loadShiftPeopleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Personen mit Schicht'**
  String get svcLoadShiftPeopleFailed;

  /// svc.loadShiftsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Schichten'**
  String get svcLoadShiftsFailed;

  /// svc.loadTenantFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden des Mandanten'**
  String get svcLoadTenantFailed;

  /// svc.loadTenantFailed2
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden des Tenants'**
  String get svcLoadTenantFailed2;

  /// svc.loadTypesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Anwesenheitstypen'**
  String get svcLoadTypesFailed;

  /// svc.loadUsersFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Benutzer'**
  String get svcLoadUsersFailed;

  /// svc.loadViewersFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Beobachter'**
  String get svcLoadViewersFailed;

  /// svc.mergeScoresFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Zusammenführen der Noten.'**
  String get svcMergeScoresFailed;

  /// svc.mergingPdfs
  ///
  /// In de, this message translates to:
  /// **'PDFs werden zusammengeführt...'**
  String get svcMergingPdfs;

  /// svc.messageSent
  ///
  /// In de, this message translates to:
  /// **'Nachricht wurde erfolgreich gesendet!'**
  String get svcMessageSent;

  /// svc.noDeletePermission
  ///
  /// In de, this message translates to:
  /// **'Keine Berechtigung zum Löschen'**
  String get svcNoDeletePermission;

  /// svc.noPlayerFound
  ///
  /// In de, this message translates to:
  /// **'Es konnte kein Spieler gefunden werden.'**
  String get svcNoPlayerFound;

  /// svc.noPrintableScores
  ///
  /// In de, this message translates to:
  /// **'Keine druckbaren Noten (PDF/Bild) gefunden.'**
  String get svcNoPrintableScores;

  /// svc.notification
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigung'**
  String get svcNotification;

  /// svc.offlineSaved
  ///
  /// In de, this message translates to:
  /// **'Offline-Änderungen gespeichert'**
  String get svcOfflineSaved;

  /// svc.onlyOneMainGroup
  ///
  /// In de, this message translates to:
  /// **'Es kann nur eine Hauptgruppe existieren'**
  String get svcOnlyOneMainGroup;

  /// svc.orgNotFound
  ///
  /// In de, this message translates to:
  /// **'Organisation nicht gefunden'**
  String get svcOrgNotFound;

  /// svc.pdfDownloaded
  ///
  /// In de, this message translates to:
  /// **'PDF heruntergeladen - bitte manuell drucken'**
  String get svcPdfDownloaded;

  /// svc.pushPrompt
  ///
  /// In de, this message translates to:
  /// **'Möchtest du Push-Benachrichtigungen aktivieren? Du wirst über Termine, Checklisten und wichtige Ereignisse informiert.'**
  String get svcPushPrompt;

  /// svc.pushTitle
  ///
  /// In de, this message translates to:
  /// **'Push-Benachrichtigungen'**
  String get svcPushTitle;

  /// svc.removeOrgFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Entfernen der Organisation'**
  String get svcRemoveOrgFailed;

  /// svc.renameOrgFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Umbenennen der Organisation'**
  String get svcRenameOrgFailed;

  /// svc.revokePublicLinkFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Widerrufen des öffentlichen Links'**
  String get svcRevokePublicLinkFailed;

  /// svc.saveAbsenceFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern der Abwesenheit'**
  String get svcSaveAbsenceFailed;

  /// svc.saveBrandingFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern des Brandings'**
  String get svcSaveBrandingFailed;

  /// svc.saveDefaultFieldsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern der Standardfelder'**
  String get svcSaveDefaultFieldsFailed;

  /// svc.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern'**
  String get svcSaveFailed;

  /// svc.saveOrgFieldsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern der Organisations-Zusatzfelder'**
  String get svcSaveOrgFieldsFailed;

  /// svc.savePlanTemplatesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern der Planvorlagen'**
  String get svcSavePlanTemplatesFailed;

  /// svc.saveSharedFieldsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern der gemeinsamen Zusatzfelder'**
  String get svcSaveSharedFieldsFailed;

  /// svc.scores
  ///
  /// In de, this message translates to:
  /// **'Noten'**
  String get svcScores;

  /// svc.searchTargetPeopleFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Suchen der Personen in Ziel-Instanz'**
  String get svcSearchTargetPeopleFailed;

  /// svc.sendFeedbackFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Senden des Feedbacks'**
  String get svcSendFeedbackFailed;

  /// svc.sendMessageFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Senden der Nachricht, versuche es später erneut!'**
  String get svcSendMessageFailed;

  /// svc.sendQuestionFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Senden der Frage'**
  String get svcSendQuestionFailed;

  /// svc.show
  ///
  /// In de, this message translates to:
  /// **'Anzeigen'**
  String get svcShow;

  /// svc.signUpFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Eintragen'**
  String get svcSignUpFailed;

  /// svc.signedUrlFailed
  ///
  /// In de, this message translates to:
  /// **'Signed URL konnte nicht erzeugt werden.'**
  String get svcSignedUrlFailed;

  /// svc.transferAbsencesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Übertragen der Abwesenheiten'**
  String get svcTransferAbsencesFailed;

  /// svc.transferPersonAttendancesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Übertragen der Person-Anwesenheiten'**
  String get svcTransferPersonAttendancesFailed;

  /// svc.unassignFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Austragen'**
  String get svcUnassignFailed;

  /// svc.updateAttendanceFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim updaten der Anwesenheit'**
  String get svcUpdateAttendanceFailed;

  /// svc.updateCategoryFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Kategorie'**
  String get svcUpdateCategoryFailed;

  /// svc.updateCategoryOrderFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Kategoriereihenfolge'**
  String get svcUpdateCategoryOrderFailed;

  /// svc.updateChurchFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Gemeinde'**
  String get svcUpdateChurchFailed;

  /// svc.updateConfigFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Updaten der Konfiguration, bitte versuche es später erneut.'**
  String get svcUpdateConfigFailed;

  /// svc.updateEntryFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Updaten des Eintrags'**
  String get svcUpdateEntryFailed;

  /// svc.updateExtraFieldsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim updaten der Zusatzfelder'**
  String get svcUpdateExtraFieldsFailed;

  /// svc.updateFieldFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim updaten des Feldes'**
  String get svcUpdateFieldFailed;

  /// svc.updateGroupFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim updaten des Instruments'**
  String get svcUpdateGroupFailed;

  /// svc.updateRolePermissionFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Rollenberechtigung'**
  String get svcUpdateRolePermissionFailed;

  /// svc.updateSettingsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Einstellungen'**
  String get svcUpdateSettingsFailed;

  /// svc.updateShiftFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Schicht'**
  String get svcUpdateShiftFailed;

  /// svc.updateTenantDataFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren der Mandantendaten'**
  String get svcUpdateTenantDataFailed;

  /// svc.updateTenantUserFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren des Mandantenbenutzers'**
  String get svcUpdateTenantUserFailed;

  /// svc.updateTypeFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren des Anwesenheitstyps'**
  String get svcUpdateTypeFailed;

  /// tabs.dashboard
  ///
  /// In de, this message translates to:
  /// **'Dashboard'**
  String get tabsDashboard;

  /// tabs.events
  ///
  /// In de, this message translates to:
  /// **'Termine'**
  String get tabsEvents;

  /// tabs.members
  ///
  /// In de, this message translates to:
  /// **'Mitglieder'**
  String get tabsMembers;

  /// tabs.more
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get tabsMore;

  /// tabs.myEvents
  ///
  /// In de, this message translates to:
  /// **'Meine Termine'**
  String get tabsMyEvents;

  /// tabs.org
  ///
  /// In de, this message translates to:
  /// **'Org'**
  String get tabsOrg;

  /// tabs.overview
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get tabsOverview;

  /// tabs.people
  ///
  /// In de, this message translates to:
  /// **'Personen'**
  String get tabsPeople;

  /// tabs.songs
  ///
  /// In de, this message translates to:
  /// **'Werke'**
  String get tabsSongs;

  /// tasks.assignedTo
  ///
  /// In de, this message translates to:
  /// **'Zugewiesen an {name}'**
  String tasksAssignedTo(Object name);

  /// tasks.assignedToYou
  ///
  /// In de, this message translates to:
  /// **'Dir zugewiesen'**
  String get tasksAssignedToYou;

  /// tasks.created
  ///
  /// In de, this message translates to:
  /// **'Aufgabe angelegt'**
  String get tasksCreated;

  /// tasks.deleteConfirm
  ///
  /// In de, this message translates to:
  /// **'Aufgabe löschen?'**
  String get tasksDeleteConfirm;

  /// tasks.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Löschen fehlgeschlagen'**
  String get tasksDeleteFailed;

  /// tasks.deleteMessage
  ///
  /// In de, this message translates to:
  /// **'Die Aufgabe wird endgültig entfernt.'**
  String get tasksDeleteMessage;

  /// tasks.deleted
  ///
  /// In de, this message translates to:
  /// **'Aufgabe gelöscht'**
  String get tasksDeleted;

  /// tasks.description
  ///
  /// In de, this message translates to:
  /// **'Beschreibung'**
  String get tasksDescription;

  /// tasks.descriptionOptional
  ///
  /// In de, this message translates to:
  /// **'Beschreibung (optional)'**
  String get tasksDescriptionOptional;

  /// tasks.details
  ///
  /// In de, this message translates to:
  /// **'Details'**
  String get tasksDetails;

  /// tasks.done
  ///
  /// In de, this message translates to:
  /// **'Erledigt'**
  String get tasksDone;

  /// tasks.doneThanks
  ///
  /// In de, this message translates to:
  /// **'Erledigt – danke!'**
  String get tasksDoneThanks;

  /// tasks.dueLabel
  ///
  /// In de, this message translates to:
  /// **'Fällig {label}'**
  String tasksDueLabel(Object label);

  /// tasks.dueOn
  ///
  /// In de, this message translates to:
  /// **'Fällig am'**
  String get tasksDueOn;

  /// tasks.enterTitle
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Titel eingeben'**
  String get tasksEnterTitle;

  /// tasks.eventFrom
  ///
  /// In de, this message translates to:
  /// **'{type} vom {date}'**
  String tasksEventFrom(Object type, Object date);

  /// tasks.flutter.allTasks
  ///
  /// In de, this message translates to:
  /// **'Alle Aufgaben'**
  String get tasksFlutterAllTasks;

  /// tasks.flutter.editTask
  ///
  /// In de, this message translates to:
  /// **'Aufgabe bearbeiten'**
  String get tasksFlutterEditTask;

  /// tasks.flutter.newTask
  ///
  /// In de, this message translates to:
  /// **'Neue Aufgabe'**
  String get tasksFlutterNewTask;

  /// tasks.flutter.noDate
  ///
  /// In de, this message translates to:
  /// **'Kein Datum'**
  String get tasksFlutterNoDate;

  /// tasks.flutter.reopen
  ///
  /// In de, this message translates to:
  /// **'Wieder öffnen'**
  String get tasksFlutterReopen;

  /// tasks.flutter.showAllCount
  ///
  /// In de, this message translates to:
  /// **'Alle anzeigen ({count})'**
  String tasksFlutterShowAllCount(Object count);

  /// tasks.inProgress
  ///
  /// In de, this message translates to:
  /// **'In Arbeit'**
  String get tasksInProgress;

  /// tasks.markDone
  ///
  /// In de, this message translates to:
  /// **'Als erledigt markieren'**
  String get tasksMarkDone;

  /// tasks.myTasks
  ///
  /// In de, this message translates to:
  /// **'Meine Aufgaben'**
  String get tasksMyTasks;

  /// tasks.noDue
  ///
  /// In de, this message translates to:
  /// **'Ohne Fälligkeit'**
  String get tasksNoDue;

  /// tasks.noPersonFound
  ///
  /// In de, this message translates to:
  /// **'Keine Person gefunden'**
  String get tasksNoPersonFound;

  /// tasks.nobody
  ///
  /// In de, this message translates to:
  /// **'Niemand'**
  String get tasksNobody;

  /// tasks.notAssigned
  ///
  /// In de, this message translates to:
  /// **'Noch niemandem zugewiesen'**
  String get tasksNotAssigned;

  /// tasks.notAvailable
  ///
  /// In de, this message translates to:
  /// **'Diese Aufgabe gibt es nicht mehr oder du kannst sie nicht sehen.'**
  String get tasksNotAvailable;

  /// tasks.notify
  ///
  /// In de, this message translates to:
  /// **'{name} benachrichtigen'**
  String tasksNotify(Object name);

  /// tasks.notifyHint
  ///
  /// In de, this message translates to:
  /// **'Sofort per Push oder Telegram'**
  String get tasksNotifyHint;

  /// tasks.openCount
  ///
  /// In de, this message translates to:
  /// **'{count} offen'**
  String tasksOpenCount(Object count);

  /// tasks.origin
  ///
  /// In de, this message translates to:
  /// **'Herkunft'**
  String get tasksOrigin;

  /// tasks.overdueCount
  ///
  /// In de, this message translates to:
  /// **'{count} überfällig'**
  String tasksOverdueCount(Object count);

  /// tasks.overdueLabel
  ///
  /// In de, this message translates to:
  /// **'Überfällig {label}'**
  String tasksOverdueLabel(Object label);

  /// tasks.overdueSuffix
  ///
  /// In de, this message translates to:
  /// **'· überfällig'**
  String get tasksOverdueSuffix;

  /// tasks.person
  ///
  /// In de, this message translates to:
  /// **'Person'**
  String get tasksPerson;

  /// tasks.priority
  ///
  /// In de, this message translates to:
  /// **'Priorität'**
  String get tasksPriority;

  /// tasks.protocol
  ///
  /// In de, this message translates to:
  /// **'Protokoll'**
  String get tasksProtocol;

  /// tasks.reminderOther
  ///
  /// In de, this message translates to:
  /// **'Die verantwortliche Person bekommt 2 Tage vor Fälligkeit eine Erinnerung und noch eine, falls die Aufgabe überfällig wird.'**
  String get tasksReminderOther;

  /// tasks.reminderSelf
  ///
  /// In de, this message translates to:
  /// **'Du bekommst 2 Tage vor Fälligkeit eine Erinnerung und noch eine, falls die Aufgabe überfällig wird.'**
  String get tasksReminderSelf;

  /// tasks.responsible
  ///
  /// In de, this message translates to:
  /// **'Verantwortlich'**
  String get tasksResponsible;

  /// tasks.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Aufgabe konnte nicht gespeichert werden'**
  String get tasksSaveFailed;

  /// tasks.saved
  ///
  /// In de, this message translates to:
  /// **'Gespeichert'**
  String get tasksSaved;

  /// tasks.searchPerson
  ///
  /// In de, this message translates to:
  /// **'Person suchen'**
  String get tasksSearchPerson;

  /// tasks.status.completed
  ///
  /// In de, this message translates to:
  /// **'Erledigt'**
  String get tasksStatusCompleted;

  /// tasks.statusFailed
  ///
  /// In de, this message translates to:
  /// **'Status konnte nicht geändert werden'**
  String get tasksStatusFailed;

  /// tasks.status.inProgress
  ///
  /// In de, this message translates to:
  /// **'In Arbeit'**
  String get tasksStatusInProgress;

  /// tasks.status.open
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get tasksStatusOpen;

  /// tasks.task
  ///
  /// In de, this message translates to:
  /// **'Aufgabe'**
  String get tasksTask;

  /// tasks.title
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get tasksTitle;

  /// tasks.topic
  ///
  /// In de, this message translates to:
  /// **'Thema'**
  String get tasksTopic;

  /// tasks.whatToDo
  ///
  /// In de, this message translates to:
  /// **'Was ist zu tun?'**
  String get tasksWhatToDo;

  /// tasks.whoWhen
  ///
  /// In de, this message translates to:
  /// **'Wer & bis wann'**
  String get tasksWhoWhen;

  /// teachers.add
  ///
  /// In de, this message translates to:
  /// **'Lehrer hinzufügen'**
  String get teachersAdd;

  /// teachers.contact
  ///
  /// In de, this message translates to:
  /// **'Kontakt'**
  String get teachersContact;

  /// teachers.edit
  ///
  /// In de, this message translates to:
  /// **'Lehrer bearbeiten'**
  String get teachersEdit;

  /// teachers.fillAll
  ///
  /// In de, this message translates to:
  /// **'Bitte fülle alle Felder aus...'**
  String get teachersFillAll;

  /// teachers.flutter.delete
  ///
  /// In de, this message translates to:
  /// **'Lehrer löschen'**
  String get teachersFlutterDelete;

  /// teachers.flutter.deleteConfirm
  ///
  /// In de, this message translates to:
  /// **'Möchtest du \"{name}\" wirklich löschen?'**
  String teachersFlutterDeleteConfirm(Object name);

  /// teachers.flutter.deleted
  ///
  /// In de, this message translates to:
  /// **'Lehrer gelöscht'**
  String get teachersFlutterDeleted;

  /// teachers.flutter.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Lehrer konnten nicht geladen werden'**
  String get teachersFlutterLoadFailed;

  /// teachers.instruments
  ///
  /// In de, this message translates to:
  /// **'Instrumente'**
  String get teachersInstruments;

  /// teachers.playerCount
  ///
  /// In de, this message translates to:
  /// **'{count} Spieler'**
  String teachersPlayerCount(num count);

  /// teachers.players
  ///
  /// In de, this message translates to:
  /// **'Spieler'**
  String get teachersPlayers;

  /// teachers.private
  ///
  /// In de, this message translates to:
  /// **'Privatlehrer'**
  String get teachersPrivate;

  /// teachers.title
  ///
  /// In de, this message translates to:
  /// **'Lehrer'**
  String get teachersTitle;

  /// teachers.update
  ///
  /// In de, this message translates to:
  /// **'Lehrer updaten'**
  String get teachersUpdate;

  /// teachers.updated
  ///
  /// In de, this message translates to:
  /// **'Lehrer erfolgreich geupdated!'**
  String get teachersUpdated;

  /// teamOrg.acceptSuggestion
  ///
  /// In de, this message translates to:
  /// **'Vorschlag übernehmen'**
  String get teamOrgAcceptSuggestion;

  /// teamOrg.acceptedByLeaders
  ///
  /// In de, this message translates to:
  /// **'Von der Leitung übernommen'**
  String get teamOrgAcceptedByLeaders;

  /// teamOrg.addTopics
  ///
  /// In de, this message translates to:
  /// **'Themen aufnehmen'**
  String get teamOrgAddTopics;

  /// teamOrg.allCount
  ///
  /// In de, this message translates to:
  /// **'Alle · {count}'**
  String teamOrgAllCount(Object count);

  /// teamOrg.allDecided
  ///
  /// In de, this message translates to:
  /// **'Alle Vorschläge sind entschieden.'**
  String get teamOrgAllDecided;

  /// teamOrg.change
  ///
  /// In de, this message translates to:
  /// **'Ändern'**
  String get teamOrgChange;

  /// teamOrg.changeDate
  ///
  /// In de, this message translates to:
  /// **'Datum dieses Termins ändern'**
  String get teamOrgChangeDate;

  /// teamOrg.chosenEvent
  ///
  /// In de, this message translates to:
  /// **'Gewählter Termin'**
  String get teamOrgChosenEvent;

  /// teamOrg.createEvent
  ///
  /// In de, this message translates to:
  /// **'Termin anlegen'**
  String get teamOrgCreateEvent;

  /// teamOrg.createTask
  ///
  /// In de, this message translates to:
  /// **'Aufgabe anlegen'**
  String get teamOrgCreateTask;

  /// teamOrg.createTopic
  ///
  /// In de, this message translates to:
  /// **'Thema anlegen'**
  String get teamOrgCreateTopic;

  /// teamOrg.daysAgo
  ///
  /// In de, this message translates to:
  /// **'vor {count} Tagen'**
  String teamOrgDaysAgo(Object count);

  /// teamOrg.decisionFailed
  ///
  /// In de, this message translates to:
  /// **'Entscheidung konnte nicht gespeichert werden'**
  String get teamOrgDecisionFailed;

  /// teamOrg.descPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Worum geht es? (optional)'**
  String get teamOrgDescPlaceholder;

  /// teamOrg.doneDisappear
  ///
  /// In de, this message translates to:
  /// **'Erledigte Aufgaben verschwinden nach 30 Tagen aus der Liste.'**
  String get teamOrgDoneDisappear;

  /// teamOrg.draft
  ///
  /// In de, this message translates to:
  /// **'Entwurf'**
  String get teamOrgDraft;

  /// teamOrg.editedOn
  ///
  /// In de, this message translates to:
  /// **'{text} · geändert am {date}'**
  String teamOrgEditedOn(Object text, Object date);

  /// teamOrg.emptyAll
  ///
  /// In de, this message translates to:
  /// **'Noch keine Aufgaben. Leg die erste mit + an oder direkt aus einem Protokoll.'**
  String get teamOrgEmptyAll;

  /// teamOrg.emptyMine
  ///
  /// In de, this message translates to:
  /// **'Du hast keine Aufgaben. Alles erledigt!'**
  String get teamOrgEmptyMine;

  /// teamOrg.emptyMineAssigned
  ///
  /// In de, this message translates to:
  /// **'Dir sind gerade keine Aufgaben zugewiesen. Genieß die Ruhe!'**
  String get teamOrgEmptyMineAssigned;

  /// teamOrg.emptyPerson
  ///
  /// In de, this message translates to:
  /// **'Hier ist nichts offen.'**
  String get teamOrgEmptyPerson;

  /// teamOrg.filter
  ///
  /// In de, this message translates to:
  /// **'Filter'**
  String get teamOrgFilter;

  /// teamOrg.flutter.and
  ///
  /// In de, this message translates to:
  /// **'und'**
  String get teamOrgFlutterAnd;

  /// teamOrg.flutter.createType
  ///
  /// In de, this message translates to:
  /// **'{name} anlegen'**
  String teamOrgFlutterCreateType(Object name);

  /// teamOrg.flutter.member
  ///
  /// In de, this message translates to:
  /// **'Mitglied'**
  String get teamOrgFlutterMember;

  /// teamOrg.flutter.newSuggestions
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} neuer Vorschlag} other {{count} neue Vorschläge}}'**
  String teamOrgFlutterNewSuggestions(num count);

  /// teamOrg.group.none
  ///
  /// In de, this message translates to:
  /// **'Ohne Datum'**
  String get teamOrgGroupNone;

  /// teamOrg.group.overdue
  ///
  /// In de, this message translates to:
  /// **'Überfällig'**
  String get teamOrgGroupOverdue;

  /// teamOrg.group.week
  ///
  /// In de, this message translates to:
  /// **'Diese Woche'**
  String get teamOrgGroupWeek;

  /// teamOrg.leadersPlan
  ///
  /// In de, this message translates to:
  /// **'Themen und Tagesordnungen plant die Leitung. Du gehörst zu keiner Gruppe mit Protokoll & Tagesordnung.'**
  String get teamOrgLeadersPlan;

  /// teamOrg.mineCount
  ///
  /// In de, this message translates to:
  /// **'Meine · {count}'**
  String teamOrgMineCount(Object count);

  /// teamOrg.minutes
  ///
  /// In de, this message translates to:
  /// **'{min} min'**
  String teamOrgMinutes(Object min);

  /// teamOrg.mySuggestions
  ///
  /// In de, this message translates to:
  /// **'Meine Vorschläge'**
  String get teamOrgMySuggestions;

  /// teamOrg.nextEvent
  ///
  /// In de, this message translates to:
  /// **'Nächster Termin'**
  String get teamOrgNextEvent;

  /// teamOrg.noHits
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer'**
  String get teamOrgNoHits;

  /// teamOrg.noOpenTopics
  ///
  /// In de, this message translates to:
  /// **'Keine offenen Themen. Lege mit + ein neues an.'**
  String get teamOrgNoOpenTopics;

  /// teamOrg.noProtocolEvent
  ///
  /// In de, this message translates to:
  /// **'Kein Termin mit Protokoll & Tagesordnung geplant.'**
  String get teamOrgNoProtocolEvent;

  /// teamOrg.noProtocolMatch
  ///
  /// In de, this message translates to:
  /// **'Kein Protokoll passt zu „{search}“.'**
  String teamOrgNoProtocolMatch(Object search);

  /// teamOrg.noProtocols
  ///
  /// In de, this message translates to:
  /// **'Noch keine Protokolle'**
  String get teamOrgNoProtocols;

  /// teamOrg.noProtocolsHint
  ///
  /// In de, this message translates to:
  /// **'Ein Protokoll schreibst du direkt im Termin: Öffne den Termin und tippe auf „Protokoll“.'**
  String get teamOrgNoProtocolsHint;

  /// teamOrg.noPublished
  ///
  /// In de, this message translates to:
  /// **'Noch keine Protokolle freigegeben'**
  String get teamOrgNoPublished;

  /// teamOrg.noPublishedHint
  ///
  /// In de, this message translates to:
  /// **'Sobald die Leitung ein Protokoll freigibt, findest du es hier.'**
  String get teamOrgNoPublishedHint;

  /// teamOrg.noTopsYet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Themen auf der Tagesordnung.'**
  String get teamOrgNoTopsYet;

  /// teamOrg.nobodyAssigned
  ///
  /// In de, this message translates to:
  /// **'Niemand zugewiesen'**
  String get teamOrgNobodyAssigned;

  /// teamOrg.nobodyResponsible
  ///
  /// In de, this message translates to:
  /// **'Noch niemand verantwortlich'**
  String get teamOrgNobodyResponsible;

  /// teamOrg.nothingSuggested
  ///
  /// In de, this message translates to:
  /// **'Du hast noch nichts vorgeschlagen.'**
  String get teamOrgNothingSuggested;

  /// teamOrg.openCount
  ///
  /// In de, this message translates to:
  /// **'{count} offen'**
  String teamOrgOpenCount(Object count);

  /// teamOrg.openTopic
  ///
  /// In de, this message translates to:
  /// **'Thema öffnen'**
  String get teamOrgOpenTopic;

  /// teamOrg.outcome.decided
  ///
  /// In de, this message translates to:
  /// **'Beschlossen'**
  String get teamOrgOutcomeDecided;

  /// teamOrg.outcome.discussed
  ///
  /// In de, this message translates to:
  /// **'Besprochen'**
  String get teamOrgOutcomeDiscussed;

  /// teamOrg.personInformed
  ///
  /// In de, this message translates to:
  /// **'{name} wird informiert. Eine kurze Begründung hilft.'**
  String teamOrgPersonInformed(Object name);

  /// teamOrg.planForWhich
  ///
  /// In de, this message translates to:
  /// **'Für welchen Termin planen?'**
  String get teamOrgPlanForWhich;

  /// teamOrg.plannedLower
  ///
  /// In de, this message translates to:
  /// **'eingeplant'**
  String get teamOrgPlannedLower;

  /// teamOrg.postponedLower
  ///
  /// In de, this message translates to:
  /// **'vertagt'**
  String get teamOrgPostponedLower;

  /// teamOrg.proposal
  ///
  /// In de, this message translates to:
  /// **'Vorschlag'**
  String get teamOrgProposal;

  /// teamOrg.published
  ///
  /// In de, this message translates to:
  /// **'Freigegeben'**
  String get teamOrgPublished;

  /// teamOrg.publishedOn
  ///
  /// In de, this message translates to:
  /// **'Freigegeben am {date}'**
  String teamOrgPublishedOn(Object date);

  /// teamOrg.reasonOptional
  ///
  /// In de, this message translates to:
  /// **'Begründung (optional)'**
  String get teamOrgReasonOptional;

  /// teamOrg.reject
  ///
  /// In de, this message translates to:
  /// **'Ablehnen'**
  String get teamOrgReject;

  /// teamOrg.rejectSuggestion
  ///
  /// In de, this message translates to:
  /// **'Vorschlag ablehnen'**
  String get teamOrgRejectSuggestion;

  /// teamOrg.removeFailed
  ///
  /// In de, this message translates to:
  /// **'Thema konnte nicht entfernt werden'**
  String get teamOrgRemoveFailed;

  /// teamOrg.removeFromEvent
  ///
  /// In de, this message translates to:
  /// **'Aus diesem Termin entfernen'**
  String get teamOrgRemoveFromEvent;

  /// teamOrg.removedStays
  ///
  /// In de, this message translates to:
  /// **'Aus dem Termin entfernt, bleibt im Themenspeicher'**
  String get teamOrgRemovedStays;

  /// teamOrg.review
  ///
  /// In de, this message translates to:
  /// **'Prüfen'**
  String get teamOrgReview;

  /// teamOrg.searchProtocols
  ///
  /// In de, this message translates to:
  /// **'Termin oder Datum suchen'**
  String get teamOrgSearchProtocols;

  /// teamOrg.sendSuggestion
  ///
  /// In de, this message translates to:
  /// **'Vorschlag senden'**
  String get teamOrgSendSuggestion;

  /// teamOrg.showDone
  ///
  /// In de, this message translates to:
  /// **'Erledigte anzeigen ({count})'**
  String teamOrgShowDone(Object count);

  /// teamOrg.showOlderDone
  ///
  /// In de, this message translates to:
  /// **'Ältere erledigte anzeigen'**
  String get teamOrgShowOlderDone;

  /// teamOrg.since
  ///
  /// In de, this message translates to:
  /// **'seit {date}'**
  String teamOrgSince(Object date);

  /// teamOrg.submittedByMembers
  ///
  /// In de, this message translates to:
  /// **'Von Mitgliedern eingereicht'**
  String get teamOrgSubmittedByMembers;

  /// teamOrg.submittedOn
  ///
  /// In de, this message translates to:
  /// **'Eingereicht am {date}'**
  String teamOrgSubmittedOn(Object date);

  /// teamOrg.suggestHint
  ///
  /// In de, this message translates to:
  /// **'Du hast ein Anliegen für die nächste Sitzung? Die Leitung entscheidet, ob es auf die Tagesordnung kommt.'**
  String get teamOrgSuggestHint;

  /// teamOrg.suggestTopic
  ///
  /// In de, this message translates to:
  /// **'Thema vorschlagen'**
  String get teamOrgSuggestTopic;

  /// teamOrg.suggestion.accepted
  ///
  /// In de, this message translates to:
  /// **'Übernommen'**
  String get teamOrgSuggestionAccepted;

  /// teamOrg.suggestionFailed
  ///
  /// In de, this message translates to:
  /// **'Vorschlag konnte nicht gesendet werden'**
  String get teamOrgSuggestionFailed;

  /// teamOrg.suggestion.rejected
  ///
  /// In de, this message translates to:
  /// **'Abgelehnt'**
  String get teamOrgSuggestionRejected;

  /// teamOrg.suggestionSent
  ///
  /// In de, this message translates to:
  /// **'Vorschlag gesendet'**
  String get teamOrgSuggestionSent;

  /// teamOrg.suggestion.waiting
  ///
  /// In de, this message translates to:
  /// **'Wartet'**
  String get teamOrgSuggestionWaiting;

  /// teamOrg.suggestions
  ///
  /// In de, this message translates to:
  /// **'Vorschläge'**
  String get teamOrgSuggestions;

  /// teamOrg.suggestionsHint
  ///
  /// In de, this message translates to:
  /// **'Übernommene Vorschläge landen im Themenspeicher. Wer vorgeschlagen hat, wird über deine Entscheidung informiert.'**
  String get teamOrgSuggestionsHint;

  /// teamOrg.tabProtocols
  ///
  /// In de, this message translates to:
  /// **'Protokolle'**
  String get teamOrgTabProtocols;

  /// teamOrg.tabTasks
  ///
  /// In de, this message translates to:
  /// **'Aufgaben'**
  String get teamOrgTabTasks;

  /// teamOrg.tabTopics
  ///
  /// In de, this message translates to:
  /// **'Themen'**
  String get teamOrgTabTopics;

  /// teamOrg.tasksLoadFailed
  ///
  /// In de, this message translates to:
  /// **'Aufgaben konnten nicht geladen werden'**
  String get teamOrgTasksLoadFailed;

  /// teamOrg.thePerson
  ///
  /// In de, this message translates to:
  /// **'Die Person'**
  String get teamOrgThePerson;

  /// teamOrg.title
  ///
  /// In de, this message translates to:
  /// **'Teamorganisation'**
  String get teamOrgTitle;

  /// teamOrg.titlePlaceholder
  ///
  /// In de, this message translates to:
  /// **'z. B. Neue Notenpulte'**
  String get teamOrgTitlePlaceholder;

  /// teamOrg.today
  ///
  /// In de, this message translates to:
  /// **'heute'**
  String get teamOrgToday;

  /// teamOrg.todayCap
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get teamOrgTodayCap;

  /// teamOrg.tomorrow
  ///
  /// In de, this message translates to:
  /// **'Morgen'**
  String get teamOrgTomorrow;

  /// teamOrg.topName
  ///
  /// In de, this message translates to:
  /// **'TOP {n} · {name}'**
  String teamOrgTopName(Object n, Object name);

  /// teamOrg.whichPriority
  ///
  /// In de, this message translates to:
  /// **'Mit welcher Priorität kommt das Thema in den Themenspeicher?'**
  String get teamOrgWhichPriority;

  /// teamOrg.yesterday
  ///
  /// In de, this message translates to:
  /// **'gestern'**
  String get teamOrgYesterday;

  /// teams.choose
  ///
  /// In de, this message translates to:
  /// **'Wähle aus, welche Attendix-Instanz in diesem Kanal angezeigt werden soll.'**
  String get teamsChoose;

  /// teams.noAccount
  ///
  /// In de, this message translates to:
  /// **'Kein Attendix-Konto gefunden. Bitte melde dich zuerst im Attendix-Tab an.'**
  String get teamsNoAccount;

  /// teams.onlyInTeams
  ///
  /// In de, this message translates to:
  /// **'Diese Seite wird nur innerhalb von Microsoft Teams verwendet.'**
  String get teamsOnlyInTeams;

  /// teams.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Konfiguration konnte nicht gespeichert werden'**
  String get teamsSaveFailed;

  /// teams.setup
  ///
  /// In de, this message translates to:
  /// **'Attendix-Tab einrichten'**
  String get teamsSetup;

  /// tenantRegister.acceptTerms
  ///
  /// In de, this message translates to:
  /// **'Nutzungsbedingungen und Datenschutzerklärung akzeptieren'**
  String get tenantRegisterAcceptTerms;

  /// tenantRegister.acceptTermsToast
  ///
  /// In de, this message translates to:
  /// **'Bitte akzeptiere die Nutzungsbedingungen und Datenschutzerklärung.'**
  String get tenantRegisterAcceptTermsToast;

  /// tenantRegister.account
  ///
  /// In de, this message translates to:
  /// **'Account'**
  String get tenantRegisterAccount;

  /// tenantRegister.alreadyRegistered
  ///
  /// In de, this message translates to:
  /// **'Sie sind bereits in dieser Instanz registriert.'**
  String get tenantRegisterAlreadyRegistered;

  /// tenantRegister.birthDate
  ///
  /// In de, this message translates to:
  /// **'Geburtsdatum'**
  String get tenantRegisterBirthDate;

  /// tenantRegister.birthDateRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie ein gültiges Geburtsdatum an.'**
  String get tenantRegisterBirthDateRequired;

  /// tenantRegister.choosePicture
  ///
  /// In de, this message translates to:
  /// **'Wähle ein Passbild aus (max. 15 MB)'**
  String get tenantRegisterChoosePicture;

  /// tenantRegister.churchNamePlaceholder
  ///
  /// In de, this message translates to:
  /// **'Name deiner Gemeinde'**
  String get tenantRegisterChurchNamePlaceholder;

  /// tenantRegister.churchNameRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie den Namen Ihrer Gemeinde ein.'**
  String get tenantRegisterChurchNameRequired;

  /// tenantRegister.churchNotListed
  ///
  /// In de, this message translates to:
  /// **'Gemeinde nicht gelistet? Bitte Namen eingeben'**
  String get tenantRegisterChurchNotListed;

  /// tenantRegister.churchRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte wählen Sie eine Gemeinde aus.'**
  String get tenantRegisterChurchRequired;

  /// tenantRegister.confirmCode
  ///
  /// In de, this message translates to:
  /// **'Code bestätigen'**
  String get tenantRegisterConfirmCode;

  /// tenantRegister.emailAddress
  ///
  /// In de, this message translates to:
  /// **'E-Mail Adresse'**
  String get tenantRegisterEmailAddress;

  /// tenantRegister.failed
  ///
  /// In de, this message translates to:
  /// **'Fehler bei der Registrierung: {error}'**
  String tenantRegisterFailed(Object error);

  /// tenantRegister.fieldAccept
  ///
  /// In de, this message translates to:
  /// **'Sie müssen dem Feld \"{field}\" zustimmen, um fortzufahren.'**
  String tenantRegisterFieldAccept(Object field);

  /// tenantRegister.fieldDate
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie ein gültiges Datum für das Feld \"{field}\" ein.'**
  String tenantRegisterFieldDate(Object field);

  /// tenantRegister.fieldNumber
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie eine gültige Zahl für das Feld \"{field}\" ein.'**
  String tenantRegisterFieldNumber(Object field);

  /// tenantRegister.fieldRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte füllen Sie das Feld \"{field}\" aus.'**
  String tenantRegisterFieldRequired(Object field);

  /// tenantRegister.fieldValue
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie einen gültigen Wert für das Feld \"{field}\" ein.'**
  String tenantRegisterFieldValue(Object field);

  /// tenantRegister.finish
  ///
  /// In de, this message translates to:
  /// **'Registrierung abschließen'**
  String get tenantRegisterFinish;

  /// tenantRegister.firstName
  ///
  /// In de, this message translates to:
  /// **'Vorname'**
  String get tenantRegisterFirstName;

  /// tenantRegister.flutter.createChurchFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen der Gemeinde.'**
  String get tenantRegisterFlutterCreateChurchFailed;

  /// tenantRegister.flutter.groupRequired
  ///
  /// In de, this message translates to:
  /// **'Gruppe ist erforderlich'**
  String get tenantRegisterFlutterGroupRequired;

  /// tenantRegister.flutter.invalidLink
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Registrierungslink.'**
  String get tenantRegisterFlutterInvalidLink;

  /// tenantRegister.flutter.loadChurchesFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Gemeinden'**
  String get tenantRegisterFlutterLoadChurchesFailed;

  /// tenantRegister.flutter.loadError
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden: {error}'**
  String tenantRegisterFlutterLoadError(Object error);

  /// tenantRegister.flutter.loadGroupsFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Gruppen'**
  String get tenantRegisterFlutterLoadGroupsFailed;

  /// tenantRegister.flutter.maxSize
  ///
  /// In de, this message translates to:
  /// **'Max. 15 MB'**
  String get tenantRegisterFlutterMaxSize;

  /// tenantRegister.flutter.minFiveChars
  ///
  /// In de, this message translates to:
  /// **'Mindestens 5 Zeichen'**
  String get tenantRegisterFlutterMinFiveChars;

  /// tenantRegister.flutter.registerFailedRetry
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Registrieren. Bitte versuche es erneut.'**
  String get tenantRegisterFlutterRegisterFailedRetry;

  /// tenantRegister.flutter.registrationAt
  ///
  /// In de, this message translates to:
  /// **'Registrierung bei'**
  String get tenantRegisterFlutterRegistrationAt;

  /// tenantRegister.flutter.signInExisting
  ///
  /// In de, this message translates to:
  /// **'Melde dich mit deinem bestehenden Account an.'**
  String get tenantRegisterFlutterSignInExisting;

  /// tenantRegister.flutter.termsAccept
  ///
  /// In de, this message translates to:
  /// **' akzeptieren'**
  String get tenantRegisterFlutterTermsAccept;

  /// tenantRegister.flutter.termsLink
  ///
  /// In de, this message translates to:
  /// **'Nutzungsbedingungen und Datenschutzerklärung'**
  String get tenantRegisterFlutterTermsLink;

  /// tenantRegister.flutter.toLogin
  ///
  /// In de, this message translates to:
  /// **'Zur Anmeldung'**
  String get tenantRegisterFlutterToLogin;

  /// tenantRegister.haveAccount
  ///
  /// In de, this message translates to:
  /// **'Account bereits vorhanden? Hier klicken'**
  String get tenantRegisterHaveAccount;

  /// tenantRegister.intro
  ///
  /// In de, this message translates to:
  /// **'Registriere dich über dieses Formular für die oben genannte Instanz.'**
  String get tenantRegisterIntro;

  /// tenantRegister.invalidLink
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Freigabe-Link.'**
  String get tenantRegisterInvalidLink;

  /// tenantRegister.lastName
  ///
  /// In de, this message translates to:
  /// **'Nachname'**
  String get tenantRegisterLastName;

  /// tenantRegister.moreInfo
  ///
  /// In de, this message translates to:
  /// **'Weitere Informationen'**
  String get tenantRegisterMoreInfo;

  /// tenantRegister.nameRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie Ihren Vor- und Nachnamen an.'**
  String get tenantRegisterNameRequired;

  /// tenantRegister.noChurchFound
  ///
  /// In de, this message translates to:
  /// **'Keine Gemeinde gefunden.'**
  String get tenantRegisterNoChurchFound;

  /// tenantRegister.noGroups
  ///
  /// In de, this message translates to:
  /// **'Registrierung aktuell nicht möglich: Der Administrator hat noch keine Gruppen angelegt. Bitte versuche es später erneut.'**
  String get tenantRegisterNoGroups;

  /// tenantRegister.noGroupsToast
  ///
  /// In de, this message translates to:
  /// **'Registrierung nicht möglich: Es sind keine Gruppen verfügbar.'**
  String get tenantRegisterNoGroupsToast;

  /// tenantRegister.notListed
  ///
  /// In de, this message translates to:
  /// **'Nicht gelistet'**
  String get tenantRegisterNotListed;

  /// tenantRegister.notes
  ///
  /// In de, this message translates to:
  /// **'Bemerkungen (optional)'**
  String get tenantRegisterNotes;

  /// tenantRegister.passwordMismatch
  ///
  /// In de, this message translates to:
  /// **'Die Passwörter stimmen nicht überein.'**
  String get tenantRegisterPasswordMismatch;

  /// tenantRegister.passwordTooShort
  ///
  /// In de, this message translates to:
  /// **'Das Passwort muss mindestens 6 Zeichen lang sein.'**
  String get tenantRegisterPasswordTooShort;

  /// tenantRegister.personalData
  ///
  /// In de, this message translates to:
  /// **'Persönliche Daten'**
  String get tenantRegisterPersonalData;

  /// tenantRegister.phone
  ///
  /// In de, this message translates to:
  /// **'Handynummer'**
  String get tenantRegisterPhone;

  /// tenantRegister.phoneRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie eine gültige Telefonnummer an.'**
  String get tenantRegisterPhoneRequired;

  /// tenantRegister.pictureFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim ändern des Passbildes, versuche es später erneut'**
  String get tenantRegisterPictureFailed;

  /// tenantRegister.pictureRequired
  ///
  /// In de, this message translates to:
  /// **'Bitte wählen Sie ein Passbild aus.'**
  String get tenantRegisterPictureRequired;

  /// tenantRegister.pictureTooLarge
  ///
  /// In de, this message translates to:
  /// **'Das ausgewählte Bild ist zu groß. Bitte wähle ein Bild unter 15 MB.'**
  String get tenantRegisterPictureTooLarge;

  /// tenantRegister.pleaseChoose
  ///
  /// In de, this message translates to:
  /// **'Bitte auswählen'**
  String get tenantRegisterPleaseChoose;

  /// tenantRegister.replacePicture
  ///
  /// In de, this message translates to:
  /// **'Passbild ersetzen'**
  String get tenantRegisterReplacePicture;

  /// tenantRegister.searchChurch
  ///
  /// In de, this message translates to:
  /// **'Gemeinde suchen'**
  String get tenantRegisterSearchChurch;

  /// tenantRegister.signedInAs
  ///
  /// In de, this message translates to:
  /// **'Du bist angemeldet als {email}.'**
  String tenantRegisterSignedInAs(Object email);

  /// tenantRegister.success.header
  ///
  /// In de, this message translates to:
  /// **'Registrierung erfolgreich'**
  String get tenantRegisterSuccessHeader;

  /// tenantRegister.success.joined
  ///
  /// In de, this message translates to:
  /// **'Deine Registrierung war erfolgreich! Du bist nun teil der Instanz.'**
  String get tenantRegisterSuccessJoined;

  /// tenantRegister.success.newConfirm
  ///
  /// In de, this message translates to:
  /// **'Dein Konto wurde erstellt. Um dich anmelden zu können, bestätige bitte deine E-Mail. Falls keine E-Mail ankommt, überprüfe bitte deinen Spam-Ordner. Im Anschluss kannst du dich anmelden.'**
  String get tenantRegisterSuccessNewConfirm;

  /// tenantRegister.success.newPending
  ///
  /// In de, this message translates to:
  /// **'Dein Konto wurde erstellt und wartet auf die Genehmigung durch einen Administrator. Bitte bestätige deine E-Mail, um dich anmelden zu können. Falls keine E-Mail ankommt, überprüfe bitte deinen Spam-Ordner.'**
  String get tenantRegisterSuccessNewPending;

  /// tenantRegister.success.pending
  ///
  /// In de, this message translates to:
  /// **'Deine Registrierung war erfolgreich! Bitte warte auf die Genehmigung durch einen Administrator.'**
  String get tenantRegisterSuccessPending;

  /// tenantRegister.title
  ///
  /// In de, this message translates to:
  /// **'Registrierung'**
  String get tenantRegisterTitle;

  /// tenantSelect.flutter.createdAt
  ///
  /// In de, this message translates to:
  /// **'Erstellt am'**
  String get tenantSelectFlutterCreatedAt;

  /// tenantSelect.flutter.dangerZone
  ///
  /// In de, this message translates to:
  /// **'Gefahrenzone'**
  String get tenantSelectFlutterDangerZone;

  /// tenantSelect.flutter.deleteAllData
  ///
  /// In de, this message translates to:
  /// **'Alle Daten dieser Instanz werden unwiderruflich gelöscht.'**
  String get tenantSelectFlutterDeleteAllData;

  /// tenantSelect.flutter.deleteTenant
  ///
  /// In de, this message translates to:
  /// **'Instanz löschen'**
  String get tenantSelectFlutterDeleteTenant;

  /// tenantSelect.flutter.deleteTenantHint
  ///
  /// In de, this message translates to:
  /// **'Diese Gruppe unwiderruflich löschen'**
  String get tenantSelectFlutterDeleteTenantHint;

  /// tenantSelect.flutter.deleted
  ///
  /// In de, this message translates to:
  /// **'Instanz gelöscht'**
  String get tenantSelectFlutterDeleted;

  /// tenantSelect.flutter.detailsLoadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Instanz-Details'**
  String get tenantSelectFlutterDetailsLoadFailed;

  /// tenantSelect.flutter.detailsTitle
  ///
  /// In de, this message translates to:
  /// **'Instanz-Details'**
  String get tenantSelectFlutterDetailsTitle;

  /// tenantSelect.flutter.emptyText
  ///
  /// In de, this message translates to:
  /// **'Du bist noch keiner Instanz zugeordnet. Bitte wende dich an einen Administrator oder lege eine neue Instanz an.'**
  String get tenantSelectFlutterEmptyText;

  /// tenantSelect.flutter.emptyTitle
  ///
  /// In de, this message translates to:
  /// **'Keine Instanzen'**
  String get tenantSelectFlutterEmptyTitle;

  /// tenantSelect.flutter.enterNameToConfirm
  ///
  /// In de, this message translates to:
  /// **'Bitte gib den Namen der Instanz ein, um das Löschen zu bestätigen:'**
  String get tenantSelectFlutterEnterNameToConfirm;

  /// tenantSelect.flutter.info
  ///
  /// In de, this message translates to:
  /// **'Informationen'**
  String get tenantSelectFlutterInfo;

  /// tenantSelect.flutter.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden'**
  String get tenantSelectFlutterLoadFailed;

  /// tenantSelect.flutter.newTenant
  ///
  /// In de, this message translates to:
  /// **'Neue Instanz'**
  String get tenantSelectFlutterNewTenant;

  /// tenantSelect.flutter.noRole
  ///
  /// In de, this message translates to:
  /// **'Keine Rolle'**
  String get tenantSelectFlutterNoRole;

  /// tenantSelect.flutter.notFound
  ///
  /// In de, this message translates to:
  /// **'Instanz nicht gefunden'**
  String get tenantSelectFlutterNotFound;

  /// tenantSelect.flutter.region
  ///
  /// In de, this message translates to:
  /// **'Region'**
  String get tenantSelectFlutterRegion;

  /// tenantSelect.flutter.tenantSelection
  ///
  /// In de, this message translates to:
  /// **'Instanzauswahl'**
  String get tenantSelectFlutterTenantSelection;

  /// tenantSelect.flutter.yourRole
  ///
  /// In de, this message translates to:
  /// **'Deine Rolle'**
  String get tenantSelectFlutterYourRole;

  /// terms.acceptAfter
  ///
  /// In de, this message translates to:
  /// **'gelesen.'**
  String get termsAcceptAfter;

  /// terms.acceptAria
  ///
  /// In de, this message translates to:
  /// **'Nutzungsbedingungen und Datenschutzerklärung akzeptieren'**
  String get termsAcceptAria;

  /// terms.acceptBefore
  ///
  /// In de, this message translates to:
  /// **'Ich akzeptiere die Nutzungsbedingungen und habe die'**
  String get termsAcceptBefore;

  /// terms.acceptContinue
  ///
  /// In de, this message translates to:
  /// **'Akzeptieren und fortfahren'**
  String get termsAcceptContinue;

  /// terms.beforeStart
  ///
  /// In de, this message translates to:
  /// **'Kurz bevor es losgeht'**
  String get termsBeforeStart;

  /// terms.intro
  ///
  /// In de, this message translates to:
  /// **'Um Attendix nutzen zu können, benötigen wir einmalig deine Zustimmung zu unseren Nutzungsbedingungen und der Datenschutzerklärung.'**
  String get termsIntro;

  /// terms.pleaseAccept
  ///
  /// In de, this message translates to:
  /// **'Bitte akzeptiere die Nutzungsbedingungen und Datenschutzerklärung.'**
  String get termsPleaseAccept;

  /// terms.privacy
  ///
  /// In de, this message translates to:
  /// **'Datenschutzerklärung'**
  String get termsPrivacy;

  /// terms.read
  ///
  /// In de, this message translates to:
  /// **'Datenschutzerklärung & Impressum lesen'**
  String get termsRead;

  /// terms.safe
  ///
  /// In de, this message translates to:
  /// **'Deine Daten sind sicher'**
  String get termsSafe;

  /// terms.safeText
  ///
  /// In de, this message translates to:
  /// **'Wir speichern nur die Daten, die für den Betrieb der App notwendig sind, und geben sie nicht an Dritte weiter.'**
  String get termsSafeText;

  /// terms.saveFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern. Bitte versuche es erneut.'**
  String get termsSaveFailed;

  /// terms.sessionExpired
  ///
  /// In de, this message translates to:
  /// **'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.'**
  String get termsSessionExpired;

  /// terms.title
  ///
  /// In de, this message translates to:
  /// **'Datenschutz & Nutzung'**
  String get termsTitle;

  /// terms.usage
  ///
  /// In de, this message translates to:
  /// **'Wofür werden deine Daten genutzt?'**
  String get termsUsage;

  /// terms.usageText
  ///
  /// In de, this message translates to:
  /// **'Ausschließlich zur Verwaltung deiner Anwesenheit und zur Kommunikation innerhalb deiner Gruppe oder deines Chores.'**
  String get termsUsageText;

  /// typeSettings.active
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get typeSettingsActive;

  /// typeSettings.activeHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn du diese Option deaktivierst, wird der Anwesenheitstyp beim Anlegen einer Anwesenheit nicht mehr als Option angezeigt.'**
  String get typeSettingsActiveHelper;

  /// typeSettings.activeReminders
  ///
  /// In de, this message translates to:
  /// **'Aktive Erinnerungen'**
  String get typeSettingsActiveReminders;

  /// typeSettings.addField
  ///
  /// In de, this message translates to:
  /// **'Feld hinzufügen'**
  String get typeSettingsAddField;

  /// typeSettings.addNoteField
  ///
  /// In de, this message translates to:
  /// **'Notizfeld hinzufügen'**
  String get typeSettingsAddNoteField;

  /// typeSettings.addReminder
  ///
  /// In de, this message translates to:
  /// **'Erinnerung hinzufügen'**
  String get typeSettingsAddReminder;

  /// typeSettings.addTodo
  ///
  /// In de, this message translates to:
  /// **'To-Do hinzufügen'**
  String get typeSettingsAddTodo;

  /// typeSettings.after1Day
  ///
  /// In de, this message translates to:
  /// **'nach 1 Tag'**
  String get typeSettingsAfter1Day;

  /// typeSettings.after2Days
  ///
  /// In de, this message translates to:
  /// **'nach 2 Tagen'**
  String get typeSettingsAfter2Days;

  /// typeSettings.after3Days
  ///
  /// In de, this message translates to:
  /// **'nach 3 Tagen'**
  String get typeSettingsAfter3Days;

  /// typeSettings.after7Days
  ///
  /// In de, this message translates to:
  /// **'nach 7 Tagen'**
  String get typeSettingsAfter7Days;

  /// typeSettings.agenda
  ///
  /// In de, this message translates to:
  /// **'Tagesordnung'**
  String get typeSettingsAgenda;

  /// typeSettings.agendaExists
  ///
  /// In de, this message translates to:
  /// **'Ein Tagesordnungs-Platzhalter ist bereits vorhanden'**
  String get typeSettingsAgendaExists;

  /// typeSettings.agendaPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Tagesordnung Platzhalter'**
  String get typeSettingsAgendaPlaceholder;

  /// typeSettings.allDay
  ///
  /// In de, this message translates to:
  /// **'Ganztägig'**
  String get typeSettingsAllDay;

  /// typeSettings.allDayHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn du diese Option aktivierst, wird bei einer Anwesenheit von diesem Typ keine Uhrzeit festgelegt aber eine Dauer angegeben.'**
  String get typeSettingsAllDayHelper;

  /// typeSettings.appearance
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get typeSettingsAppearance;

  /// typeSettings.attendanceTypes
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitstypen'**
  String get typeSettingsAttendanceTypes;

  /// typeSettings.availableStatus
  ///
  /// In de, this message translates to:
  /// **'Verfügbare Anwesenheitsstatus'**
  String get typeSettingsAvailableStatus;

  /// typeSettings.checklist
  ///
  /// In de, this message translates to:
  /// **'Checkliste'**
  String get typeSettingsChecklist;

  /// typeSettings.checklistHelper
  ///
  /// In de, this message translates to:
  /// **'Aktiviere die Checkliste, um To-Dos für diesen Anwesenheitstyp zu definieren. Diese werden automatisch bei neuen Terminen übernommen.'**
  String get typeSettingsChecklistHelper;

  /// typeSettings.circleHint
  ///
  /// In de, this message translates to:
  /// **'Den Personenkreis legst du wie gewohnt über relevante Gruppen oder unter „Filter“ mit einem Zusatzfeld fest (z. B. Ja/Nein-Feld „Tontechnik“). Dienste zählen in die Anwesenheitsquote, aber nur für eingeteilte Personen.'**
  String get typeSettingsCircleHint;

  /// typeSettings.color
  ///
  /// In de, this message translates to:
  /// **'Farbe'**
  String get typeSettingsColor;

  /// typeSettings.colorHint
  ///
  /// In de, this message translates to:
  /// **'Die Farbe ist nur für den Kalender relevant (beim Anlegen einer Anwesenheit).'**
  String get typeSettingsColorHint;

  /// typeSettings.configureReminders
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen konfigurieren'**
  String get typeSettingsConfigureReminders;

  /// typeSettings.countForAvg
  ///
  /// In de, this message translates to:
  /// **'Für Ø berücksichtigen'**
  String get typeSettingsCountForAvg;

  /// typeSettings.countForAvgHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn diese Option aktiviert ist, wird dieser Typ beim Anwesenheitsdurchschnitt berücksichtigt.'**
  String get typeSettingsCountForAvgHelper;

  /// typeSettings.createFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Erstellen des Anwesenheitstyps'**
  String get typeSettingsCreateFailed;

  /// typeSettings.created
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitstyp erfolgreich erstellt'**
  String get typeSettingsCreated;

  /// typeSettings.custom
  ///
  /// In de, this message translates to:
  /// **'Benutzerdefiniert'**
  String get typeSettingsCustom;

  /// typeSettings.customDots
  ///
  /// In de, this message translates to:
  /// **'Benutzerdefiniert...'**
  String get typeSettingsCustomDots;

  /// typeSettings.daysBeforeN
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Tag vorher} other {{count} Tage vorher}}'**
  String typeSettingsDaysBeforeN(num count);

  /// typeSettings.deadline
  ///
  /// In de, this message translates to:
  /// **'Deadline'**
  String get typeSettingsDeadline;

  /// typeSettings.defaultDays
  ///
  /// In de, this message translates to:
  /// **'Standarddauer (in Tagen)'**
  String get typeSettingsDefaultDays;

  /// typeSettings.defaultStatus
  ///
  /// In de, this message translates to:
  /// **'Standard Anwesenheitsstatus'**
  String get typeSettingsDefaultStatus;

  /// typeSettings.deleteFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Löschen des Anwesenheitstyps'**
  String get typeSettingsDeleteFailed;

  /// typeSettings.deleteType
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitstyp löschen'**
  String get typeSettingsDeleteType;

  /// typeSettings.deleteTypeMessage
  ///
  /// In de, this message translates to:
  /// **'Möchtest du den Anwesenheitstyp „{name}“ wirklich löschen? Alle Anwesenheiten dieses Typs werden ebenfalls gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.'**
  String typeSettingsDeleteTypeMessage(Object name);

  /// typeSettings.deleted
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitstyp erfolgreich gelöscht'**
  String get typeSettingsDeleted;

  /// typeSettings.discardChanges
  ///
  /// In de, this message translates to:
  /// **'Änderungen verwerfen?'**
  String get typeSettingsDiscardChanges;

  /// typeSettings.discardMessage
  ///
  /// In de, this message translates to:
  /// **'Du hast bereits Daten eingegeben. Möchtest du diese wirklich verwerfen?'**
  String get typeSettingsDiscardMessage;

  /// typeSettings.dutyHelper
  ///
  /// In de, this message translates to:
  /// **'Für Dienste wie Tontechnik: Pro Termin wird eine feste Zahl Personen eingeteilt. Nur Eingeteilte sind erwartet, alle anderen aus dem Personenkreis sind Springer.'**
  String get typeSettingsDutyHelper;

  /// typeSettings.dutyMode
  ///
  /// In de, this message translates to:
  /// **'Dienst-Modus'**
  String get typeSettingsDutyMode;

  /// typeSettings.dutyRoster
  ///
  /// In de, this message translates to:
  /// **'Dienstplan'**
  String get typeSettingsDutyRoster;

  /// typeSettings.dutyViewActive
  ///
  /// In de, this message translates to:
  /// **'Dienstplan-Ansicht ist aktiv'**
  String get typeSettingsDutyViewActive;

  /// typeSettings.editField
  ///
  /// In de, this message translates to:
  /// **'Feld bearbeiten'**
  String get typeSettingsEditField;

  /// typeSettings.editTodo
  ///
  /// In de, this message translates to:
  /// **'To-Do bearbeiten'**
  String get typeSettingsEditTodo;

  /// typeSettings.enableChecklist
  ///
  /// In de, this message translates to:
  /// **'Checkliste aktivieren'**
  String get typeSettingsEnableChecklist;

  /// typeSettings.enableLocation
  ///
  /// In de, this message translates to:
  /// **'Ort / Navigation aktivieren'**
  String get typeSettingsEnableLocation;

  /// typeSettings.end
  ///
  /// In de, this message translates to:
  /// **'Ende'**
  String get typeSettingsEnd;

  /// typeSettings.enterFieldLabel
  ///
  /// In de, this message translates to:
  /// **'Bitte eine Feldbezeichnung eingeben'**
  String get typeSettingsEnterFieldLabel;

  /// typeSettings.enterItem
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Programmpunkt eingeben.'**
  String get typeSettingsEnterItem;

  /// typeSettings.enterName
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Namen für den Anwesenheitstyp eingeben.'**
  String get typeSettingsEnterName;

  /// typeSettings.enterTodo
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Text für das To-Do eingeben'**
  String get typeSettingsEnterTodo;

  /// typeSettings.eventReminder
  ///
  /// In de, this message translates to:
  /// **'Terminerinnerung'**
  String get typeSettingsEventReminder;

  /// typeSettings.eventReminderHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn diese Option aktiviert ist, Erinnerungen angelegt wurden und die Benachrichtigungen aktiviert sind, erhalten Personen eine Terminerinnerung.'**
  String get typeSettingsEventReminderHelper;

  /// typeSettings.eventReminders
  ///
  /// In de, this message translates to:
  /// **'Terminerinnerungen'**
  String get typeSettingsEventReminders;

  /// typeSettings.extraFilter
  ///
  /// In de, this message translates to:
  /// **'Zusatzfeld-Filter'**
  String get typeSettingsExtraFilter;

  /// typeSettings.extraFilterHelper
  ///
  /// In de, this message translates to:
  /// **'Nur Personen mit dem ausgewählten Zusatzfeld-Wert werden beim Anlegen einer Anwesenheit von diesem Typ berücksichtigt.'**
  String get typeSettingsExtraFilterHelper;

  /// typeSettings.fieldLabel
  ///
  /// In de, this message translates to:
  /// **'Feldbezeichnung'**
  String get typeSettingsFieldLabel;

  /// typeSettings.fieldLabelPh
  ///
  /// In de, this message translates to:
  /// **'z.B. Instrument mitbringen?'**
  String get typeSettingsFieldLabelPh;

  /// typeSettings.filter
  ///
  /// In de, this message translates to:
  /// **'Filter'**
  String get typeSettingsFilter;

  /// typeSettings.flutter.allGroupsHint
  ///
  /// In de, this message translates to:
  /// **'Leer = gilt für alle Gruppen'**
  String get typeSettingsFlutterAllGroupsHint;

  /// typeSettings.flutter.createType
  ///
  /// In de, this message translates to:
  /// **'Typ erstellen'**
  String get typeSettingsFlutterCreateType;

  /// typeSettings.flutter.createdNamed
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitstyp \"{name}\" erstellt'**
  String typeSettingsFlutterCreatedNamed(Object name);

  /// typeSettings.flutter.deadlineLabel
  ///
  /// In de, this message translates to:
  /// **'Frist (Stunden vorher, optional)'**
  String get typeSettingsFlutterDeadlineLabel;

  /// typeSettings.flutter.deadlinePh
  ///
  /// In de, this message translates to:
  /// **'z.B. 24 für 1 Tag'**
  String get typeSettingsFlutterDeadlinePh;

  /// typeSettings.flutter.durationMinutes
  ///
  /// In de, this message translates to:
  /// **'Dauer (Minuten)'**
  String get typeSettingsFlutterDurationMinutes;

  /// typeSettings.flutter.durationPh
  ///
  /// In de, this message translates to:
  /// **'z.B. 10'**
  String get typeSettingsFlutterDurationPh;

  /// typeSettings.flutter.extraField
  ///
  /// In de, this message translates to:
  /// **'Zusatzfeld'**
  String get typeSettingsFlutterExtraField;

  /// typeSettings.flutter.extraFilterHint
  ///
  /// In de, this message translates to:
  /// **'Nur Spieler mit diesem Zusatzfeld-Wert einbeziehen'**
  String get typeSettingsFlutterExtraFilterHint;

  /// typeSettings.flutter.fieldNamePh
  ///
  /// In de, this message translates to:
  /// **'z.B. Einspielen, Pause'**
  String get typeSettingsFlutterFieldNamePh;

  /// typeSettings.flutter.hidden
  ///
  /// In de, this message translates to:
  /// **'Ausgeblendet'**
  String get typeSettingsFlutterHidden;

  /// typeSettings.flutter.minutes
  ///
  /// In de, this message translates to:
  /// **'{minutes} Min.'**
  String typeSettingsFlutterMinutes(Object minutes);

  /// typeSettings.flutter.namePh
  ///
  /// In de, this message translates to:
  /// **'z.B. Probe, Konzert, Generalprobe'**
  String get typeSettingsFlutterNamePh;

  /// typeSettings.flutter.namePhShort
  ///
  /// In de, this message translates to:
  /// **'z.B. Probe, Konzert'**
  String get typeSettingsFlutterNamePhShort;

  /// typeSettings.flutter.newField
  ///
  /// In de, this message translates to:
  /// **'Neues Feld'**
  String get typeSettingsFlutterNewField;

  /// typeSettings.flutter.newType
  ///
  /// In de, this message translates to:
  /// **'Neuer Anwesenheitstyp'**
  String get typeSettingsFlutterNewType;

  /// typeSettings.flutter.noTypes
  ///
  /// In de, this message translates to:
  /// **'Keine Anwesenheitstypen vorhanden'**
  String get typeSettingsFlutterNoTypes;

  /// typeSettings.flutter.notFound
  ///
  /// In de, this message translates to:
  /// **'Typ nicht gefunden'**
  String get typeSettingsFlutterNotFound;

  /// typeSettings.flutter.planHeadingPh
  ///
  /// In de, this message translates to:
  /// **'z.B. Probenplan'**
  String get typeSettingsFlutterPlanHeadingPh;

  /// typeSettings.flutter.reorder
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge ändern'**
  String get typeSettingsFlutterReorder;

  /// typeSettings.flutter.saveOrderFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern. Bitte erneut versuchen.'**
  String get typeSettingsFlutterSaveOrderFailed;

  /// typeSettings.flutter.todoPh
  ///
  /// In de, this message translates to:
  /// **'z.B. Noten vorbereiten'**
  String get typeSettingsFlutterTodoPh;

  /// typeSettings.flutter.totalMinutes
  ///
  /// In de, this message translates to:
  /// **'Gesamt: {minutes} Min.'**
  String typeSettingsFlutterTotalMinutes(Object minutes);

  /// typeSettings.flutter.typeTitle
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitstyp'**
  String get typeSettingsFlutterTypeTitle;

  /// typeSettings.flutter.usageWarning
  ///
  /// In de, this message translates to:
  /// **'Wird in {count} Termin(en) verwendet. Änderungen wirken sich auf bestehende Einträge aus.'**
  String typeSettingsFlutterUsageWarning(Object count);

  /// typeSettings.flutter.withProgramme
  ///
  /// In de, this message translates to:
  /// **'Mit Programm'**
  String get typeSettingsFlutterWithProgramme;

  /// typeSettings.freeTextPh
  ///
  /// In de, this message translates to:
  /// **'Freitext eingeben...'**
  String get typeSettingsFreeTextPh;

  /// typeSettings.h12
  ///
  /// In de, this message translates to:
  /// **'12 h vorher'**
  String get typeSettingsH12;

  /// typeSettings.h24
  ///
  /// In de, this message translates to:
  /// **'24 h vorher'**
  String get typeSettingsH24;

  /// typeSettings.h48
  ///
  /// In de, this message translates to:
  /// **'48 h vorher'**
  String get typeSettingsH48;

  /// typeSettings.h6
  ///
  /// In de, this message translates to:
  /// **'6 h vorher'**
  String get typeSettingsH6;

  /// typeSettings.h72
  ///
  /// In de, this message translates to:
  /// **'72 h vorher'**
  String get typeSettingsH72;

  /// typeSettings.hideName
  ///
  /// In de, this message translates to:
  /// **'Name verbergen'**
  String get typeSettingsHideName;

  /// typeSettings.hideNameHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn du diese Option aktivierst, wird der Name dieses Anwesenheitstyps in der Liste verborgen. Nur die Zusatzinfo (falls vorhanden) wird angezeigt.'**
  String get typeSettingsHideNameHelper;

  /// typeSettings.highlight
  ///
  /// In de, this message translates to:
  /// **'Hervorheben'**
  String get typeSettingsHighlight;

  /// typeSettings.highlightHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn du diese Option aktivierst, wird dieser Anwesenheitstyp in der Liste als Fett dargestellt.'**
  String get typeSettingsHighlightHelper;

  /// typeSettings.hoursBefore
  ///
  /// In de, this message translates to:
  /// **'Stunden vor Termin'**
  String get typeSettingsHoursBefore;

  /// typeSettings.hoursBeforeN
  ///
  /// In de, this message translates to:
  /// **'{count, plural, one {{count} Stunde vorher} other {{count} Stunden vorher}}'**
  String typeSettingsHoursBeforeN(num count);

  /// typeSettings.hoursBeforeStart
  ///
  /// In de, this message translates to:
  /// **'{count} Stunde(n) vor Terminbeginn'**
  String typeSettingsHoursBeforeStart(Object count);

  /// typeSettings.hoursPlaceholder
  ///
  /// In de, this message translates to:
  /// **'z.B. 12 für 12 Stunden vorher'**
  String get typeSettingsHoursPlaceholder;

  /// typeSettings.howEvery5
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen werden <strong>alle 5 Minuten</strong> geprüft und versendet.'**
  String get typeSettingsHowEvery5;

  /// typeSettings.howMax
  ///
  /// In de, this message translates to:
  /// **'Maximal <strong>3 Erinnerungen</strong> pro Termintyp möglich.'**
  String get typeSettingsHowMax;

  /// typeSettings.howRemaining
  ///
  /// In de, this message translates to:
  /// **'Die Erinnerung wird versendet, sobald die <strong>verbleibende Zeit</strong> dem konfigurierten Wert entspricht.'**
  String get typeSettingsHowRemaining;

  /// typeSettings.howReminders
  ///
  /// In de, this message translates to:
  /// **'So funktionieren Erinnerungen'**
  String get typeSettingsHowReminders;

  /// typeSettings.info
  ///
  /// In de, this message translates to:
  /// **'Info'**
  String get typeSettingsInfo;

  /// typeSettings.infoOptional
  ///
  /// In de, this message translates to:
  /// **'Info-Text (optional)'**
  String get typeSettingsInfoOptional;

  /// typeSettings.infoOptionalDots
  ///
  /// In de, this message translates to:
  /// **'Info-Text (optional)...'**
  String get typeSettingsInfoOptionalDots;

  /// typeSettings.insertPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Platzhalter einfügen'**
  String get typeSettingsInsertPlaceholder;

  /// typeSettings.learnMore
  ///
  /// In de, this message translates to:
  /// **'Mehr erfahren'**
  String get typeSettingsLearnMore;

  /// typeSettings.locationHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn aktiviert, kann bei Terminen dieses Typs ein Ort hinterlegt werden. Dieser wird dann als Navigationslink in Google Maps oder Apple Karten angezeigt.'**
  String get typeSettingsLocationHelper;

  /// typeSettings.manageSongs
  ///
  /// In de, this message translates to:
  /// **'Werke verwalten'**
  String get typeSettingsManageSongs;

  /// typeSettings.max3
  ///
  /// In de, this message translates to:
  /// **'Maximal 3 Erinnerungen pro Typ möglich'**
  String get typeSettingsMax3;

  /// typeSettings.maxReached
  ///
  /// In de, this message translates to:
  /// **'Maximum von 3 Erinnerungen erreicht. Entferne eine bestehende Erinnerung, um eine neue hinzuzufügen.'**
  String get typeSettingsMaxReached;

  /// typeSettings.minPh
  ///
  /// In de, this message translates to:
  /// **'min'**
  String get typeSettingsMinPh;

  /// typeSettings.multi
  ///
  /// In de, this message translates to:
  /// **'Mehrfachauswahl'**
  String get typeSettingsMulti;

  /// typeSettings.name
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get typeSettingsName;

  /// typeSettings.neededPeople
  ///
  /// In de, this message translates to:
  /// **'Benötigte Personen'**
  String get typeSettingsNeededPeople;

  /// typeSettings.newTodo
  ///
  /// In de, this message translates to:
  /// **'Neues To-Do'**
  String get typeSettingsNewTodo;

  /// typeSettings.noDeadline
  ///
  /// In de, this message translates to:
  /// **'Keine Deadline'**
  String get typeSettingsNoDeadline;

  /// typeSettings.noFilter
  ///
  /// In de, this message translates to:
  /// **'Kein Filter'**
  String get typeSettingsNoFilter;

  /// typeSettings.noReminders
  ///
  /// In de, this message translates to:
  /// **'Keine Erinnerungen konfiguriert'**
  String get typeSettingsNoReminders;

  /// typeSettings.noRemindersYet
  ///
  /// In de, this message translates to:
  /// **'Noch keine Erinnerungen konfiguriert'**
  String get typeSettingsNoRemindersYet;

  /// typeSettings.noSignupFields
  ///
  /// In de, this message translates to:
  /// **'Keine Anmeldefelder konfiguriert'**
  String get typeSettingsNoSignupFields;

  /// typeSettings.noTodos
  ///
  /// In de, this message translates to:
  /// **'Noch keine To-Dos angelegt'**
  String get typeSettingsNoTodos;

  /// typeSettings.normalView
  ///
  /// In de, this message translates to:
  /// **'Nein, normale Ansicht'**
  String get typeSettingsNormalView;

  /// typeSettings.note
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get typeSettingsNote;

  /// typeSettings.notePh
  ///
  /// In de, this message translates to:
  /// **'Notiz eingeben...'**
  String get typeSettingsNotePh;

  /// typeSettings.notifyGroup
  ///
  /// In de, this message translates to:
  /// **'Gruppe bei Ausfall benachrichtigen'**
  String get typeSettingsNotifyGroup;

  /// typeSettings.notifyGroupHelper
  ///
  /// In de, this message translates to:
  /// **'Sagt eine eingeteilte Person ab und der Dienst ist unterbesetzt, bekommen alle aus dem Personenkreis eine Nachricht.'**
  String get typeSettingsNotifyGroupHelper;

  /// typeSettings.off
  ///
  /// In de, this message translates to:
  /// **'Aus'**
  String get typeSettingsOff;

  /// typeSettings.option
  ///
  /// In de, this message translates to:
  /// **'Option'**
  String get typeSettingsOption;

  /// typeSettings.options
  ///
  /// In de, this message translates to:
  /// **'Optionen'**
  String get typeSettingsOptions;

  /// typeSettings.optionsComma
  ///
  /// In de, this message translates to:
  /// **'Optionen (kommagetrennt)'**
  String get typeSettingsOptionsComma;

  /// typeSettings.optionsPh
  ///
  /// In de, this message translates to:
  /// **'Option A, Option B, Option C'**
  String get typeSettingsOptionsPh;

  /// typeSettings.orderSaved
  ///
  /// In de, this message translates to:
  /// **'Reihenfolge gespeichert'**
  String get typeSettingsOrderSaved;

  /// typeSettings.orgPlanDefault
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan ist standardmäßig ein Organisationsplan'**
  String get typeSettingsOrgPlanDefault;

  /// typeSettings.performer
  ///
  /// In de, this message translates to:
  /// **'Ausführender'**
  String get typeSettingsPerformer;

  /// typeSettings.performerPh
  ///
  /// In de, this message translates to:
  /// **'Ausführenden eingeben...'**
  String get typeSettingsPerformerPh;

  /// typeSettings.placeholderHint
  ///
  /// In de, this message translates to:
  /// **'Der Platzhalter „Tagesordnung“ im Standard-Ablaufplan legt fest, wo Themen eingefügt werden. Ohne Platzhalter landen sie am Ende.'**
  String get typeSettingsPlaceholderHint;

  /// typeSettings.planHeading
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan Überschrift'**
  String get typeSettingsPlanHeading;

  /// typeSettings.positiveInt
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie eine positive Ganzzahl ein'**
  String get typeSettingsPositiveInt;

  /// typeSettings.postponedHelper
  ///
  /// In de, this message translates to:
  /// **'Beim nächsten Termin dieses Typs stehen vertagte Themen beim Aufnehmen ganz oben.'**
  String get typeSettingsPostponedHelper;

  /// typeSettings.programmeItem
  ///
  /// In de, this message translates to:
  /// **'Programmpunkt'**
  String get typeSettingsProgrammeItem;

  /// typeSettings.programmeItemPh
  ///
  /// In de, this message translates to:
  /// **'Programmpunkt eingeben...'**
  String get typeSettingsProgrammeItemPh;

  /// typeSettings.protocolAgenda
  ///
  /// In de, this message translates to:
  /// **'Protokoll & Tagesordnung'**
  String get typeSettingsProtocolAgenda;

  /// typeSettings.protocolHelper
  ///
  /// In de, this message translates to:
  /// **'Termine dieses Typs bekommen eine Tagesordnung im Ablaufplan und ein Protokoll. Wer dazugehört, regeln die relevanten Gruppen.'**
  String get typeSettingsProtocolHelper;

  /// typeSettings.quickSelect
  ///
  /// In de, this message translates to:
  /// **'Schnellauswahl'**
  String get typeSettingsQuickSelect;

  /// typeSettings.relevantGroups
  ///
  /// In de, this message translates to:
  /// **'Relevante Gruppen'**
  String get typeSettingsRelevantGroups;

  /// typeSettings.relevantGroupsHelper
  ///
  /// In de, this message translates to:
  /// **'Nur die relevanten Gruppen werden beim Anlegen einer Anwesenheit von diesem Typ berücksichtigt. Wenn keine Gruppe ausgewählt ist, werden alle Gruppen berücksichtigt.'**
  String get typeSettingsRelevantGroupsHelper;

  /// typeSettings.remindUnconfirmed
  ///
  /// In de, this message translates to:
  /// **'Erinnern, wenn unbestätigt'**
  String get typeSettingsRemindUnconfirmed;

  /// typeSettings.reminderExists
  ///
  /// In de, this message translates to:
  /// **'Diese Erinnerung existiert bereits'**
  String get typeSettingsReminderExists;

  /// typeSettings.reminders
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen'**
  String get typeSettingsReminders;

  /// typeSettings.remindersActive
  ///
  /// In de, this message translates to:
  /// **'{count} Erinnerung(en) aktiv'**
  String typeSettingsRemindersActive(Object count);

  /// typeSettings.runSheet
  ///
  /// In de, this message translates to:
  /// **'Ablaufplan'**
  String get typeSettingsRunSheet;

  /// typeSettings.sameTime
  ///
  /// In de, this message translates to:
  /// **'Zur gleichen Zeit'**
  String get typeSettingsSameTime;

  /// typeSettings.savingOrder
  ///
  /// In de, this message translates to:
  /// **'Speichere Reihenfolge...'**
  String get typeSettingsSavingOrder;

  /// typeSettings.selectFieldType
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Feldtyp auswählen'**
  String get typeSettingsSelectFieldType;

  /// typeSettings.selfAssign
  ///
  /// In de, this message translates to:
  /// **'Selbst eintragen erlaubt'**
  String get typeSettingsSelfAssign;

  /// typeSettings.selfAssignHelper
  ///
  /// In de, this message translates to:
  /// **'Personen aus dem Personenkreis können offene Dienste selbst übernehmen.'**
  String get typeSettingsSelfAssignHelper;

  /// typeSettings.signupFields
  ///
  /// In de, this message translates to:
  /// **'Anmeldefelder'**
  String get typeSettingsSignupFields;

  /// typeSettings.single
  ///
  /// In de, this message translates to:
  /// **'Einzelauswahl'**
  String get typeSettingsSingle;

  /// typeSettings.songPlaceholder
  ///
  /// In de, this message translates to:
  /// **'Werk Platzhalter'**
  String get typeSettingsSongPlaceholder;

  /// typeSettings.songPlaceholderN
  ///
  /// In de, this message translates to:
  /// **'Werk Platzhalter {n}'**
  String typeSettingsSongPlaceholderN(Object n);

  /// typeSettings.songsHelper
  ///
  /// In de, this message translates to:
  /// **'Wenn du diese Option aktivierst, dann kannst du beim Anlegen einer Anwesenheit von diesem Typ, Werke hinzufügen, die für die kommenden Proben relevant sind und automatisch im Probenplan berücksichtigt werden.'**
  String get typeSettingsSongsHelper;

  /// typeSettings.start
  ///
  /// In de, this message translates to:
  /// **'Beginn'**
  String get typeSettingsStart;

  /// typeSettings.startAllDay
  ///
  /// In de, this message translates to:
  /// **'Startzeit für den Ablaufplan bei ganztägigen Terminen'**
  String get typeSettingsStartAllDay;

  /// typeSettings.startShort
  ///
  /// In de, this message translates to:
  /// **'Start'**
  String get typeSettingsStartShort;

  /// typeSettings.suggestPostponed
  ///
  /// In de, this message translates to:
  /// **'Vertagte Themen vorschlagen'**
  String get typeSettingsSuggestPostponed;

  /// typeSettings.tenantNameBefore
  ///
  /// In de, this message translates to:
  /// **'Instanz-Name vor Werken'**
  String get typeSettingsTenantNameBefore;

  /// typeSettings.tenantNameHelper
  ///
  /// In de, this message translates to:
  /// **'Falls aktiviert, wird der Instanz-Name vor jedem Werk im Ablaufplan angezeigt.'**
  String get typeSettingsTenantNameHelper;

  /// typeSettings.text
  ///
  /// In de, this message translates to:
  /// **'Text'**
  String get typeSettingsText;

  /// typeSettings.timesHint
  ///
  /// In de, this message translates to:
  /// **'Die Zeiten können nachträglich individuell in jeder Anwesenheit angepasst werden'**
  String get typeSettingsTimesHint;

  /// typeSettings.titleHelper
  ///
  /// In de, this message translates to:
  /// **'Dieser Titel wird beim Exportieren eines Ablaufplans angezeigt. Falls eine Typ-Info vorhanden ist, wird diese in Klammern dahinter angezeigt. (z.B. Probenplan (Kantateprobe))'**
  String get typeSettingsTitleHelper;

  /// typeSettings.todoPlaceholder
  ///
  /// In de, this message translates to:
  /// **'To-Do Text eingeben...'**
  String get typeSettingsTodoPlaceholder;

  /// typeSettings.todoTextPh
  ///
  /// In de, this message translates to:
  /// **'To-Do Text...'**
  String get typeSettingsTodoTextPh;

  /// typeSettings.topicMinutes
  ///
  /// In de, this message translates to:
  /// **'Standarddauer pro Thema (Min.)'**
  String get typeSettingsTopicMinutes;

  /// typeSettings.topicsHere
  ///
  /// In de, this message translates to:
  /// **'Hier werden Themen eingefügt'**
  String get typeSettingsTopicsHere;

  /// typeSettings.twoOptions
  ///
  /// In de, this message translates to:
  /// **'Bitte mindestens 2 Optionen angeben'**
  String get typeSettingsTwoOptions;

  /// typeSettings.twoStatus
  ///
  /// In de, this message translates to:
  /// **'Bitte mindestens zwei verfügbare Anwesenheitsstatus auswählen.'**
  String get typeSettingsTwoStatus;

  /// typeSettings.type
  ///
  /// In de, this message translates to:
  /// **'Typ'**
  String get typeSettingsType;

  /// typeSettings.types
  ///
  /// In de, this message translates to:
  /// **'Typen'**
  String get typeSettingsTypes;

  /// typeSettings.typesIntro
  ///
  /// In de, this message translates to:
  /// **'Pflege deine eigenen Typen für Anwesenheiten. So kannst du individuelle Bezeichnungen, einen Standard-Status, Probenvorlagen und Start- bzw. Endzeiten hinterlegen und auch Anwesenheiten nur für bestimmte Gruppen konfigurieren.'**
  String get typeSettingsTypesIntro;

  /// typeSettings.update
  ///
  /// In de, this message translates to:
  /// **'Updaten'**
  String get typeSettingsUpdate;

  /// typeSettings.updateFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Aktualisieren des Anwesenheitstyps'**
  String get typeSettingsUpdateFailed;

  /// typeSettings.updated
  ///
  /// In de, this message translates to:
  /// **'Anwesenheitstyp erfolgreich aktualisiert'**
  String get typeSettingsUpdated;

  /// typeSettings.urgentHelper
  ///
  /// In de, this message translates to:
  /// **'Einmaliger dringender Push an alle aus dem Personenkreis und die Leitung.'**
  String get typeSettingsUrgentHelper;

  /// typeSettings.urgentIfOpen
  ///
  /// In de, this message translates to:
  /// **'Dringend, wenn noch offen'**
  String get typeSettingsUrgentIfOpen;

  /// typeSettings.useDutyView
  ///
  /// In de, this message translates to:
  /// **'Dienstplan-Ansicht verwenden?'**
  String get typeSettingsUseDutyView;

  /// typeSettings.useDutyViewMessage
  ///
  /// In de, this message translates to:
  /// **'Sind Dienste bei euch der Normalfall? Dann zeigt „Meine Termine“ für alle im Dienst-Team zuerst ihre Dienste, offene Dienste und Zahlen statt der Anwesenheitsquote. Du kannst das jederzeit unter Mehr → Einstellungen ändern.'**
  String get typeSettingsUseDutyViewMessage;

  /// typeSettings.useIt
  ///
  /// In de, this message translates to:
  /// **'Ja, verwenden'**
  String get typeSettingsUseIt;

  /// typeSettings.validHours
  ///
  /// In de, this message translates to:
  /// **'Gültige Werte: 0-168 Stunden (max. 1 Woche vorher)'**
  String get typeSettingsValidHours;

  /// typeSettings.value
  ///
  /// In de, this message translates to:
  /// **'Wert'**
  String get typeSettingsValue;

  /// typeSettings.viewFailed
  ///
  /// In de, this message translates to:
  /// **'Konnte die Ansicht nicht umstellen'**
  String get typeSettingsViewFailed;

  /// typeSettings.yesNo
  ///
  /// In de, this message translates to:
  /// **'Ja / Nein'**
  String get typeSettingsYesNo;

  /// usage.active7
  ///
  /// In de, this message translates to:
  /// **'Aktiv (7T)'**
  String get usageActive7;

  /// usage.activeTenants
  ///
  /// In de, this message translates to:
  /// **'Aktive Instanzen'**
  String get usageActiveTenants;

  /// usage.days30
  ///
  /// In de, this message translates to:
  /// **'30 Tage'**
  String get usageDays30;

  /// usage.days7
  ///
  /// In de, this message translates to:
  /// **'7 Tage'**
  String get usageDays7;

  /// usage.days90
  ///
  /// In de, this message translates to:
  /// **'90 Tage'**
  String get usageDays90;

  /// usage.devices
  ///
  /// In de, this message translates to:
  /// **'Geräte'**
  String get usageDevices;

  /// usage.distribution
  ///
  /// In de, this message translates to:
  /// **'Event-Verteilung'**
  String get usageDistribution;

  /// usage.eventsPerDay
  ///
  /// In de, this message translates to:
  /// **'Events pro Tag'**
  String get usageEventsPerDay;

  /// usage.noEvents
  ///
  /// In de, this message translates to:
  /// **'Keine Events im gewählten Zeitraum.'**
  String get usageNoEvents;

  /// usage.title
  ///
  /// In de, this message translates to:
  /// **'Usage Dashboard'**
  String get usageTitle;

  /// usage.topEvent
  ///
  /// In de, this message translates to:
  /// **'Top Event'**
  String get usageTopEvent;

  /// usage.topEvents
  ///
  /// In de, this message translates to:
  /// **'Top Events'**
  String get usageTopEvents;

  /// usage.topTenants
  ///
  /// In de, this message translates to:
  /// **'Top Instanzen'**
  String get usageTopTenants;

  /// usage.totalEvents
  ///
  /// In de, this message translates to:
  /// **'Events gesamt'**
  String get usageTotalEvents;

  /// voiceLeader.flutter.memberCount
  ///
  /// In de, this message translates to:
  /// **'{count} Mitglieder'**
  String voiceLeaderFlutterMemberCount(Object count);

  /// voiceLeader.flutter.moreCount
  ///
  /// In de, this message translates to:
  /// **'+{count} weitere'**
  String voiceLeaderFlutterMoreCount(Object count);

  /// voiceLeader.flutter.noGroup
  ///
  /// In de, this message translates to:
  /// **'Du bist noch keiner Stimmgruppe zugeordnet.'**
  String get voiceLeaderFlutterNoGroup;

  /// voiceLeader.flutter.voiceGroup
  ///
  /// In de, this message translates to:
  /// **'Stimmgruppe'**
  String get voiceLeaderFlutterVoiceGroup;

  /// voiceLeader.loadFailed
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Gruppenmitglieder.'**
  String get voiceLeaderLoadFailed;

  /// voiceLeader.myVoice
  ///
  /// In de, this message translates to:
  /// **'Meine Stimme'**
  String get voiceLeaderMyVoice;

  /// voiceLeader.noContact
  ///
  /// In de, this message translates to:
  /// **'Keine Kontaktdaten hinterlegt'**
  String get voiceLeaderNoContact;

  /// voiceLeader.noMembers
  ///
  /// In de, this message translates to:
  /// **'Keine Mitglieder in deiner Stimme gefunden.'**
  String get voiceLeaderNoMembers;

  /// voiceLeader.noProfile
  ///
  /// In de, this message translates to:
  /// **'Kein Spielerprofil gefunden.'**
  String get voiceLeaderNoProfile;

  /// voiceLeader.profilePicture
  ///
  /// In de, this message translates to:
  /// **'Profilbild'**
  String get voiceLeaderProfilePicture;

  /// voiceLeader.sfShort
  ///
  /// In de, this message translates to:
  /// **'Sf'**
  String get voiceLeaderSfShort;

  /// voiceLeader.upcomingAbsences
  ///
  /// In de, this message translates to:
  /// **'Anstehende Abwesenheiten:'**
  String get voiceLeaderUpcomingAbsences;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
