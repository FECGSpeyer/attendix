# Fix-Paket „app“

Soll: Ionic 4.19.7 (9f9b82af). Ist: Flutter 1aba6be,  (normales Design).
Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.

## Angleichen (hoch/mittel): 17

- [ ] **hoch** `register/tenant-register/tenant-register.page` `field-ac71b961` [register/tenant-register/tenant-register.page.html:165](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.html#L165) (2. Prüfung: bestätigt)
  Ionic: ion-select mit defaultValue vorbelegt, Wert wird immer in additional_fields gespeichert / Flutter: Default nur angezeigt, ohne aktive Auswahl fehlt der Schlüssel in additional_fields (anderer DB-Wert; Leser fallen zwar auf defaultValue zurück, der gespeicherte Datensatz unterscheidet sich).
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:525-549
- [ ] **hoch** `register/tenant-register/tenant-register.page` [src/app/register/tenant-register/tenant-register.page.ts:304](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L304)
  Ionic: additional_fields[id] = field.value (mit defaultValue vorbelegt) für jedes Feld / Flutter: Auswahlfeld wird nur nach aktiver Auswahl in additional_fields geschrieben; unverändert fehlt der Default im gespeicherten Datensatz.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:527, lib/features/registration/data/providers/registration_providers.dart:334
- [ ] **mittel** `app-routing.module` `route-d98e9634` [register/register-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/register-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Ionic: /register = Instanz anlegen mit RegisterGuard (abgemeldet → /login, ohne Instanz → Anlegen, mit Instanz → getUrl(role)) / Flutter: /register ist das öffentliche Konto-Registrierungsformular; angemeldet ohne Instanz → /tenants (Liste mit „Neue Instanz anlegen“), mit Instanz → homeRouteFor. Instanz anlegen liegt unter /tenants/new.
  Flutter: lib/core/router/app_router.dart:449-455, lib/core/router/app_router.dart:289-310
- [ ] **mittel** `app-routing.module` [src/app/tabs/tabs-routing.module.ts](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/tabs/tabs-routing.module.ts)
  Ionic: /tabs/settings/general/shifts(/:id) öffnet Schichten / Flutter: legacyRouteRedirect → /settings/general/shifts, keine solche Route → Fehlerseite "Seite nicht gefunden".
  Flutter: lib/core/router/legacy_routes.dart:93-98, lib/core/router/app_router.dart:1109-1124
- [ ] **mittel** `app.component` `alert-df60fa5d` [app.component.ts:113](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L113) (2. Prüfung: bestätigt)
  Ionic: Alert „Neues Passwort“ mit Passwortfeld (Platzhalter „Min. 6 Zeichen eingeben...“), Buttons Abbrechen/Passwort ändern, bleibt bei Fehler offen / Flutter: eigene Seite /new-password, nach Erfolg oder Abbrechen → /tenants. Gleiche Mindestlänge, anderer Dialogtyp/Flow.
  Flutter: lib/features/auth/presentation/pages/new_password_page.dart:34-115
- [ ] **mittel** `app.component` `nav-3a7bceb6-2` [app.component.ts:352](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L352) (2. Prüfung: bestätigt)
  Ionic: Recovery-Link → /login; LoginGuard leitet Nutzer mit Instanz weiter auf die Startseite, der Alert erscheint dort / Flutter: Recovery-Link → Seite /new-password.
  Flutter: lib/features/auth/data/auth_link_listener.dart:119-120
- [ ] **mittel** `app.component` [src/app/app.component.ts:108-160](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L108-160)
  Ionic: PASSWORD_RECOVERY-Event/Recovery-Link öffnet Alert "Neues Passwort" über der Login-Seite / Flutter: Navigation auf eigene Seite /new-password.
  Flutter: lib/features/auth/data/auth_link_listener.dart:119-120, lib/features/auth/presentation/pages/new_password_page.dart:34-115
- [ ] **mittel** `register/register.page` `popover-f947f492` [register/register.page.html:130](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/register.page.html#L130) (2. Prüfung: bestätigt)
  Ionic: Info-Popover am Info-Icon (Hauptgruppe) / Flutter: AlertDialog mit gleichem Text und OK-Button.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_create_page.dart:347-351, lib/features/tenant_selection/presentation/pages/tenant_create_page.dart:541-558
- [ ] **mittel** `register/tenant-register/tenant-register.page` `toast-23c76f81` [register/tenant-register/tenant-register.page.ts:456](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L456) (2. Prüfung: bestätigt)
  Ionic: Ja/Nein-Feld ohne booleschen Wert → Toast „Bitte geben Sie einen gültigen Wert für das Feld "…" ein.“ und Abbruch / Flutter: kein Check, unberührter Schalter wird als false gespeichert. Selten, da Ionic beim Anlegen eines Ja/Nein-Felds defaultValue false setzt.
- [ ] **mittel** `register/tenant-register/tenant-register.page` `actionsheet-ab6f737a` [register/tenant-register/tenant-register.page.ts:480](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L480) (2. Prüfung: bestätigt)
  Ionic: bei vorhandenem Passbild Action-Sheet „Passbild ersetzen“/„Abbrechen“ vor der Dateiauswahl / Flutter: kein Action-Sheet, Tap öffnet direkt die Auswahl.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:283, lib/features/registration/presentation/pages/tenant_registration_page.dart:295
- [ ] **mittel** `register/tenant-register/tenant-register.page` `field-9f610a4d` [register/tenant-register/tenant-register.page.html:107](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.html#L107) (2. Prüfung: bestätigt)
  Ionic: Datei-Input accept=image/* (Systemauswahl inkl. Kamera/Dateien), Original wird hochgeladen / Flutter: ImagePicker Galerie; im Web bietet der Browser weiter Kamera an (Input ohne capture), in den nativen Apps nur Galerie; Bild auf 800×800, Qualität 80 verkleinert.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:590-600
- [ ] **mittel** `register/tenant-register/tenant-register.page` `field-a9922b49` [register/tenant-register/tenant-register.page.html:149](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.html#L149) (2. Prüfung: bestätigt)
  Ionic: Reihenfolge Kategorie, sort_order, Name; Filter maingroup !== true / Flutter: nur nach Name, Filter maingroup = false (NULL fällt raus). Dadurch ist auch die vorausgewählte erste Gruppe eine andere.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:350-395, lib/features/registration/data/providers/registration_providers.dart:33-46
- [ ] **mittel** `register/tenant-register/tenant-register.page` [src/app/services/group/group.service.ts:18](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/group/group.service.ts#L18)
  Ionic: getGroups sortiert nach Kategorie, sort_order, Name und filtert maingroup !== true / Flutter: registrationGroupsProvider sortiert nur nach Name, Filter .eq('maingroup', false) schließt NULL aus.
  Flutter: lib/features/registration/data/providers/registration_providers.dart:33
- [ ] **mittel** `register/tenant-register/tenant-register.page` [src/app/register/tenant-register/tenant-register.page.ts:77](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L77)
  Ionic: Zusatzfelder in der Reihenfolge von registration_fields / Flutter: in der Reihenfolge von tenant.additional_fields (gefiltert auf registration_fields).
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:468
- [ ] **mittel** `tabs/side-nav/side-nav.component` `modal-186fad14` [tabs/side-nav/side-nav.component.ts:144](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/tabs/side-nav/side-nav.component.ts#L144) (2. Prüfung: bestätigt)
  Ionic: „Ablaufpläne“ öffnet PlanningPage als Modal / Flutter: context.push('/planning') – normale Seite im Shell.
  Flutter: lib/shared/widgets/layout/side_nav/side_nav.dart:109, lib/core/router/app_router.dart:899-912
- [ ] **mittel** `terms/terms.page` `nav-4df0f2ac` [terms/terms.page.ts:61](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/terms/terms.page.ts#L61) (2. Prüfung: bestätigt)
  Ionic: nach Zustimmung direkt Utils.getUrl(role) / Flutter: gemerkter Link oder /tenants; nach Login ist die Instanz meist schon gesetzt, dann bleibt die Instanzauswahl stehen statt zur Startseite zu gehen.
  Flutter: lib/features/legal/presentation/pages/terms_page.dart:58, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:78-80
- [ ] **mittel** `terms/terms.page` [src/app/terms/terms.page.ts:61](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/terms/terms.page.ts#L61)
  Ionic: navigateByUrl(Utils.getUrl(tenantUser.role)) / Flutter: PendingFileLink oder /tenants; die Instanzauswahl leitet nur ohne aktive Instanz automatisch zur Startseite weiter.
  Flutter: lib/features/legal/presentation/pages/terms_page.dart:58, lib/core/router/app_router.dart:371, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:80

## Flutter besser – Leon entscheidet: 39

- [ ] **niedrig** `app-routing.module` `route-b64546c1` [tabs/tabs-routing.module.ts:9](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/tabs/tabs-routing.module.ts#L9)
  Flutter besser: /tabs ohne Anmeldung → Ionic: AuthGuard → /login, nach Login routeAfterAuth (Link geht verloren) / Flutter: Link wird gemerkt (PendingFileLink) und nach Login fortgesetzt; /tabs → /open-link → Rollen-Startseite.
  Flutter: lib/core/router/app_router.dart:276-441, lib/core/router/legacy_routes.dart:44-45
- [ ] **niedrig** `app-routing.module` `route-5a8aa5c8` [selfService/overview/overview-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/selfService/overview/overview-routing.module.ts#L7)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute. (Übersicht: Ionic Reload schickt Admin/Verantwortl./Beobachter auf /tabs/player.)
  Flutter: lib/core/router/route_access.dart:77-81
- [ ] **niedrig** `app-routing.module` `route-30a0910a` [people/members/members-routing.module.ts:6](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/people/members/members-routing.module.ts#L6)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute.
  Flutter: lib/core/router/route_access.dart:83-88
- [ ] **niedrig** `app-routing.module` `route-117fac13` [attendance/att-list/att-list-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/attendance/att-list/att-list-routing.module.ts#L7)
  Flutter besser: Ionic: isUrlAccessAllowed kennt nur /tabs/attendance mit Unterpfad, Reload der nackten URL schickt Helfer auf /tabs/signout / Flutter: Helfer dürfen /attendance öffnen (gleiche Rollen wie Tab).
  Flutter: lib/core/router/app_router.dart:194, lib/core/router/app_router.dart:820-847
- [ ] **niedrig** `app-routing.module` `route-902a5855` [protocols/protocol/protocol-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/protocols/protocol/protocol-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Flutter besser: nur für PLAYER/VL/NONE: Sie bekommen Team-Benachrichtigungs-Links /tabs/attendance/:id/protocol, Ionic leitet sie beim Kaltstart auf /tabs/signout um. Flutter mappt auf /settings/protocol/:id ohne Rollensperre. Notiz des Erstreviewers präzisiert: Die URL fehlt NICHT in den Guards – AuthGuard und isUrlAccessAllowed decken /tabs/attendance* für ADMIN/HELPER/VLH/VIEWER/RESPONSIBLE ab.
  Flutter: lib/core/router/legacy_routes.dart:54-56, lib/core/router/app_router.dart:1045-1055
- [ ] **niedrig** `app-routing.module` `route-05ed08a7` [songs/songs-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/songs/songs-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: Rollenprüfung nur beim Kaltstart/Betreten von /tabs (AuthGuard, Standardzweig nur ADMIN/RESPONSIBLE/VIEWER) bzw. TabsPage-effect mit isUrlAccessAllowed → Reload/Deep-Link landet für andere Rollen auf Utils.getUrl(role). Flutter: Rollenprüfung bei jeder Navigation, abgelehnte Rollen → role.defaultRoute. /tabs/songs-tab fällt im AuthGuard in den Standardzweig.
  Flutter: lib/core/router/route_access.dart:89-93, lib/core/router/app_router.dart:1283-1300
- [ ] **niedrig** `app-routing.module` `route-82191e46` [songs/song/song-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/songs/song/song-routing.module.ts#L7)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:1293-1300
- [ ] **niedrig** `app-routing.module` `route-e032468e` [songs/songs-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/songs/songs-routing.module.ts#L7)
  Flutter besser: Ionic: Reload von /tabs/settings/songs bricht für Nicht-Dirigenten ab (AuthGuard) / Flutter: alle Rollen inkl. Bewerber können /settings/songs öffnen; Anlegen/Bearbeiten nur Admin/Verantwortl. (route_access).
  Flutter: lib/core/router/app_router.dart:950-981, lib/core/router/route_access.dart:117-122
- [ ] **niedrig** `app-routing.module` `route-692f435d` [songs/song/song-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/songs/song/song-routing.module.ts#L7)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:960-967
- [ ] **niedrig** `app-routing.module` `route-f024e0aa` [agenda-items/agenda-item-detail/agenda-item-detail-routing.module.ts:6](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/agenda-items/agenda-item-detail/agenda-item-detail-routing.module.ts#L6) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: Rollenprüfung nur beim Kaltstart/Betreten von /tabs (AuthGuard, Standardzweig nur ADMIN/RESPONSIBLE/VIEWER) bzw. TabsPage-effect mit isUrlAccessAllowed → Reload/Deep-Link landet für andere Rollen auf Utils.getUrl(role). Flutter: Rollenprüfung bei jeder Navigation, abgelehnte Rollen → role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:1040-1044
- [ ] **niedrig** `app-routing.module` `route-903b9699` [tasks/task-detail/task-detail-routing.module.ts:6](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/tasks/task-detail/task-detail-routing.module.ts#L6)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute. (team-notify-Links /tabs/settings/tasks/:id)
  Flutter: lib/core/router/app_router.dart:1035-1039
- [ ] **niedrig** `app-routing.module` `route-3e6c6d33` [team-organization/team-organization-routing.module.ts:6](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/team-organization/team-organization-routing.module.ts#L6)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:1028-1034
- [ ] **niedrig** `app-routing.module` `route-a1ee1df3` [messages/message-list/message-list-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/messages/message-list/message-list-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: /tabs/settings/messages steht nicht in isUrlAccessAllowed → Reload wirft sogar ADMIN auf die Startseite / Flutter: Route für admin/responsible erreichbar, andere → defaultRoute.
  Flutter: lib/core/router/app_router.dart:176, lib/core/router/app_router.dart:1006-1010
- [ ] **niedrig** `app-routing.module` `route-0a62fac7` [settings/auto-messages/list/auto-message-list.module.ts:9](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/auto-messages/list/auto-message-list.module.ts#L9)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:178, lib/core/router/app_router.dart:1012-1016
- [ ] **niedrig** `app-routing.module` `route-e4f28d41` [settings/auto-messages/rule/auto-message-rule.module.ts:10](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/auto-messages/rule/auto-message-rule.module.ts#L10)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:1017-1025
- [ ] **niedrig** `app-routing.module` `route-b987dd8e` [messages/message-detail/message-detail-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/messages/message-detail/message-detail-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Flutter besser: Nachrichten-Mail-Links /tabs/messages/:id landen in Ionic für Spieler beim Kaltstart auf getUrl(role) / Flutter: Legacy-URL → /messages/:id, Seite öffnet.
  Flutter: lib/core/router/app_router.dart:930-935, lib/core/router/legacy_routes.dart:61-62
- [ ] **niedrig** `app-routing.module` `route-0351b31a` [notifications/notifications-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/notifications/notifications-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: Rollenprüfung nur beim Kaltstart/Betreten von /tabs (AuthGuard, Standardzweig nur ADMIN/RESPONSIBLE/VIEWER) bzw. TabsPage-effect mit isUrlAccessAllowed → Reload/Deep-Link landet für andere Rollen auf Utils.getUrl(role). Flutter: Rollenprüfung bei jeder Navigation, abgelehnte Rollen → role.defaultRoute. (VIEWER fehlt in isUrlAccessAllowed, Spieler-Rollen blockiert der AuthGuard).
  Flutter: lib/core/router/app_router.dart:1056-1060
- [ ] **niedrig** `app-routing.module` `route-6b4589f8` [register/register-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/register-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Flutter besser: Ionic: /tabs/settings/register (RegisterPage) – Reload bricht für Nicht-Dirigenten ab / Flutter: Legacy-URL → /tenants/new für alle angemeldeten Rollen.
  Flutter: lib/core/router/legacy_routes.dart:91-92, lib/core/router/app_router.dart:547-551
- [ ] **niedrig** `app-routing.module` `route-58f7f3b8` [settings/general/extra-fields/extra-fields-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/general/extra-fields/extra-fields-routing.module.ts#L7)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:1217-1221
- [ ] **niedrig** `app-routing.module` `route-4f889ee3` [settings/voice-leader/voice-leader-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/voice-leader/voice-leader-routing.module.ts#L7)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute. (Stimmführer: nur VL/VLH)
  Flutter: lib/core/router/route_access.dart:95-98
- [ ] **niedrig** `app-routing.module` `route-81a96071` [settings/delete-account/delete-account-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/delete-account/delete-account-routing.module.ts#L7)
  Flutter besser: Ionic: delete-account fehlt in isUrlAccessAllowed, Reload leitet Nicht-Dirigenten auf getUrl um / Flutter: /settings/delete-account für alle angemeldeten Rollen.
  Flutter: lib/core/router/app_router.dart:1199-1203
- [ ] **niedrig** `app-routing.module` `route-bac0fe82` [settings/help/help-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/help/help-routing.module.ts#L7)
  Flutter besser: Ionic: Reload von /tabs/settings/help bricht für Nicht-Dirigenten ab (AuthGuard) / Flutter: Hilfe für alle Rollen erreichbar.
  Flutter: lib/core/router/app_router.dart:1180-1198
- [ ] **niedrig** `app-routing.module` `route-1a651acd` [settings/help/article/help-article-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/help/article/help-article-routing.module.ts#L7)
  Flutter besser: wie /tabs/settings/help – Ionic Reload für Nicht-Dirigenten abgebrochen / Flutter: Artikel für alle Rollen.
  Flutter: lib/core/router/app_router.dart:1180-1198
- [ ] **niedrig** `app-routing.module` `route-d6960ea2` [settings/help/glossary/help-glossary-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/help/glossary/help-glossary-routing.module.ts#L7)
  Flutter besser: wie /tabs/settings/help – Ionic Reload für Nicht-Dirigenten abgebrochen / Flutter: Glossar für alle Rollen.
  Flutter: lib/core/router/app_router.dart:1180-1198
- [ ] **niedrig** `app-routing.module` `route-f4856f09` [org-settings/org-person-fields/org-person-fields-routing.module.ts:5](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/org-settings/org-person-fields/org-person-fields-routing.module.ts#L5)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:1153-1177
- [ ] **niedrig** `app-routing.module` `route-f65b270a` [org-settings/org-songs/org-songs-routing.module.ts:5](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/org-settings/org-songs/org-songs-routing.module.ts#L5)
  Flutter besser: Ionic prüft die Rolle nur beim Betreten von /tabs (AuthGuard) bzw. per TabsPage-effect/isUrlAccessAllowed; diese URL fehlt dort, daher bricht ein Reload/Deep-Link für Nicht-Dirigenten ab (leere Seite) bzw. leitet auf getUrl(role) um. Flutter: Route existiert, Rollenprüfung bei jeder Navigation, abgelehnte Rollen landen auf role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:1153-1177
- [ ] **niedrig** `app.component` `toast-499d9f2d` [app.component.ts:312](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L312)
  Flutter besser: Ionic zeigt error_description der Supabase-URL roh (englisch) / Flutter übersetzt bekannte Fehler in deutschen Text.
  Flutter: lib/features/auth/data/auth_link_listener.dart:124-165
- [ ] **niedrig** `app.component` `db-bd67c5c9` [app.component.ts:321](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L321)
  Flutter besser: Ionic verifyOtp nur mit type recovery|signup / Flutter mappt alle Link-Typen (u.a. invite, magiclink, email_change) auf den passenden OtpType.
  Flutter: lib/features/auth/data/auth_flow_service.dart:296-310, lib/features/auth/data/auth_flow_service.dart:470-530
- [ ] **niedrig** `register/register.page` `toast-535997f4` [register/register.page.ts:57](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/register.page.ts#L57)
  Flutter besser: Ionic: Toast mit roher Fehlermeldung (register.createFailed + error.message), teils doppelt / Flutter: verständlicher deutscher Fehlertext.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_create_page.dart:596-599
- [ ] **niedrig** `app-routing.module` [src/app/services/auth.guard.ts:16-45](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/auth.guard.ts#L16-45)
  Flutter besser: Ionic: AuthGuard läuft nur beim Betreten von /tabs; für viele Unterseiten (messages, team-organization, tasks/:id, agenda-items/:id, messages/:id, auto-messages, overview, delete-account, general/extra-fields, general/shifts, org-settings/person-fields, org-settings/songs) bricht ein Reload die Navigation ab (leere Seite) oder TabsPage-effect leitet auf getUrl(role) um, obwohl die UI der Rolle den Zugang erlaubt / Flutter: Redirect prüft die Rolle bei jeder Navigation und schickt abgelehnte Rollen auf role.defaultRoute.
  Flutter: lib/core/router/app_router.dart:214-246, lib/core/router/route_access.dart:127-139
- [ ] **niedrig** `app.component` [src/app/app.component.ts:297](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L297)
  Flutter besser: Ionic zeigt error_description (englisch) direkt / Flutter übersetzt bekannte Fehler ins Deutsche.
  Flutter: lib/features/auth/data/auth_link_listener.dart:152-165
- [ ] **niedrig** `app.component` [src/app/app.component.ts:303-323](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L303-323)
  Flutter besser: Ionic verifyOtp nur recovery|signup / Flutter unterstützt weitere Link-Typen (invite, magiclink, email_change).
  Flutter: lib/features/auth/data/auth_flow_service.dart:296-310
- [ ] **niedrig** `login/legal-modal/legal-content.component` [src/app/login/legal-modal/legal-content.component.ts:18-24](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/legal-modal/legal-content.component.ts#L18-24)
  Flutter besser: Ionic setzt nur error=true (Fehlertext) / Flutter: Fehleransicht mit "Erneut versuchen".
  Flutter: lib/features/legal/presentation/widgets/legal_content_view.dart:61-83
- [ ] **niedrig** `login/register-modal/register-modal.component` [src/app/login/register-modal/register-modal.component.ts:196-205](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/register-modal/register-modal.component.ts#L196-205)
  Flutter besser: Ionic: allgemeine Fehlertoasts aus db.register / Flutter: spezifischere Meldungen je Supabase-Fehler.
  Flutter: lib/features/auth/presentation/pages/register_page.dart:212-242
- [ ] **niedrig** `login/register-modal/register-modal.component` [src/app/login/register-modal/register-modal.component.ts:196-205](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/register-modal/register-modal.component.ts#L196-205)
  Flutter besser: Ionic zeigt "Registrierung erfolgreich…"-Toast, obwohl der Nutzer direkt angemeldet ist / Flutter leitet den angemeldeten Nutzer weiter.
  Flutter: lib/features/auth/presentation/pages/register_page.dart:212-242
- [ ] **niedrig** `open-attendance/open-attendance.page` [src/app/open-attendance/open-attendance.page.ts:62-67](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/open-attendance/open-attendance.page.ts#L62-67)
  Flutter besser: Ionic merkt sich die ID nur in pendingAttendanceId (geht bei Reload verloren) / Flutter setzt den Link nach dem Login fort.
  Flutter: lib/core/router/app_router.dart:311-316, lib/features/planning/presentation/pages/open_attendance_page.dart:40-43
- [ ] **niedrig** `open-attendance/open-attendance.page` [src/app/open-attendance/open-attendance.page.ts:70-85](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/open-attendance/open-attendance.page.ts#L70-85)
  Flutter besser: Ionic bleibt für Beobachter ohne Termin-Zugriff auf dem Spinner hängen / Flutter leitet auf /people um.
  Flutter: lib/features/planning/presentation/pages/open_attendance_page.dart:60-94
- [ ] **niedrig** `register/register.page` [src/app/register/register.page.ts:53](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/register.page.ts#L53)
  Flutter besser: Ionic ruft modalController.dismiss() auch in der Route-Variante (/tabs/settings/register) auf, wo kein Modal existiert (Fehler/kein Schließen) / Flutter navigiert korrekt zurück.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_create_page.dart:561-564
- [ ] **niedrig** `register/tenant-register/tenant-register.page` [src/app/register/tenant-register/tenant-register.page.ts:411](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L411)
  Flutter besser: Ionic speichert firstName/lastName ungetrimmt und akzeptiert reine Leerzeichen / Flutter: onSaved trimmt, reine Leerzeichen scheitern an „Name erforderlich“.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:307, lib/features/registration/presentation/pages/tenant_registration_page.dart:318, lib/features/registration/presentation/pages/tenant_registration_page.dart:1060-1062

## Kleinigkeiten (niedrig): 68

- [ ] **niedrig** `app-redirect/app-redirect.page` `action-f6aa44fd` [app-redirect/app-redirect.page.html:13](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app-redirect/app-redirect.page.html#L13) (2. Prüfung: bestätigt)
  Ionic: Icon logo-google-playstore / Flutter: Icons.shop. Text und Ziel (Play-Store-Link im selben Tab) gleich.
  Flutter: lib/features/public_links/presentation/pages/app_redirect_page.dart:115-120
- [ ] **niedrig** `app-routing.module` `route-70e49d30` [attendance/attendance/attendance-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/attendance/attendance/attendance-routing.module.ts#L7) (2. Prüfung: korrigiert)
  Korrektur hoch→niedrig: In Ionic kommt VIEWER nur per getippter URL auf /tabs/attendance/:id; es gibt keinen UI-Weg. att-list openAttendance verlangt isConductor (ADMIN/RESPONSIBLE) oder isHelper, nextAttendance im Topics-Tab nur für Teamleiter (ADMIN/RESPONSIBLE), „Termin öffnen“ in der Nachricht nur isManager, Push navigateToAttendance schickt VIEWER auf /tabs/signout, Dienst-Mails nur an Rollen 1/5. Die Behauptung „Beobachter öffnen den Termin aus Liste, Topics und Nachrichten“ stimmt nicht. Ionic: URL öffnet für VIEWER die Terminseite / Flutter: attendanceDetailRedirect (canAddAttendance) leitet VIEWER auf /people um.
  Flutter: lib/core/router/attendance_detail_guard.dart:22-27, lib/core/router/app_router.dart:222-230
- [ ] **niedrig** `app-routing.module` `route-4cddadf6` [songs/import/import-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/songs/import/import-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Ionic-Route /tabs/songs-tab/import (SongImportPage) nur per URL erreichbar, in der App öffnet der Import als Modal / Flutter: keine Route, /songs-tab/import wird als Werk-ID „import“ gelesen.
- [ ] **niedrig** `app-routing.module` `route-22a72ccb` [songs/import/import-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/songs/import/import-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Ionic-Route /tabs/settings/songs/import nur per URL erreichbar (App nutzt Modal) / Flutter: keine Import-Route, „import“ wird als Werk-ID interpretiert.
- [ ] **niedrig** `app-routing.module` `route-409dca75` [settings/general/shifts/shifts-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/general/shifts/shifts-routing.module.ts#L7) (2. Prüfung: korrigiert)
  Korrektur mittel→niedrig: Auch in Ionic öffnet ein Reload/Lesezeichen von /tabs/settings/general/shifts die Seite nie – AuthGuard (Standardzweig) bzw. TabsPage-effect (URL fehlt in isUrlAccessAllowed) leiten auf getUrl(role) um. In der App navigiert Flutter korrekt nach /settings/shifts. Unterschied nur bei Legacy-URL: Ionic landet auf der Startseite / Flutter zeigt Fehlerseite „Seite nicht gefunden: …“ mit Button „Zur Startseite“.
  Flutter: lib/core/router/legacy_routes.dart:93-98, lib/core/router/app_router.dart:1110-1124
- [ ] **niedrig** `app-routing.module` `route-174d1db9` [settings/general/shifts/shift/shift-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/general/shifts/shift/shift-routing.module.ts#L7) (2. Prüfung: korrigiert)
  Korrektur mittel→niedrig: Auch in Ionic öffnet ein Reload von /tabs/settings/general/shifts/:id die Schicht nicht (AuthGuard/TabsPage-effect → getUrl(role)). In-App-Navigation existiert in Flutter unter /settings/shifts/:id. Nur Legacy-URL: Ionic → Startseite / Flutter → Fehlerseite „Seite nicht gefunden“ mit „Zur Startseite“.
  Flutter: lib/core/router/legacy_routes.dart:93-98, lib/core/router/app_router.dart:1110-1124
- [ ] **niedrig** `app-routing.module` `route-b9a9398e` [public-planning/public-planning-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/public-planning/public-planning-routing.module.ts#L7)
  Ionic: /tabs/org-plans/planung bleibt im Tab Org-Pläne / Flutter: Legacy-URL → /settings/org-plans/planung (Einstellungen statt Tab /org-plans-tab/planung).
  Flutter: lib/core/router/legacy_routes.dart:63-64
- [ ] **niedrig** `app-routing.module` `route-dd04c3d0` [settings/general/branding/branding-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/general/branding/branding-routing.module.ts#L7)
  Ionic: /tabs/settings/org-settings/branding öffnet die Org-Branding-Seite / Flutter: Legacy-URL → /settings/org-settings (Branding ist dort enthalten, keine eigene Seite).
  Flutter: lib/core/router/legacy_routes.dart:99-102
- [ ] **niedrig** `app-routing.module` `route-ddf8f625` [settings/administration/administration-routing.module.ts:6](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/settings/administration/administration-routing.module.ts#L6)
  Ionic: SuperDeveloperGuard leitet Nicht-Superdevs auf /tabs/player um / Flutter: Umleitung auf /settings.
  Flutter: lib/core/router/app_router.dart:1238-1245
- [ ] **niedrig** `app-routing.module` `route-1f551f78` [dashboard/dashboard-routing.module.ts:6](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/dashboard/dashboard-routing.module.ts#L6) (2. Prüfung: bestätigt)
  Ionic: SuperDeveloperGuard leitet Nicht-Superdevs auf /tabs/player um / Flutter: Umleitung auf /settings.
  Flutter: lib/core/router/app_router.dart:1276-1281
- [ ] **niedrig** `app-routing.module` `route-b64546c1-2` [tabs/tabs-routing.module.ts:228](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/tabs/tabs-routing.module.ts#L228)
  Ionic: Tabs-Kindroute '' → redirect /tabs/player (danach effect → getUrl(role)) / Flutter: /tabs → /open-link → Rollen-Startseite (homeRouteFor/defaultRoute) direkt, ohne Zwischenstopp auf /people.
  Flutter: lib/core/router/legacy_routes.dart:45, lib/features/deep_links/presentation/pages/open_link_page.dart:81-89
- [ ] **niedrig** `app-routing.module` `route-b64546c1-3` [tabs/tabs-routing.module.ts:235](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/tabs/tabs-routing.module.ts#L235)
  Ionic: Wildcard/Leer-Route unter /tabs → /tabs/player / Flutter: unbekannte /tabs/...-Pfade → /open-link → Rollen-Startseite.
  Flutter: lib/core/router/legacy_routes.dart:74-75, lib/features/deep_links/presentation/pages/open_link_page.dart:81-89
- [ ] **niedrig** `app-routing.module` `route-4f64d874` [terms/terms-routing.module.ts:6](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/terms/terms-routing.module.ts#L6)
  Ionic: nach Akzeptieren der AGB → getUrl(role) / Flutter: → /tenants → homeRouteFor (Dashboard-Logik); TermsGuard-Äquivalent im Redirect.
  Flutter: lib/core/router/app_router.dart:365-376, lib/core/router/app_router.dart:492-496
- [ ] **niedrig** `app-routing.module` `route-f224eba3` [songs/import/import-routing.module.ts:7](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/songs/import/import-routing.module.ts#L7) (2. Prüfung: bestätigt)
  Ionic: /:songSharingId/import (Werk-Import aus geteilter Liste, nur per URL, ohne Tenant praktisch nicht nutzbar) / Flutter: keine Route; /x/import wird als /:songSharingId/:songId mit songId „import“ gelesen.
- [ ] **niedrig** `app.component` `alert-b82c0ed9` [app.component.ts:219](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L219)
  Ionic: Hinweis wird in Teams nicht gezeigt (isInTeams) / Flutter: Native-App-Hinweis ohne Teams-Prüfung, erscheint auch im Teams-Tab. Texte/Buttons gleich.
  Flutter: lib/shared/widgets/dialogs/native_app_ad.dart:30-97
- [ ] **niedrig** `app.module` `logic-0c401cb7` [app.module.ts:1](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.module.ts#L1)
  Ionic: TeamsService.init als APP_INITIALIZER (App startet erst nach Teams-Erkennung); SW im iframe deaktiviert / Flutter: TeamsService.init() wird nicht abgewartet (unawaited), SSO startet nach Erkennung. Sichtbar höchstens als kurzer Zwischenstand im Teams-Tab.
  Flutter: lib/main.dart:102-105, lib/main.dart:155
- [ ] **niedrig** `login/login.page` `loading-256b5e4d` [login/login.page.ts:87](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.ts#L87) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading-Overlay ohne Text (max. 3 s) / Flutter: Spinner im Button, Felder und Links bleiben bedienbar. (Erstnotiz „mit Text“ unzutreffend.)
  Flutter: lib/features/auth/presentation/pages/login_page.dart:192-228, lib/features/auth/presentation/pages/login_page.dart:490-495
- [ ] **niedrig** `login/login.page` `loading-850f8e3f` [login/login.page.ts:169](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.ts#L169)
  Ionic: blockierendes Loading-Overlay mit Text / Flutter: Spinner im Button, Felder und Links bleiben bedienbar.
  Flutter: lib/features/auth/presentation/pages/login_page.dart:262-282
- [ ] **niedrig** `login/login.page` `loading-65905d50` [login/login.page.ts:194](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.ts#L194)
  Ionic: blockierendes Loading-Overlay mit Text / Flutter: Spinner im Button, Felder und Links bleiben bedienbar.
  Flutter: lib/features/auth/presentation/pages/login_page.dart:284-298
- [ ] **niedrig** `login/login.page` `loading-5b2e7ab2` [login/login.page.ts:300](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.ts#L300)
  Ionic: blockierendes Loading-Overlay mit Text / Flutter: Spinner im Button, Felder und Links bleiben bedienbar.
  Flutter: lib/features/auth/presentation/pages/login_page.dart:151-168
- [ ] **niedrig** `login/login.page` `alert-6a20446e` [login/login.page.ts:317](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.ts#L317)
  Ionic: Alert "Passwort zurücksetzen" mit E-Mail-Feld, danach Toast / Flutter: eigener Dialog (reset_password_dialog) mit gleichem Feld; Toast-Texte leicht anders formuliert, kein Loading-Overlay.
  Flutter: lib/features/auth/presentation/pages/login_page.dart:113-126, lib/features/auth/presentation/widgets/reset_password_dialog.dart
- [ ] **niedrig** `login/login.page` `modal-54e99890` [login/login.page.ts:344](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.ts#L344)
  Ionic: Registrieren-Modal leer / Flutter: Registrieren-Seite mit der im Login eingegebenen E-Mail vorbefüllt.
  Flutter: lib/features/auth/presentation/pages/login_page.dart:333-347
- [ ] **niedrig** `login/login.page` `action-4356dbd3` [login/login.page.html:9](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.html#L9) (2. Prüfung: bestätigt)
  Ionic: (keyup.enter) am Formular ruft onEnter() → login() sofort, auch aus dem E-Mail-Feld (kein Fokuswechsel) / Flutter: E-Mail-Feld TextInputAction.next springt ins Passwortfeld, erst Enter im Passwortfeld sendet (mit Validierung). OTP-Enter gleich.
  Flutter: lib/features/auth/presentation/pages/login_page.dart:182-189, lib/features/auth/presentation/pages/login_page.dart:747-756, lib/features/auth/presentation/pages/login_page.dart:797-799
- [ ] **niedrig** `login/login.page` `action-02346026` [login/login.page.html:94](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.html#L94)
  Ionic: "Nach Updates suchen" prüft/installiert ein OTA-Live-Update (Capgo) / Flutter: prüft die Store-Version und öffnet den Store.
  Flutter: lib/features/auth/presentation/pages/login_page.dart:657-672
- [ ] **niedrig** `login/register-modal/register-modal.component` `loading-3c8fec58` [login/register-modal/register-modal.component.ts:102](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/register-modal/register-modal.component.ts#L102)
  Ionic: blockierendes Loading-Overlay mit Text / Flutter: Spinner im Button, Felder und Links bleiben bedienbar.
  Flutter: lib/features/auth/presentation/pages/register_page.dart:263-268
- [ ] **niedrig** `login/register-modal/register-modal.component` `loading-246d5798` [login/register-modal/register-modal.component.ts:129](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/register-modal/register-modal.component.ts#L129)
  Ionic: blockierendes Loading-Overlay mit Text / Flutter: Spinner im Button, Felder und Links bleiben bedienbar.
  Flutter: lib/features/auth/presentation/pages/register_page.dart:281-297
- [ ] **niedrig** `login/register-modal/register-modal.component` `loading-2d3baa1a` [login/register-modal/register-modal.component.ts:198](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/register-modal/register-modal.component.ts#L198)
  Ionic: Overlay "Registrierung läuft..." / Flutter: Spinner im Button, kein blockierendes Overlay.
  Flutter: lib/features/auth/presentation/pages/register_page.dart:528-539
- [ ] **niedrig** `login/register-modal/register-modal.component` `action-f32f9068` [login/register-modal/register-modal.component.html:23](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/register-modal/register-modal.component.html#L23)
  Ionic: Enter in jedem Feld sendet das Formular ab / Flutter: Enter sendet nur aus dem Feld "Passwort bestätigen" ab.
  Flutter: lib/features/auth/presentation/pages/register_page.dart:360-557
- [ ] **niedrig** `open-file/open-file.page` `nav-034261c8` [open-file/open-file.page.ts:83](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/open-file/open-file.page.ts#L83)
  Ionic: navigateByUrl(..., replaceUrl) – Zurück führt nicht auf /open-file / Flutter: context.go ohne Ersetzen des Browser-History-Eintrags, Zurück im Browser öffnet /open-file erneut.
  Flutter: lib/features/public_links/presentation/pages/open_file_page.dart:115-124
- [ ] **niedrig** `register/register.page` `loading-f7a14784` [register/register.page.ts:47](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/register.page.ts#L47)
  Ionic: blockierendes Overlay beim Anlegen / Flutter: Spinner im Button.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_create_page.dart:446-460
- [ ] **niedrig** `register/register.page` `loading-14fb6abb` [register/register.page.ts:111](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/register.page.ts#L111)
  Ionic: blockierendes Loading-Overlay beim Löschen / Flutter: nur Info-Toast, nicht blockierend.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_create_page.dart:524
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `toast-3163772f` [register/tenant-register/tenant-register.page.ts:65](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L65)
  Ionic: Toast 'Ungültiger Freigabe-Link.' auf leerer Seite (nur 'Registrierung abschließen' sichtbar) / Flutter: Fehleransicht 'Ungültiger Registrierungslink.' mit Button 'Zur Anmeldung', kein Toast.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:146, lib/features/registration/presentation/pages/tenant_registration_page.dart:171
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `loading-c4081e17` [register/tenant-register/tenant-register.page.ts:103](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L103)
  Ionic: blockierendes Loading-Overlay während Bereits-registriert-Prüfung / Flutter: Prüfung im Hintergrund ohne Overlay.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:688
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `loading-ba12bb0b` [register/tenant-register/tenant-register.page.ts:175](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L175) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading-Overlay beim Code-Anfordern / Flutter: nur Buttons deaktiviert, Spinner unter dem Formular.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:968
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `loading-54fa6693` [register/tenant-register/tenant-register.page.ts:198](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L198) (2. Prüfung: bestätigt)
  Ionic: blockierendes Loading-Overlay beim Code-Bestätigen / Flutter: Buttons/Codefeld deaktiviert, kein Overlay.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:988, lib/features/registration/presentation/pages/tenant_registration_page.dart:434-438
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `nav-daa5b1d7` [register/tenant-register/tenant-register.page.ts:248](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L248) (2. Prüfung: bestätigt)
  Ionic goHome: Utils.getUrl(role) / Flutter: homeRouteFor (bei aktivem Dashboard-Tab Dashboard-Startseite; Rolle none → /login statt Signout-Seite).
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:158-166
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `effect-6294e86d` [register/tenant-register/tenant-register.page.ts:248](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L248)
  Ziel-Berechnung wie nav-daa5b1d7: Flutter homeRouteFor berücksichtigt zusätzlich die Dashboard-Startseite (Ionic Utils.getUrl nicht).
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:163, lib/core/utils/dashboard_logic.dart:56
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `alert-d3091b10` [register/tenant-register/tenant-register.page.ts:255](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L255)
  Gleicher Titel 'Anmelden', Buttons 'Abbrechen'/'Anmelden', danach Check+Prefill. Unterschiede: Flutter zusätzlicher Text 'Melde dich mit deinem bestehenden Account an.', Feld-Label 'E-Mail' statt Platzhalter 'E-Mail Adresse', Fehler als roter Text im Dialog statt Toast (bei unbestätigter E-Mail zeigt Flutter 'Bitte bestätige zuerst deine E-Mail-Adresse.', Ionic nichts).
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:715
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `loading-0e5874c4` [register/tenant-register/tenant-register.page.ts:301](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L301)
  Ionic: blockierendes Overlay 'Registrierung läuft...' (bis 45 s) / Flutter: Button deaktiviert + Spinner unter dem Button, ohne Text und ohne Overlay.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:1121, lib/features/registration/presentation/pages/tenant_registration_page.dart:436
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `toast-e04d5d24` [register/tenant-register/tenant-register.page.ts:363](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L363) (2. Prüfung: bestätigt)
  Ionic: „Fehler bei der Registrierung: <technische Meldung>“ (6 s) / Flutter: bei unbekannten Fehlern generischer Text „…Fehler beim Registrieren. Bitte versuche es erneut.“, Standarddauer.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:1153-1160, lib/features/registration/data/providers/registration_providers.dart:279
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `toast-b918f4e0` [register/tenant-register/tenant-register.page.ts:446](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L446)
  Ionic: isNaN(Number(value)) – leerer Wert ('' oder null) gilt als gültig / Flutter: leeres Zahlenfeld -> Toast 'Bitte geben Sie eine gültige Zahl für das Feld ... ein.' (Pflichtfeld).
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:1085
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `toast-02f7573a` [register/tenant-register/tenant-register.page.ts:451](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L451)
  Ionic: Datumsfelder haben kein Eingabeelement, geprüft wird nur der defaultValue / Flutter: Datumsauswahl; ohne Auswahl Toast (defaultValue wird ignoriert).
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:1089, lib/features/registration/presentation/pages/tenant_registration_page.dart:552
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `loading-19c310bc` [register/tenant-register/tenant-register.page.ts:498](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L498)
  Ionic: Loading-Overlay während Bild eingelesen wird / Flutter: kein Ladeindikator.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:590
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `toast-2a68da3c` [register/tenant-register/tenant-register.page.ts:505](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L505)
  Gleicher Text. Ionic prüft die Originaldatei (>15 MB) / Flutter prüft erst nach Verkleinerung auf 800 px, Qualität 80 – greift praktisch nie, große Bilder werden angenommen.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:604
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `action-56c2bb62` [register/tenant-register/tenant-register.page.html:102](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.html#L102)
  Ionic: Label bleibt 'Wähle ein Passbild aus (max. 15 MB)' / Flutter: nach Auswahl Label 'Passbild ersetzen'.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:282
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `action-86975787` [register/tenant-register/tenant-register.page.html:104](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.html#L104)
  Ionic: Avatar-Grafik (DEFAULT_IMAGE, Fallback avatar-placeholder.svg) / Flutter: graues Kreis-Avatar mit Personen-Icon.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:284
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `modal-6f647b7b` [register/tenant-register/tenant-register.page.html:178](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.html#L178)
  Ionic: Vollbild-ion-modal / Flutter: Bottom-Sheet mit 95 % Höhe (Inhalt gleich).
  Flutter: lib/features/profile/presentation/widgets/church_picker.dart:25
- [ ] **niedrig** `register/tenant-register/tenant-register.page` `action-5bd78b6a` [register/tenant-register/tenant-register.page.html:233](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.html#L233) (2. Prüfung: bestätigt)
  Ionic: nur bei fehlenden Gruppen deaktiviert, auch bei ungültigem Link sichtbar / Flutter: zusätzlich im OTP-Modus vor Anmeldung und während des Ladens deaktiviert, bei ungültigem Link nicht vorhanden.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:422-433
- [ ] **niedrig** `tabs/side-nav/side-nav.component` `loading-e9133cc5` [tabs/side-nav/side-nav.component.ts:124](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/tabs/side-nav/side-nav.component.ts#L124) (2. Prüfung: bestätigt)
  Ionic: Loading-Overlay während Instanzwechsel / Flutter: switchTenant ohne Ladeanzeige.
  Flutter: lib/shared/widgets/layout/side_nav/side_nav.dart:128, lib/shared/widgets/tenant/tenant_switcher_title.dart:389-405
- [ ] **niedrig** `tabs/tabs.page` `action-8d0f89f7` [tabs/tabs.page.html:66](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/tabs/tabs.page.html#L66)
  Ionic Tabbar: 'Werke' bei aktivierter Option für alle außer Bewerber (auch Eltern) / Flutter: zusätzlich für Eltern ausgeblendet (canOpenSongsTab). Ionic-Route/Sidepanel sperren Eltern ebenfalls.
  Flutter: lib/shared/widgets/layout/main_shell.dart:145, lib/core/providers/optional_tabs_providers.dart:87
- [ ] **niedrig** `terms/terms.page` `nav-4d7988a7` [terms/terms.page.ts:28](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/terms/terms.page.ts#L28)
  Ionic: bereits akzeptiert -> Utils.getUrl(role) / Flutter: Router leitet auf gemerkten Link oder /tenants; ist schon eine Instanz aktiv, erscheint dort die Instanzauswahl statt der Startseite.
  Flutter: lib/core/router/app_router.dart:370
- [ ] **niedrig** `terms/terms.page` `effect-1f50895e` [terms/terms.page.ts:28](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/terms/terms.page.ts#L28)
  Wie nav-4d7988a7: Flutter berechnet kein Rollenziel, sondern geht über /tenants (Auto-Weiterleitung mit homeRouteFor nur ohne aktive Instanz).
  Flutter: lib/core/router/app_router.dart:371, lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart:80
- [ ] **niedrig** `terms/terms.page` `effect-9680384f` [terms/terms.page.ts:61](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/terms/terms.page.ts#L61)
  Wie nav-4df0f2ac: Ziel wird nicht aus der Rolle berechnet, sondern über /tenants bzw. homeRouteFor (inkl. Dashboard-Startseite).
  Flutter: lib/features/legal/presentation/pages/terms_page.dart:58
- [ ] **niedrig** `app-routing.module` [src/app/utilities/Utils.ts:1312-1317](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/utilities/Utils.ts#L1312-1317)
  Ionic: VIEWER darf attendance/:id öffnen (AuthGuard, isUrlAccessAllowed), Einstieg aus Anwesenheitsliste, Themen-Tab und Nachrichten / Flutter: attendanceDetailRedirect verlangt canAddAttendance, Beobachter wird auf /people umgeleitet. [2. Prüfung: Beobachter erreichen /tabs/attendance/:id in Ionic nur per eingetippter URL (Liste, Themen-Tab und Nachrichten zeigen den Einstieg nur anderen Rollen); siehe zz-verify-app]
  Flutter: lib/core/router/attendance_detail_guard.dart:22-27
- [ ] **niedrig** `app-redirect/app-redirect.page` [src/app/app-redirect/app-redirect.page.ts:38-42](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app-redirect/app-redirect.page.ts#L38-42)
  Ionic: window.location.replace(storeUrl) – Zurück führt nicht wieder auf /app / Flutter: launchUrl(webOnlyWindowName: "_self") legt einen Eintrag an, Zurück öffnet /app und leitet erneut weiter.
  Flutter: lib/features/public_links/presentation/pages/app_redirect_page.dart:31-54
- [ ] **niedrig** `app.component` [src/app/app.component.ts:178-199](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L178-199)
  Ionic: SwUpdate prüft regelmäßig/bei Sichtbarkeitswechsel, aktiviert eine neue Version und lädt die Seite sofort neu / Flutter: neue Version wird erst beim nächsten Start geladen.
  Flutter: lib/core/services/app_update_service_web.dart
- [ ] **niedrig** `app.component` [src/app/app.component.ts:203-207](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L203-207)
  Ionic: showNativeAppAd kehrt in Teams zurück (isInTeams) / Flutter: keine Teams-Prüfung, Hinweis erscheint auch im Teams-Tab.
  Flutter: lib/shared/widgets/dialogs/native_app_ad.dart:30-97
- [ ] **niedrig** `app.component` [src/app/app.component.ts:375-385](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/app.component.ts#L375-385)
  Ionic: trackt router.url roh (/tabs/...) / Flutter: tracking_observer bereinigt IDs/Query und trackt Flutter-Pfade (andere URLs in der Auswertung).
  Flutter: lib/core/router/tracking_observer.dart:14-40
- [ ] **niedrig** `login/legal-modal/legal-content.component` [src/app/login/legal-modal/legal-content.component.ts](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/legal-modal/legal-content.component.ts)
  Ionic: innerHTML / Flutter: Umwandlung über HtmlToDelta/Quill; Darstellung komplexer HTML-Elemente (Tabellen, Listen) nicht geprüft (Paketquellen nicht im Container).
  Flutter: lib/features/legal/presentation/widgets/legal_content_view.dart:61-83
- [ ] **niedrig** `login/login.page` [src/app/login/login.page.ts:164-166](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.ts#L164-166)
  Ionic: ungültige E-Mail → Toast / Flutter: Fehlertext direkt am Feld.
  Flutter: lib/features/auth/presentation/pages/login_page.dart:151-168
- [ ] **niedrig** `login/login.page` [src/app/login/login.page.ts:334](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.ts#L334)
  Ionic: db.resetPassword-Toasts / Flutter: eigene, leicht anders formulierte Toasts im Reset-Dialog.
  Flutter: lib/features/auth/presentation/widgets/reset_password_dialog.dart
- [ ] **niedrig** `login/login.page` [src/app/login/login.page.ts](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/login/login.page.ts)
  Ionic: Registrieren-Modal startet leer / Flutter: übernimmt die eingegebene E-Mail.
  Flutter: lib/features/auth/presentation/pages/login_page.dart:333-347
- [ ] **niedrig** `open-attendance/open-attendance.page` [src/app/open-attendance/open-attendance.page.ts:49-55](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/open-attendance/open-attendance.page.ts#L49-55)
  Ionic: ungültige ID angemeldet → routeAfterAuth (Dashboard-Logik) / Flutter: → role.defaultRoute.
  Flutter: lib/features/planning/presentation/pages/open_attendance_page.dart:37-50
- [ ] **niedrig** `register/register.page` [src/app/register/register.page.ts:40-58](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/register.page.ts#L40-58)
  Ionic speichert Instanz-/Namensfelder ungetrimmt / Flutter trimmt Leerzeichen.
  Flutter: lib/features/tenant_selection/presentation/pages/tenant_create_page.dart:470-490
- [ ] **niedrig** `register/tenant-register/tenant-register.page` [src/app/register/tenant-register/tenant-register.page.html:157](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.html#L157)
  Ionic: Template rendert für Typ 'textarea' und 'date' kein Eingabeelement (leeres ion-item), Validierung prüft nur den Default / Flutter: mehrzeiliges Textfeld bzw. Datumsauswahl vorhanden.
  Flutter: lib/features/registration/presentation/pages/tenant_registration_page.dart:473, lib/features/registration/presentation/pages/tenant_registration_page.dart:552
- [ ] **niedrig** `register/tenant-register/tenant-register.page` [src/app/services/db.service.ts:1730](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/services/db.service.ts#L1730)
  Ionic: E-Mail existiert + Passwort stimmt -> addUserToTenant direkt (auch wenn bereits Mitglied) / Flutter: registerUser(selfRegister) -> bei bestehender Mitgliedschaft kein zweiter tenantUsers-Eintrag. Randfall, Flutter vermeidet Duplikat.
  Flutter: lib/features/registration/data/providers/registration_providers.dart:150
- [ ] **niedrig** `tabs/side-nav/side-nav.component` [src/app/tabs/side-nav/side-nav.component.html:26](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/tabs/side-nav/side-nav.component.html#L26)
  Ionic: tenants.logo_url gesetzt -> Logo-Bild statt Initialen im Instanz-Button / Flutter: Tenant-Modell kennt logo_url nicht, es werden immer die Initialen gezeigt.
  Flutter: lib/shared/widgets/layout/side_nav/side_nav.dart:614
- [ ] **niedrig** `register/tenant-register/tenant-register.page` [src/app/register/tenant-register/tenant-register.page.ts:329](https://github.com/FECGSpeyer/attendance/blob/9f9b82af/src/app/register/tenant-register/tenant-register.page.ts#L329)
  Ionic: addPlayer schreibt img = DEFAULT_IMAGE (https://ionicframework.com/docs/img/demos/avatar.svg), wenn kein Passbild gewählt wurde / Flutter: buildRegistrationPlayerData setzt kein img (DB-Default). Anzeige gleich, da Flutter .svg-Avatar als „kein Bild“ behandelt.
  Flutter: lib/features/registration/data/providers/registration_providers.dart:303-330
