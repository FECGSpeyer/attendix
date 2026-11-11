-- ai_assistant: the chat assistant ("Assistent" under "Mehr").
-- Run once before deploying the Edge Function `ai-assistant`; without it
-- every call is refused (column missing → the tenant counts as switched off,
-- function missing → budget check fails).
--
-- 1. tenants.ai_assistant_enabled: an admin switches the assistant on per
--    tenant (general settings). Off by default.
-- 2. ai_assistant_usage + ai_assistant_take: daily call budget per account
--    and per tenant. Only the service role (the Edge Function) reads or
--    writes it: RLS on, no policies, the function is not executable by
--    anon/authenticated. Only counts are stored, never the typed text.
--
-- Rollback:
--   drop function if exists public.ai_assistant_take(bigint, text, integer, integer);
--   drop table if exists public.ai_assistant_usage;
--   alter table public.tenants drop column if exists ai_assistant_enabled;

alter table public.tenants
  add column if not exists ai_assistant_enabled boolean not null default false;

create table if not exists public.ai_assistant_usage (
  "tenantId" bigint not null,
  "userId" text not null,
  day date not null default (now() at time zone 'utc')::date,
  calls integer not null default 0,
  primary key ("tenantId", "userId", day)
);

alter table public.ai_assistant_usage enable row level security;

create index if not exists ai_assistant_usage_user_day_idx
  on public.ai_assistant_usage ("userId", day);

-- Counts one call and says whether it is still within both daily limits:
-- [p_user_limit] for the account over all its tenants, [p_tenant_limit]
-- for the tenant over all its accounts. Locks always account first, then
-- tenant (as part_detect_take), so two parallel calls can never both take
-- the last unit.
create or replace function public.ai_assistant_take(
  p_tenant_id bigint,
  p_user_id text,
  p_user_limit integer,
  p_tenant_limit integer
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (now() at time zone 'utc')::date;
  user_calls integer;
  tenant_calls integer;
begin
  perform pg_advisory_xact_lock(hashtext('ai_assistant_user'), hashtext(p_user_id));
  perform pg_advisory_xact_lock(hashtext('ai_assistant_tenant'), p_tenant_id::integer);

  select coalesce(sum(calls), 0) into user_calls
    from ai_assistant_usage
    where "userId" = p_user_id and day = today;
  select coalesce(sum(calls), 0) into tenant_calls
    from ai_assistant_usage
    where "tenantId" = p_tenant_id and day = today;

  if user_calls >= p_user_limit or tenant_calls >= p_tenant_limit then
    return false;
  end if;

  insert into ai_assistant_usage ("tenantId", "userId", day, calls)
    values (p_tenant_id, p_user_id, today, 1)
    on conflict ("tenantId", "userId", day)
    do update set calls = ai_assistant_usage.calls + 1;

  -- Keep 60 days for the usage overview, older days are deleted.
  delete from ai_assistant_usage where day < today - 60;
  return true;
end;
$$;

revoke all on function public.ai_assistant_take(bigint, text, integer, integer) from public, anon, authenticated;
grant execute on function public.ai_assistant_take(bigint, text, integer, integer) to service_role;
