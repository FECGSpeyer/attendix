-- supabase/sql/security_stufe1_rollback.sql
--
-- Rückweg zu security_stufe1_rls.sql: stellt den Zustand vom 2026-11-11
-- wieder her (RLS auf den 24 Tabellen aus). Die in Stufe 1 angelegten
-- Policies bleiben liegen; ohne RLS sind sie wirkungslos und Stufe 1 kann
-- später erneut ausgeführt werden.
--
-- Nur ausführen, wenn nach Stufe 1 etwas Wichtiges in der App nicht mehr
-- geht. Danach ist die Datenbank wieder ohne Anmeldung offen.

begin;

select set_config('lock_timeout', '5s', true);

do $$
declare
  t text;
begin
  foreach t in array array[
    'attendance', 'attendance_types', 'churches', 'conductors',
    'device_tokens', 'feedback', 'group_categories', 'history', 'instruments',
    'meetings', 'notifications', 'parents', 'person_attendances', 'player',
    'questions', 'scores', 'shifts', 'song_categories', 'songs', 'teachers',
    'tenantUsers', 'tenant_role_permissions', 'tenants', 'viewers'
  ]
  loop
    execute format('alter table public.%I disable row level security', t);
  end loop;
end $$;

-- Tabellenrechte von anon wie vorher.
grant all on table public.attendance to anon;
grant all on table public.player to anon;
grant all on table public."tenantUsers" to anon;
grant all on table public.person_attendances to anon;

-- Token-Trigger entfernen (der Client löscht fremde Tokens dann wieder selbst).
drop trigger if exists device_tokens_claim_token on public.device_tokens;
drop trigger if exists live_activity_tokens_claim_token on public.live_activity_tokens;

-- live_activity_tokens: vorherige Policy (inhaltlich gleich).
drop policy if exists live_activity_tokens_owner_select on public.live_activity_tokens;
drop policy if exists live_activity_tokens_owner_insert on public.live_activity_tokens;
drop policy if exists live_activity_tokens_owner_update on public.live_activity_tokens;
drop policy if exists live_activity_tokens_owner_delete on public.live_activity_tokens;
drop policy if exists "owner manages live activity tokens" on public.live_activity_tokens;
create policy "owner manages live activity tokens" on public.live_activity_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- tenant_groups, tenant_group_tenants: vorherige Policies.
drop policy if exists stufe1_authenticated_all on public.tenant_groups;
drop policy if exists stufe1_anon_select on public.tenant_groups;
drop policy if exists "All" on public.tenant_groups;
create policy "All" on public.tenant_groups
  for all to public
  using (true) with check (true);

drop policy if exists stufe1_authenticated_all on public.tenant_group_tenants;
drop policy if exists stufe1_anon_select on public.tenant_group_tenants;
drop policy if exists "Enable read access for all users" on public.tenant_group_tenants;
create policy "Enable read access for all users" on public.tenant_group_tenants
  for all to public
  using (true) with check (true);

-- get_user_id_by_email wie vorher.
grant execute on function public.get_user_id_by_email(text) to public, anon;
alter function public.get_user_id_by_email(text) reset search_path;

commit;
