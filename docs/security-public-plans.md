# Security: public plan pages (share keys / edit keys)

Status: **proposal, not applied** (SOL_FIX7). The SQL below has to be reviewed
and run in the Supabase SQL editor; the Flutter client already works with
both the current schema and the hardened one (see "Client migration").

## Problem

Public plan pages work without login (`/plan`, `/planung`, `/org-plan`).
Write access is protected by secret keys stored in the same rows:

| Table | Secret columns | Public (anon) RLS policy today |
|---|---|---|
| `attendance` | `share_key`, `share_edit_key` | `anon_select_shared_attendance`: `USING (share_key IS NOT NULL)`; `anon_read_org_plans`: org plan rows of orgs with a `public_plan_key` |
| `shared_plans` | `edit_key` | `anon_select_shared_plans`: `USING (true)`; `anon_read_adhoc_org_plans` |
| `tenant_groups` | `public_plan_key` | read by key (`getOrgByPublicKey`) |

RLS is row-level only. Any anon client can therefore run e.g.
`select id, edit_key from shared_plans` or
`select id, share_key, share_edit_key from attendance` (rows with a share key
or org plans) **without knowing any key**, and gets every edit key. The same
applies to realtime: a `postgres_changes` subscription delivers the full row,
including the key columns, to every subscriber RLS lets read the row.
In addition `auth_update_shared_plans` (`TO authenticated USING (true)`) lets
every logged-in user update every ad-hoc plan; the edit key check only lives
in the app.

## What the client does now (mitigation, no schema change)

- Public reads only select whitelisted columns
  (`PublicPlanRepository._sharedAttendanceColumns` / `_sharedPlanColumns`);
  edit keys are verified with `id + key` filters that only return whether a
  row matched (`verifySharedAttendanceEditKey` / `verifySharedPlanEditKey`).
- The public organisation page (`org_plan_public_page.dart`) no longer
  subscribes to `postgres_changes` of `attendance` / `shared_plans` (the
  Ionic page does). It polls the whitelisted select every 15 s instead, so an
  anonymous viewer never receives `share_edit_key` / `edit_key` over the
  WebSocket.
- `shared_plan_page.dart` subscribes to realtime only in edit mode, i.e.
  after the edit key from the URL was verified. That viewer already knows the
  keys of exactly that row.

This does not stop a malicious client from selecting the columns directly;
only the server-side change below does.

## Proposed server-side fix

Idea: anon (and non-member authenticated users) lose direct `SELECT` on the
secret columns. Public reads go through `SECURITY DEFINER` functions that
require the key and return only public columns. Edits go through functions
that check the edit key in the database.

```sql
-- 1) Column privileges: secrets are not readable by API roles at all.
--    (Members/admins of a tenant read share keys via the RPC in 4.)
REVOKE SELECT ON attendance FROM anon;
GRANT SELECT (id, date, duration_days, plan, extra_plans, type_id, "typeInfo",
              "tenantId", is_org_plan)
  ON attendance TO anon;

REVOKE SELECT ON shared_plans FROM anon, authenticated;
GRANT SELECT (id, plan_title, date, time, end_time, fields, branding_id,
              creator_user_id, created_at, org_id)
  ON shared_plans TO anon, authenticated;

-- Remove the broad anon row policies; the RPCs below replace them.
DROP POLICY IF EXISTS "anon_select_shared_attendance" ON attendance;
DROP POLICY IF EXISTS "anon_select_shared_plans" ON shared_plans;
-- Org members may still update ad-hoc org plans (org_members_update_...);
-- everyone else edits through update_shared_plan().
DROP POLICY IF EXISTS "auth_update_shared_plans" ON shared_plans;

-- 2) Read a shared Termin plan by id + share key.
CREATE OR REPLACE FUNCTION public.get_shared_attendance_plan(p_id bigint, p_key text)
RETURNS TABLE (id bigint, date text, duration_days int, plan jsonb,
               extra_plans jsonb, type_id text, "typeInfo" text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT a.id, a.date, a.duration_days, a.plan, a.extra_plans, a.type_id, a."typeInfo"
  FROM attendance a
  WHERE a.id = p_id AND a.share_key IS NOT NULL AND a.share_key = p_key;
$$;

-- 3) Verify an edit key without returning it.
CREATE OR REPLACE FUNCTION public.verify_shared_attendance_edit_key(p_id bigint, p_key text, p_edit_key text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM attendance
                 WHERE id = p_id AND share_key = p_key
                   AND share_edit_key IS NOT NULL AND share_edit_key = p_edit_key);
$$;

CREATE OR REPLACE FUNCTION public.verify_shared_plan_edit_key(p_id text, p_edit_key text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM shared_plans WHERE id = p_id AND edit_key = p_edit_key);
$$;

-- 4) Edits by key holders (anon or any user) are checked in the database.
CREATE OR REPLACE FUNCTION public.update_shared_attendance_plan(
  p_id bigint, p_key text, p_edit_key text, p_plan jsonb, p_extra_plans jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE attendance SET plan = p_plan, extra_plans = p_extra_plans
  WHERE id = p_id AND share_key = p_key AND share_edit_key = p_edit_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid share key' USING ERRCODE = '42501'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.update_shared_plan(
  p_id text, p_edit_key text, p_plan_title text, p_date text, p_time text,
  p_end_time text, p_fields jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE shared_plans SET plan_title = p_plan_title, date = p_date, time = p_time,
         end_time = p_end_time, fields = p_fields
  WHERE id = p_id AND edit_key = p_edit_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid edit key' USING ERRCODE = '42501'; END IF;
END $$;

-- Tenant members that manage sharing read/write the keys of their own rows
-- via SECURITY DEFINER RPCs that check tenantUsers role, e.g.:
CREATE OR REPLACE FUNCTION public.get_attendance_share_keys(p_id bigint)
RETURNS TABLE (share_key text, share_edit_key text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT a.share_key, a.share_edit_key FROM attendance a
  JOIN "tenantUsers" tu ON tu."tenantId" = a."tenantId" AND tu."userId" = auth.uid()
  WHERE a.id = p_id AND tu.role IN (1, 5); -- Role.admin / Role.responsible
$$;

REVOKE ALL ON FUNCTION public.get_shared_attendance_plan(bigint, text),
  public.verify_shared_attendance_edit_key(bigint, text, text),
  public.verify_shared_plan_edit_key(text, text),
  public.update_shared_attendance_plan(bigint, text, text, jsonb, jsonb),
  public.update_shared_plan(text, text, text, text, text, text, jsonb),
  public.get_attendance_share_keys(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_shared_attendance_plan(bigint, text),
  public.verify_shared_attendance_edit_key(bigint, text, text),
  public.verify_shared_plan_edit_key(text, text),
  public.update_shared_attendance_plan(bigint, text, text, jsonb, jsonb),
  public.update_shared_plan(text, text, text, text, text, text, jsonb)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_attendance_share_keys(bigint) TO authenticated;
```

### Realtime

Realtime `postgres_changes` checks RLS per row but always sends all columns.
After step 1 anon has no row policy on `shared_plans` / non-org `attendance`
anymore, so it no longer receives those events at all. For live updates of
public pages use a **Broadcast** channel instead: an `AFTER UPDATE` trigger
calls `realtime.send(jsonb_build_object('id', NEW.id), 'plan_changed',
'public-plan-' || NEW.id, false)` with only the id; the client re-fetches via
the RPC above. Alternatively move the keys into a separate table
(`plan_share_secrets(plan_ref, share_key, edit_key)`) that has no anon policy
and is not part of the `supabase_realtime` publication.

## Client migration once applied

1. `PublicPlanRepository.getSharedAttendancePlan` → `rpc('get_shared_attendance_plan')`.
2. `verifySharedAttendanceEditKey` / `verifySharedPlanEditKey` → the verify RPCs.
3. Public saves (`shared_plan_page.dart`, `public_planning_page.dart`) →
   `update_shared_attendance_plan` / `update_shared_plan`.
4. Planning page reading/writing `share_key` / `share_edit_key` → member RPC.
5. Ionic must be migrated at the same time (it reads the columns directly).
