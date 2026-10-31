-- part_detect_usage: daily call budget of the part-detect Edge Function
-- (reads page 1 of uploaded sheet music with a paid vision model).
-- Run once before deploying the function; without it every call is refused.
--
-- Only the service role (the Edge Function) reads or writes it: RLS on, no
-- policies, the function is not executable by anon/authenticated.

create table if not exists public.part_detect_usage (
  "tenantId" bigint not null,
  "userId" text not null,
  day date not null default (now() at time zone 'utc')::date,
  calls integer not null default 0,
  primary key ("tenantId", "userId", day)
);

alter table public.part_detect_usage enable row level security;

-- Counts one call and says whether it is still within both daily limits.
-- The tenant lock serialises calls of one tenant, so two parallel calls can
-- never both take the last unit.
create or replace function public.part_detect_take(
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
  perform pg_advisory_xact_lock(hashtext('part_detect'), p_tenant_id::integer);

  select coalesce(sum(calls), 0) into tenant_calls
    from part_detect_usage
    where "tenantId" = p_tenant_id and day = today;
  select coalesce(max(calls), 0) into user_calls
    from part_detect_usage
    where "tenantId" = p_tenant_id and "userId" = p_user_id and day = today;

  if tenant_calls >= p_tenant_limit or user_calls >= p_user_limit then
    return false;
  end if;

  insert into part_detect_usage ("tenantId", "userId", day, calls)
    values (p_tenant_id, p_user_id, today, 1)
    on conflict ("tenantId", "userId", day)
    do update set calls = part_detect_usage.calls + 1;

  -- Keep the table small: older days are no longer needed.
  delete from part_detect_usage where day < today - 7;
  return true;
end;
$$;

revoke all on function public.part_detect_take(bigint, text, integer, integer) from public, anon, authenticated;
grant execute on function public.part_detect_take(bigint, text, integer, integer) to service_role;
