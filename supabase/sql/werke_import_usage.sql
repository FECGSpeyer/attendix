-- werke_import_usage: daily budget of the werke-import Edge Function (reads a
-- shared Google Drive folder and copies files into the tenant's songs for
-- "Noten importieren"). Run once before deploying the function; without it
-- every call is refused.
--
-- Only the service role (the Edge Function) reads or writes it: RLS on, no
-- policies, the function is not executable by anon/authenticated.

create table if not exists public.werke_import_usage (
  "tenantId" bigint not null,
  "userId" text not null,
  day date not null default (now() at time zone 'utc')::date,
  calls integer not null default 0,
  bytes bigint not null default 0,
  primary key ("tenantId", "userId", day)
);

alter table public.werke_import_usage enable row level security;

-- Counts [p_calls] calls (0 or 1) and [p_bytes] bytes and says whether they
-- are still within the day's limits: calls and bytes for the account over
-- all its tenants ([p_user_calls], [p_user_bytes]) and for the tenant over
-- all its accounts ([p_tenant_calls], [p_tenant_bytes]). Nothing is counted
-- when it says no. The function takes a call before it asks Google and the
-- bytes of a file before it downloads them. Two locks (always account first, then
-- tenant, so calls never wait on each other in a circle) serialise the calls
-- of one account and of one tenant: two parallel calls can never both take
-- the last unit.
create or replace function public.werke_import_take(
  p_tenant_id bigint,
  p_user_id text,
  p_calls integer,
  p_bytes bigint,
  p_user_calls integer,
  p_tenant_calls integer,
  p_user_bytes bigint,
  p_tenant_bytes bigint
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (now() at time zone 'utc')::date;
  user_calls integer;
  user_bytes bigint;
  tenant_calls integer;
  tenant_bytes bigint;
begin
  if p_calls < 0 or p_calls > 1 or p_bytes < 0 then
    return false;
  end if;

  perform pg_advisory_xact_lock(hashtext('werke_import_user'), hashtext(p_user_id));
  perform pg_advisory_xact_lock(hashtext('werke_import_tenant'), hashtext(p_tenant_id::text));

  select coalesce(sum(calls), 0), coalesce(sum(bytes), 0) into user_calls, user_bytes
    from werke_import_usage
    where "userId" = p_user_id and day = today;
  select coalesce(sum(calls), 0), coalesce(sum(bytes), 0) into tenant_calls, tenant_bytes
    from werke_import_usage
    where "tenantId" = p_tenant_id and day = today;

  if user_calls + p_calls > p_user_calls or tenant_calls + p_calls > p_tenant_calls
     or user_bytes + p_bytes > p_user_bytes or tenant_bytes + p_bytes > p_tenant_bytes then
    return false;
  end if;

  insert into werke_import_usage ("tenantId", "userId", day, calls, bytes)
    values (p_tenant_id, p_user_id, today, p_calls, p_bytes)
    on conflict ("tenantId", "userId", day)
    do update set calls = werke_import_usage.calls + excluded.calls,
                  bytes = werke_import_usage.bytes + excluded.bytes;

  -- Keep the table small: older days are no longer needed.
  delete from werke_import_usage where day < today - 7;
  return true;
end;
$$;

create index if not exists werke_import_usage_user_day_idx
  on public.werke_import_usage ("userId", day);

revoke all on function public.werke_import_take(bigint, text, integer, bigint, integer, integer, bigint, bigint)
  from public, anon, authenticated;
grant execute on function public.werke_import_take(bigint, text, integer, bigint, integer, integer, bigint, bigint)
  to service_role;
