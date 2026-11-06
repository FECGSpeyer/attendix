-- STUFE 2 von supabase/sql/song_collections.sql (nach dem Store-Release,
-- setzt Stufe 1 voraus). Sichtbarkeitsregel und Mandanten-Prüfung auf songs.
-- Rückbau: drop policy if exists "songs_collection_visibility" on public.songs;
--          drop trigger if exists songs_collection_same_tenant on public.songs;
--          drop function if exists public.songs_collection_same_tenant();

-- songs: only rows of a visible Sammlung (AND-ed with the existing policies).
drop policy if exists "songs_collection_visibility" on public.songs;
create policy "songs_collection_visibility"
  on public.songs
  as restrictive
  for select
  to anon, authenticated
  using (public.song_collection_visible(collection_id));

-- A Werk may only point to a Sammlung of its own song tenant.
create or replace function public.songs_collection_same_tenant()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.collection_id is not null and not exists (
    select 1 from song_collections c
    where c.id = new.collection_id and c.tenant_id = new."tenantId"
  ) then
    raise exception 'collection % does not belong to tenant %', new.collection_id, new."tenantId";
  end if;
  return new;
end;
$$;

drop trigger if exists songs_collection_same_tenant on public.songs;
create trigger songs_collection_same_tenant
  before insert or update of collection_id, "tenantId" on public.songs
  for each row execute function public.songs_collection_same_tenant();

