-- supabase/sql/security_stufe1_rls.sql
--
-- Sicherheit Stufe 1: Row Level Security auf allen Tabellen im Schema public.
--
-- Befund 2026-11-11 (Produktion, Supabase Security Advisor):
--   24 Tabellen hatten RLS aus (rls_disabled_in_public), darunter player,
--   person_attendances, attendance, "tenantUsers", tenants, device_tokens.
--   Mit dem öffentlichen App-Schlüssel (anon) konnte jeder OHNE Anmeldung
--   alle Zeilen lesen, ändern und löschen.
--
-- Was diese Stufe tut:
--   1. RLS auf allen 24 Tabellen an.
--   2. Nicht angemeldete Clients (anon) bekommen nur noch, was die
--      öffentlichen Seiten beider Apps (Ionic + Flutter) wirklich brauchen:
--        - Anmeldelink /register/:id   (Instanz, Gruppen, Gemeinden lesen;
--                                       eigene Anmeldung anlegen)
--        - Werke-Link /:songSharingId  (Werke, Kategorien, Gruppen, Historie)
--        - Ablaufplan-Links /plan, /org-plan (bestehende Policies)
--   3. Angemeldete Nutzer (authenticated) behalten exakt den heutigen
--      Zugriff (Policy "true"). Ausnahmen, weil dort sicher eingrenzbar:
--        - device_tokens, live_activity_tokens: nur eigene Zeilen
--          (ersetzt den vorbereiteten PR #383)
--        - notifications: nur die eigene Zeile
--        - feedback, questions: nur anlegen, nicht lesen
--   4. tenant_groups / tenant_group_tenants: anon darf nur noch lesen
--      (bisher durfte anon dort alles, auch löschen).
--   5. get_user_id_by_email: nicht mehr ohne Anmeldung aufrufbar.
--
-- Was diese Stufe NICHT tut (Stufe 2, braucht App-Änderungen und Tests):
--   Angemeldete Nutzer sehen per API weiterhin die Daten ALLER Instanzen.
--   Die Trennung nach Instanz (tenantId) und nach Rolle folgt in Stufe 2.
--
-- Edge Functions, Cron-Jobs und Webhooks nutzen den service_role-Key und
-- umgehen RLS; sie sind nicht betroffen.
--
-- Idempotent: kann mehrfach ausgeführt werden. Läuft in einer Transaktion.
-- Rückweg: supabase/sql/security_stufe1_rollback.sql
-- NICHT ohne Leons ausdrückliches OK auf Produktion anwenden.

begin;

-- Nicht ewig auf Sperren warten: lieber abbrechen und neu versuchen, als die
-- laufende App zu blockieren.
select set_config('lock_timeout', '5s', true);

-- ---------------------------------------------------------------------------
-- 0. Hilfsfunktionen. Eigenes Schema, das die API nicht ausliefert (nur
--    public und graphql_public sind exponiert), damit sie nicht als RPC
--    aufrufbar sind. SECURITY DEFINER, damit sie unabhängig von den Policies
--    der gelesenen Tabellen sind.
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;

-- Instanz hat einen Anmeldelink.
create or replace function private.registration_tenant(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tenants t
    where t.id = p_tenant_id and t.register_id is not null
  );
$$;

-- Instanz hat einen Anmeldelink und genehmigt Anmeldungen automatisch.
create or replace function private.auto_approve_tenant(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tenants t
    where t.id = p_tenant_id
      and t.register_id is not null
      and coalesce(t.auto_approve_registrations, false)
  );
$$;

-- Instanzen, deren Werke über einen öffentlichen Link geteilt sind, samt der
-- Quell-Instanz bei synchronisierten Werken.
create or replace function private.song_sharing_tenant(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tenants t
    where t.song_sharing_id is not null
      and (t.id = p_tenant_id or t.song_source_tenant_id = p_tenant_id)
  );
$$;

-- Eintrag in einen Termin für eine Person, die sich gerade (ohne bestätigtes
-- Konto) selbst angemeldet hat und automatisch genehmigt wurde.
create or replace function private.registration_backfill_allowed(
  p_person_id bigint,
  p_attendance_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.player p
    join public.attendance a on a."tenantId" = p."tenantId"
    join public.tenants t on t.id = p."tenantId"
    where p.id = p_person_id
      and a.id = p_attendance_id
      and p.self_register is true
      and coalesce(p.pending, false) = false
      and p.created_at > now() - interval '15 minutes'
      and t.register_id is not null
      and coalesce(t.auto_approve_registrations, false)
  );
$$;

revoke all on function private.registration_tenant(bigint) from public;
revoke all on function private.auto_approve_tenant(bigint) from public;
revoke all on function private.song_sharing_tenant(bigint) from public;
revoke all on function private.registration_backfill_allowed(bigint, bigint) from public;
grant execute on function private.registration_tenant(bigint) to anon, authenticated, service_role;
grant execute on function private.auto_approve_tenant(bigint) to anon, authenticated, service_role;
grant execute on function private.song_sharing_tenant(bigint) to anon, authenticated, service_role;
grant execute on function private.registration_backfill_allowed(bigint, bigint) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1. Angemeldete Nutzer: Zugriff wie bisher (Stufe 2 grenzt nach Instanz ein).
--    Bestehende, engere Policies dieser Tabellen bleiben stehen; sie werden
--    mit dieser Policy per ODER verknüpft und ändern deshalb nichts.
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'attendance', 'attendance_types', 'churches', 'conductors',
    'group_categories', 'history', 'instruments', 'meetings', 'parents',
    'person_attendances', 'player', 'scores', 'shifts', 'song_categories',
    'songs', 'teachers', 'tenantUsers', 'tenant_role_permissions', 'tenants',
    'viewers'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists stufe1_authenticated_all on public.%I', t);
    execute format(
      'create policy stufe1_authenticated_all on public.%I '
      'for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Nicht angemeldete Clients (anon)
-- ---------------------------------------------------------------------------

-- tenants: Anmeldelink, Werke-Link, öffentliche Organisations-Pläne
-- (dort wird der Name der Instanz angezeigt).
drop policy if exists stufe1_anon_select on public.tenants;
create policy stufe1_anon_select on public.tenants
  for select to anon
  using (
    register_id is not null
    or song_sharing_id is not null
    or private.song_sharing_tenant(id)
    or exists (
      select 1
      from public.tenant_group_tenants tgt
      join public.tenant_groups tg on tg.id = tgt.tenant_group
      where tgt.tenant_id = tenants.id and tg.public_plan_key is not null
    )
  );

-- churches: Gemeindeliste im Anmeldeformular, eigene Gemeinde anlegen.
drop policy if exists stufe1_anon_select on public.churches;
create policy stufe1_anon_select on public.churches
  for select to anon
  using (true);

drop policy if exists stufe1_anon_insert on public.churches;
create policy stufe1_anon_insert on public.churches
  for insert to anon
  with check (created_from is null);

-- instruments, group_categories, attendance_types: Gruppenwahl im
-- Anmeldeformular, Anzeige auf der öffentlichen Werke-Seite, Eintrag in
-- kommende Termine nach automatischer Genehmigung.
drop policy if exists stufe1_anon_select on public.instruments;
create policy stufe1_anon_select on public.instruments
  for select to anon
  using (
    private.registration_tenant("tenantId")
    or private.song_sharing_tenant("tenantId")
  );

drop policy if exists stufe1_anon_select on public.group_categories;
create policy stufe1_anon_select on public.group_categories
  for select to anon
  using (
    private.registration_tenant(tenant_id)
    or private.song_sharing_tenant(tenant_id)
  );

drop policy if exists stufe1_anon_select on public.attendance_types;
create policy stufe1_anon_select on public.attendance_types
  for select to anon
  using (
    private.registration_tenant(tenant_id)
    or private.song_sharing_tenant(tenant_id)
  );

-- songs, song_categories, history: öffentliche Werke-Seite.
drop policy if exists stufe1_anon_select on public.songs;
create policy stufe1_anon_select on public.songs
  for select to anon
  using (private.song_sharing_tenant("tenantId"));

drop policy if exists stufe1_anon_select on public.song_categories;
create policy stufe1_anon_select on public.song_categories
  for select to anon
  using (private.song_sharing_tenant(tenant_id));

drop policy if exists stufe1_anon_select on public.history;
create policy stufe1_anon_select on public.history
  for select to anon
  using (private.song_sharing_tenant("tenantId"));

-- attendance: Die Lese-Policies für geteilte Pläne (share_key) und
-- Organisations-Pläne bestehen schon. Neu:
--   a) Bearbeiten eines geteilten Plans über den Bearbeiten-Link, nur die
--      Plan-Spalten.
--   b) Kommende Termine lesen, wenn die Instanz Anmeldungen automatisch
--      genehmigt (die App trägt die neue Person dann in diese Termine ein).
drop policy if exists stufe1_anon_update_shared_plan on public.attendance;
create policy stufe1_anon_update_shared_plan on public.attendance
  for update to anon
  using (share_key is not null and share_edit_key is not null)
  with check (share_key is not null and share_edit_key is not null);

revoke insert, update, delete, truncate on table public.attendance from anon;
grant update (plan, extra_plans) on table public.attendance to anon;

drop policy if exists stufe1_anon_select_registration on public.attendance;
create policy stufe1_anon_select_registration on public.attendance
  for select to anon
  using (
    date > now() - interval '2 days'
    and private.auto_approve_tenant("tenantId")
  );

-- player: Selbstanmeldung ohne bestätigtes Konto (Passwort-Variante). Die
-- App legt die Person an, liest die neue Zeile zurück und setzt danach das
-- Profilbild. Sichtbar und änderbar ist nur die frische Anmeldung selbst
-- (15 Minuten), nichts vom Bestand.
drop policy if exists stufe1_anon_insert_registration on public.player;
create policy stufe1_anon_insert_registration on public.player
  for insert to anon
  with check (
    self_register is true
    and private.registration_tenant("tenantId")
  );

drop policy if exists stufe1_anon_select_registration on public.player;
create policy stufe1_anon_select_registration on public.player
  for select to anon
  using (
    self_register is true
    and created_at > now() - interval '15 minutes'
    and private.registration_tenant("tenantId")
  );

drop policy if exists stufe1_anon_update_registration on public.player;
create policy stufe1_anon_update_registration on public.player
  for update to anon
  using (
    self_register is true
    and created_at > now() - interval '15 minutes'
    and private.registration_tenant("tenantId")
  )
  with check (
    self_register is true
    and created_at > now() - interval '15 minutes'
    and private.registration_tenant("tenantId")
  );

revoke delete, truncate on table public.player from anon;

-- "tenantUsers": Zugang zur Instanz bei der Selbstanmeldung. Nur als
-- Bewerber (7) oder, bei automatischer Genehmigung, als Mitglied (2).
drop policy if exists stufe1_anon_insert_registration on public."tenantUsers";
create policy stufe1_anon_insert_registration on public."tenantUsers"
  for insert to anon
  with check (
    private.registration_tenant("tenantId")
    and (
      role = 7
      or (role = 2 and private.auto_approve_tenant("tenantId"))
    )
  );

revoke update, delete, truncate on table public."tenantUsers" from anon;

-- person_attendances: Eintrag der frisch (automatisch genehmigten) Person in
-- die kommenden Termine ihrer Instanz.
drop policy if exists stufe1_anon_insert_registration on public.person_attendances;
create policy stufe1_anon_insert_registration on public.person_attendances
  for insert to anon
  with check (private.registration_backfill_allowed(person_id, attendance_id));

revoke update, delete, truncate on table public.person_attendances from anon;

-- ---------------------------------------------------------------------------
-- 3. notifications: nur die eigene Zeile (id = Konto-ID). Beide Apps lesen
--    und schreiben ausschließlich mit id = eigene Konto-ID.
-- ---------------------------------------------------------------------------
alter table public.notifications enable row level security;

drop policy if exists stufe1_owner_all on public.notifications;
create policy stufe1_owner_all on public.notifications
  for all to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 4. feedback, questions: nur anlegen. Gelesen werden sie nur von den
--    Webhooks (service_role) und im Dashboard.
-- ---------------------------------------------------------------------------
alter table public.feedback enable row level security;
alter table public.questions enable row level security;

drop policy if exists stufe1_authenticated_insert on public.feedback;
create policy stufe1_authenticated_insert on public.feedback
  for insert to authenticated
  with check (user_id is null or user_id = (select auth.uid()));

drop policy if exists stufe1_authenticated_insert on public.questions;
create policy stufe1_authenticated_insert on public.questions
  for insert to authenticated
  with check (user_id is null or user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 5. device_tokens, live_activity_tokens: nur eigene Zeilen (aus PR #383).
--    Trigger: Wird ein Token gespeichert, löscht die DB dasselbe Token bei
--    ANDEREN Nutzern. Das ersetzt den Client-Schritt "Remove this token from
--    other users", der mit Owner-RLS sonst still 0 Zeilen löschen würde.
-- ---------------------------------------------------------------------------
alter table public.device_tokens enable row level security;

do $$
declare p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'device_tokens'
  loop
    execute format('drop policy %I on public.device_tokens', p.policyname);
  end loop;
end $$;

create policy device_tokens_owner_select on public.device_tokens
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy device_tokens_owner_insert on public.device_tokens
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy device_tokens_owner_update on public.device_tokens
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy device_tokens_owner_delete on public.device_tokens
  for delete to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.device_tokens_claim_token()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.device_tokens
  where token = new.token
    and user_id <> new.user_id;
  return new;
end;
$$;

revoke all on function public.device_tokens_claim_token() from public, anon, authenticated;

drop trigger if exists device_tokens_claim_token on public.device_tokens;
create trigger device_tokens_claim_token
  before insert or update of token, user_id on public.device_tokens
  for each row execute function public.device_tokens_claim_token();

alter table public.live_activity_tokens enable row level security;

do $$
declare p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'live_activity_tokens'
  loop
    execute format('drop policy %I on public.live_activity_tokens', p.policyname);
  end loop;
end $$;

create policy live_activity_tokens_owner_select on public.live_activity_tokens
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy live_activity_tokens_owner_insert on public.live_activity_tokens
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy live_activity_tokens_owner_update on public.live_activity_tokens
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy live_activity_tokens_owner_delete on public.live_activity_tokens
  for delete to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.live_activity_tokens_claim_token()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.live_activity_tokens
  where token = new.token
    and kind = new.kind
    and user_id <> new.user_id;
  return new;
end;
$$;

revoke all on function public.live_activity_tokens_claim_token() from public, anon, authenticated;

drop trigger if exists live_activity_tokens_claim_token on public.live_activity_tokens;
create trigger live_activity_tokens_claim_token
  before insert or update of token, kind, user_id on public.live_activity_tokens
  for each row execute function public.live_activity_tokens_claim_token();

-- ---------------------------------------------------------------------------
-- 6. tenant_groups, tenant_group_tenants: Die bisherigen Policies erlaubten
--    JEDEM (auch anon) alles. Neu: anon nur lesen (öffentliche
--    Organisations-Pläne), angemeldete Nutzer wie bisher.
-- ---------------------------------------------------------------------------
drop policy if exists "All" on public.tenant_groups;
drop policy if exists stufe1_authenticated_all on public.tenant_groups;
create policy stufe1_authenticated_all on public.tenant_groups
  for all to authenticated
  using (true) with check (true);
drop policy if exists stufe1_anon_select on public.tenant_groups;
create policy stufe1_anon_select on public.tenant_groups
  for select to anon
  using (true);

drop policy if exists "Enable read access for all users" on public.tenant_group_tenants;
drop policy if exists stufe1_authenticated_all on public.tenant_group_tenants;
create policy stufe1_authenticated_all on public.tenant_group_tenants
  for all to authenticated
  using (true) with check (true);
drop policy if exists stufe1_anon_select on public.tenant_group_tenants;
create policy stufe1_anon_select on public.tenant_group_tenants
  for select to anon
  using (true);

-- ---------------------------------------------------------------------------
-- 7. get_user_id_by_email: lieferte jedem ohne Anmeldung die Konto-ID zu
--    einer E-Mail-Adresse. Beide Apps rufen sie nur angemeldet auf.
-- ---------------------------------------------------------------------------
revoke execute on function public.get_user_id_by_email(text) from public, anon;
grant execute on function public.get_user_id_by_email(text) to authenticated, service_role;
alter function public.get_user_id_by_email(text) set search_path = '';

commit;

-- ---------------------------------------------------------------------------
-- Prüfung danach (nur lesen):
--
--   -- Erwartet: keine Zeile.
--   select c.relname
--   from pg_class c join pg_namespace n on n.oid = c.relnamespace
--   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
--
--   -- Ohne Anmeldung (anon-Key) muss
--   --   GET /rest/v1/player?select=id&limit=1
--   -- eine leere Liste liefern.
-- ---------------------------------------------------------------------------
