-- supabase/sql/secure_push_tokens.sql
--
-- Sichert die Push-Token-Tabellen ab (device_tokens, live_activity_tokens).
--
-- Befund 2026-11-06 (Produktion): Ein normales Mitglied konnte per
-- GET /rest/v1/device_tokens?select=token,user_id alle Zeilen aller Nutzer
-- lesen. Die Migration im Ionic-Repo (MIGRATION_push_notifications.sql)
-- definiert nur eine Owner-Policy; live gibt es also mindestens eine weitere,
-- zu weite Policy (oder RLS ist aus).
--
-- Was diese Migration tut:
--   1. RLS an, ALLE bestehenden Policies der beiden Tabellen entfernen
--      (egal wie sie heißen) und je eine Owner-Policy pro Befehl anlegen:
--      user_id = auth.uid(). anon bekommt keinen Zugriff mehr.
--   2. SECURITY-DEFINER-Trigger: Wird ein Token gespeichert, löscht die DB
--      dasselbe Token bei ANDEREN Nutzern. Das ersetzt den Client-Schritt
--      "Remove this token from other users" in Ionic push.service.ts und
--      Flutter device_token_repository.dart, der mit Owner-RLS sonst still
--      0 Zeilen löschen würde (kein Fehler, App läuft unverändert weiter).
--
-- Edge Functions (send-push, live-activity-tick, live-activity-token,
-- delete-account, ...) nutzen den service_role-Key und umgehen RLS; sie sind
-- nicht betroffen.
--
-- Idempotent: kann mehrfach ausgeführt werden. Läuft in einer Transaktion.
-- NICHT vor Leons ausdrücklichem OK auf Produktion anwenden.

begin;

-- ---------------------------------------------------------------------------
-- 1. device_tokens
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

-- Nicht angemeldete Clients brauchen die Tabelle nie.
revoke all on table public.device_tokens from anon;

-- Ein Token gehört genau einem Nutzer: beim Speichern (Insert oder Upsert)
-- dasselbe Token bei allen anderen Nutzern entfernen. Läuft als Tabellen-
-- besitzer und umgeht damit die Owner-Policy, aber nur für genau dieses Token.
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

-- ---------------------------------------------------------------------------
-- 2. live_activity_tokens (laut supabase/sql/live_activity.sql schon owner-
--    only; hier trotzdem auf denselben Stand gebracht, falls live abweichend)
-- ---------------------------------------------------------------------------
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

revoke all on table public.live_activity_tokens from anon;

-- Gleiches Prinzip: meldet sich ein anderer Nutzer auf demselben iPhone an,
-- gehört dessen Push-to-Start-/Update-Token ab jetzt nur noch ihm. Sonst
-- bekäme das Gerät weiter Live Activities des vorherigen Nutzers, und die
-- Edge Function live-activity-token (sucht den Besitzer per Start-Token mit
-- limit(1)) könnte den falschen Nutzer treffen.
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

commit;

-- ---------------------------------------------------------------------------
-- Prüfung danach (nur lesen):
--
--   select tablename, policyname, cmd, roles, qual, with_check
--   from pg_policies
--   where schemaname = 'public'
--     and tablename in ('device_tokens', 'live_activity_tokens')
--   order by tablename, cmd;
--
-- Als normales Mitglied muss GET /rest/v1/device_tokens?select=user_id
-- danach nur noch die eigene Zeile liefern (oder keine).
--
-- Rückweg (falls Push danach nicht mehr ankommt): die vorher gesicherte
-- Ausgabe der Lese-Abfrage (pg_policies) wieder anlegen und die beiden
-- Trigger droppen:
--   drop trigger device_tokens_claim_token on public.device_tokens;
--   drop trigger live_activity_tokens_claim_token on public.live_activity_tokens;
-- ---------------------------------------------------------------------------
