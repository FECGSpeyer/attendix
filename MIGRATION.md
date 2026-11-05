# Attendix Migration Status

> **Quellprojekt:** `/Users/I576226/repositories/attendance` (Ionic/Angular)  
> **Zielprojekt:** `/Users/I576226/repositories/attendix` (Flutter)  
> **Letzte Aktualisierung:** 2026-02-17

## Übersicht

| Kategorie | Fortschritt | Status |
|-----------|-------------|--------|
| Seiten/Features | ~35% | 🟡 In Arbeit |
| Services/Repositories | ~20% | 🔴 Ausstehend |
| Datenmodelle | ~25% | 🟡 In Arbeit |
| Realtime | 0% | 🔴 Ausstehend |
| Tests | 0% | 🔴 Ausstehend |

---

## 1. Authentication & Zugang

### 1.1 Login/Register
- [x] Login Page
- [x] Register Page
- [x] Auth State Management (Riverpod)
- [ ] Passwort vergessen
- [ ] Passwort ändern
- [ ] Email verifizieren

### 1.2 Tenant Selection
- [x] Tenant-Liste anzeigen
- [x] Tenant wechseln
- [x] Current Tenant Provider
- [ ] Tenant-Favoriten
- [ ] Zuletzt verwendeter Tenant merken

---

## 2. Personen/Spieler

### 2.1 People List Page
- [x] Liste aller aktiven Personen
- [x] Suche nach Name
- [x] Filter (Aktiv, Pausiert, Kritisch, Leiter)
- [x] Sortierung (Gruppe, Vorname, Nachname)
- [x] Gruppierung nach Instrument
- [ ] Pull-to-refresh mit Realtime
- [ ] Skeleton Loading (shimmer)
- [ ] Neue Person hinzufügen
- [ ] Person archivieren
- [ ] Bulk-Aktionen

### 2.2 Person Detail Page
- [x] Basis-Ansicht
- [ ] Vollständige Felder anzeigen
- [ ] Person bearbeiten
- [ ] Profilbild ändern
- [ ] Anwesenheits-Historie
- [ ] Statistik-Kacheln
- [ ] Critical Status anzeigen
- [ ] History-Timeline
- [ ] Instrument wechseln
- [ ] Notizen bearbeiten
- [ ] Telefon/Email Aktionen

---

## 3. Anwesenheit

### 3.1 Attendance List Page
- [x] Liste aller Anwesenheiten
- [x] Gruppierung nach Datum
- [x] Datum-Labels (Heute, Gestern, etc.)
- [ ] Kalender-Ansicht
- [ ] Filter nach Anwesenheitstyp
- [ ] Realtime Updates
- [ ] Percentage anzeigen

### 3.2 Attendance Detail Page
- [x] Basis-Ansicht
- [ ] Person-Liste mit Status
- [ ] Status ändern per Tap
- [ ] Swipe-Gesten für Status
- [ ] Gruppenweise Darstellung
- [ ] Batch-Status-Änderung
- [ ] Notizen pro Person
- [ ] Spätkommer-Handling
- [ ] Entschuldigt markieren
- [ ] Prozentsatz berechnen
- [ ] Kritische Spieler markieren
- [ ] Lieder auswählen
- [ ] Checklist
- [ ] Proben-Plan (Planning)

### 3.3 Attendance Create Page
- [x] Basis-Seite
- [ ] Datum auswählen
- [ ] Anwesenheitstyp auswählen
- [ ] Start/Ende Zeit
- [ ] Von vorheriger Anwesenheit kopieren
- [ ] Alle anwesend/abwesend

---

## 4. Self-Service (KRITISCH) 🔴

### 4.1 Overview Page
- [ ] Persönliche Übersicht
- [ ] Nächste Termine
- [ ] Eigene Statistik
- [ ] Anstehende An-/Abmeldungen
- [ ] Benachrichtigungen

### 4.2 Signout Page
- [ ] Termin-Liste für An-/Abmeldung
- [ ] Selbst-Abmeldung
- [ ] Grund angeben
- [ ] Abmeldung zurücknehmen
- [ ] Deadline-Anzeige

### 4.3 Parents Page
- [ ] Kinder-Übersicht
- [ ] Kind abmelden
- [ ] Vereinfachte Ansicht

---

## 5. Statistiken

### 5.1 Stats Page
- [ ] Gesamt-Statistiken
- [ ] Anwesenheits-Diagramm (fl_chart)
- [ ] Prozent-Anzeigen
- [ ] Filter nach Zeitraum
- [ ] Filter nach Typ
- [ ] Export

---

## 6. History/Verlauf

### 6.1 History Page
- [ ] Timeline-Ansicht
- [ ] Filtern nach Typ
- [ ] Song-Historie
- [ ] Anwesenheits-Historie

---

## 7. Songs/Lieder

### 7.1 Songs List Page
- [x] Basis-Liste
- [ ] Suche
- [ ] Filter (mit Chor, mit Solo)
- [ ] Sortierung
- [ ] Song hinzufügen
- [ ] Song löschen

### 7.2 Song Detail Page
- [ ] Song-Details anzeigen
- [ ] Song bearbeiten
- [ ] Dateien anzeigen
- [ ] Noten-Viewer (PDF)
- [ ] Dateien hochladen
- [ ] Instrument-Zuordnung

### 7.3 Song Viewer
- [ ] PDF-Anzeige
- [ ] Zoom/Pan
- [ ] Seiten-Navigation

---

## 8. Instrumente/Gruppen

### 8.1 Instruments List Page
- [x] Basis-Liste
- [ ] Instrument hinzufügen
- [ ] Instrument bearbeiten
- [ ] Instrument löschen
- [ ] Reihenfolge ändern
- [ ] Kategorien

---

## 9. Lehrer

### 9.1 Teachers List Page
- [ ] Lehrerliste
- [ ] Lehrer hinzufügen
- [ ] Zugeordnete Instrumente

### 9.2 Teacher Detail Page
- [ ] Lehrer-Details
- [ ] Lehrer bearbeiten
- [ ] Zugeordnete Schüler

---

## 10. Meetings/Termine

### 10.1 Meeting List Page
- [ ] Termin-Liste
- [ ] Termin hinzufügen
- [ ] Kalender-Ansicht

### 10.2 Meeting Detail Page
- [ ] Termin-Details
- [ ] Termin bearbeiten
- [ ] Teilnehmer

---

## 11. Export

### 11.1 Export Page
- [ ] PDF Export (Package vorhanden: `pdf`, `printing`)
- [ ] Excel Export (Package vorhanden: `excel`)
- [ ] Zeitraum wählen
- [ ] Format wählen
- [ ] Teilen (`share_plus`)

---

## 12. Planning/Probenplan

### 12.1 Planning Page
- [ ] Probenplan erstellen
- [ ] Zeitblöcke definieren
- [ ] Lieder zuordnen
- [ ] Dirigent pro Block

---

## 13. Notifications

### 13.1 Notifications Page
- [ ] Einstellungen (Firebase Messaging)
- [ ] Telegram Integration
- [ ] Geburtstage
- [ ] An-/Abmeldungen
- [ ] Erinnerungen

---

## 14. Settings

### 14.1 Settings Shell
- [x] Navigations-Struktur
- [x] Logout

### 14.2 Profile Page
- [ ] Profil anzeigen
- [ ] Profil bearbeiten
- [ ] Passwort ändern

### 14.3 General Settings
- [ ] Anwesenheitstypen verwalten
- [ ] Typ hinzufügen/bearbeiten
- [ ] Verfügbare Status konfigurieren
- [x] Critical Rules

### 14.4 Handover
- [ ] Admin-Übergabe
- [ ] Rechte übertragen

### 14.5 Shifts/Schichten
- [ ] Schichtpläne
- [ ] Schicht-Definitionen

---

## 15. Registrierung (Tenant/Player)

### 15.1 Tenant Registration
- [ ] Neue Gruppe anlegen
- [ ] Initiale Konfiguration

### 15.2 Player Self-Registration
- [ ] Registrierungslink
- [ ] Selbst-Anmeldung
- [ ] Freigabe durch Admin

---

## 16. Services/Repositories

### 16.1 Core Services
- [x] Supabase Client
- [x] Auth Provider
- [ ] Repository Pattern einführen

### 16.2 Feature Services
- [ ] PlayerRepository
- [ ] AttendanceRepository
- [ ] SongRepository
- [ ] TeacherRepository
- [ ] MeetingRepository
- [ ] GroupRepository
- [ ] HistoryRepository
- [ ] AttendanceTypeRepository
- [ ] ShiftRepository
- [ ] NotificationRepository
- [ ] ImageService
- [ ] HolidayService
- [ ] CrossTenantService
- [ ] SignInOutService
- [ ] ProfileService
- [ ] FeedbackService
- [ ] TelegramService

---

## 17. Datenmodelle

### 17.1 Implementiert
- [x] Tenant
- [x] Person (inkl. Player-Felder)
- [x] Attendance
- [x] PersonAttendance
- [x] Song (Basis)
- [x] Instrument (Basis)
- [x] ChecklistItem
- [x] CriticalRule

### 17.2 Ausstehend
- [ ] Teacher
- [ ] Meeting
- [ ] History
- [ ] AttendanceType
- [ ] ShiftPlan / ShiftDefinition
- [ ] NotificationConfig
- [ ] SongFile
- [ ] SongCategory
- [ ] GroupCategory
- [ ] Viewer / Parent
- [ ] Organisation
- [ ] Feedback
- [ ] Church

---

## 18. Shared Widgets

- [ ] Avatar mit Bild (CachedNetworkImage)
- [ ] Reusable SearchBar
- [ ] Empty State Widget
- [ ] Skeleton Loader (shimmer)
- [ ] Toast/Snackbar Helper
- [ ] Confirmation Dialog
- [ ] Date Picker
- [ ] Status Badge/Chip
- [ ] Pull-to-Refresh Wrapper

---

## 19. Plattform-Features

- [ ] Haptics Feedback
- [ ] Network Status (connectivity_plus)
- [ ] Back Button Handling
- [ ] Deep Links
- [ ] Camera/Image Picker
- [ ] Local Auth (Biometrie)
- [ ] Offline Support

---

## 20. Realtime Subscriptions

- [ ] Player-Changes Channel
- [ ] Attendance-Changes Channel
- [ ] PersonAttendance-Changes Channel
- [ ] Tenant-Changes Channel
- [ ] Subscription Lifecycle (dispose)

---

## 21. Tests

- [ ] Unit Tests für Models
- [ ] Unit Tests für Repositories
- [ ] Widget Tests
- [ ] Integration Tests

---

## Priorisierung

### Phase 1 - Core (Aktuell) 🔴
1. [ ] Repository Pattern einführen
2. [ ] Realtime Subscriptions
3. [ ] AttendanceType Model & Service
4. [ ] Attendance Detail vollständig
5. [ ] Self-Service Overview
6. [ ] Stats Page

### Phase 2 - Verwaltung 🟡
7. [ ] Song Detail Page
8. [ ] Meeting Management
9. [ ] History Page
10. [ ] Export (PDF/Excel)
11. [ ] General Settings

### Phase 3 - Erweitert 🟢
12. [ ] Lehrer-Verwaltung
13. [ ] Schichtpläne
14. [ ] Handover
15. [ ] Registrierungsflow
16. [ ] Parents Dashboard

---

## Changelog

### 2026-02-17
- Initial migration plan created
- Analyzed both projects
- Documented current state

