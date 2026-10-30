# RLS-Prüfung (Rollenrechte serverseitig)

Die App setzt Rollen und die konfigurierbaren Rollenrechte (`tenant_role_permissions`) im Client durch. Ob die Datenbank dasselbe erzwingt, lässt sich nur auf der echten DB prüfen. Die Abfragen unten laufen lesend im Supabase SQL-Editor und ändern nichts.

## 1. Tabellen ohne RLS

Jede Tabelle im Schema `public` muss RLS aktiv haben, sonst kann jeder mit dem Anon-Key alles lesen und schreiben.

```sql
select c.relname as tabelle
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
order by 1;
```

Erwartet: keine Zeile.

## 2. Policies, die alles erlauben

`USING (true)` oder `WITH CHECK (true)` gibt jedem in der Rolle Zugriff auf alle Zeilen, auch auf fremde Instanzen.

```sql
select tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and (qual = 'true' or with_check = 'true')
order by tablename, policyname;
```

Bekannt und bewusst zurückgestellt: `anon_select_shared_plans`, `auth_update_shared_plans` (siehe `docs/security-public-plans.md`).

## 3. Schreibrechte ohne Instanz-Bezug

Policies für INSERT, UPDATE und DELETE sollten die Instanz prüfen (`tenantId`, `tenant_id` oder ein Join auf `tenantUsers`).

```sql
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
  and coalesce(qual, '') || coalesce(with_check, '') !~* '(tenant|tenantusers|auth\.uid)'
order by tablename, cmd;
```

Jede Zeile hier ansehen: Darf wirklich jeder angemeldete Nutzer diese Zeilen ändern?

## 4. Rollen in den Schreib-Policies

Spieler (Rolle 2), Betrachter und Eltern dürfen laut App fremde Anwesenheiten, Personen und Termine nicht ändern. Diese Abfrage zeigt, welche Policies die Rolle aus `tenantUsers` prüfen:

```sql
select tablename, policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('attendance', 'person_attendances', 'player', 'songs', 'instruments', 'tenants', 'attendance_types', 'shifts')
  and cmd <> 'SELECT'
order by tablename, cmd, policyname;
```

Für jede Tabelle sollte mindestens eine Bedingung auf `role` in `tenantUsers` stehen (Dirigent/Helfer), sonst kann ein Spieler mit eigenem API-Aufruf schreiben, was die App ihm verbietet.

## 5. `tenant_role_permissions`

Die Schalter wie `attendance_create` oder `player_notes_view` wirken heute nur in der App. Serverseitig greifen sie nur, wenn Policies oder RPCs sie lesen:

```sql
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and (qual ilike '%tenant_role_permissions%' or with_check ilike '%tenant_role_permissions%');
```

Keine Zeile heißt: Die Rechte sind reine App-Logik. Das ist für die Bedienung in Ordnung, aber keine Sicherheitsgrenze. Ionic verhält sich gleich.

## Ergebnis zurückmelden

Die Ausgaben von 1 bis 5 (als CSV oder Screenshot) reichen, um konkrete Policy-Änderungen vorzuschlagen.
