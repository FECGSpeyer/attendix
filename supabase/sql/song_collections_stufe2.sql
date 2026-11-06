-- STUFE 2 von supabase/sql/song_collections.sql (nach dem Store-Release,
-- setzt Stufe 1 voraus). Sichtbarkeitsregel und Mandanten-Prüfung auf songs.
-- In EINER Transaktion ausführen: sie setzt Werke, die auf eine Sammlung eines
-- anderen Mandanten zeigen, zurück ins Repertoire, bevor der Trigger greift.
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

-- Applied after Stufe 1, Werke may already point to a Sammlung of another
-- tenant (the foreign key only checks the id). Block writes on songs for
-- this transaction, put such Werke back into Repertoire, then install the
-- trigger, so no wrong reference is left or added in between.
lock table public.songs in share row exclusive mode;

update public.songs s
set collection_id = null
where s.collection_id is not null
  and not exists (
    select 1 from public.song_collections c
    where c.id = s.collection_id and c.tenant_id = s."tenantId"
  );

drop trigger if exists songs_collection_same_tenant on public.songs;
create trigger songs_collection_same_tenant
  before insert or update of collection_id, "tenantId" on public.songs
  for each row execute function public.songs_collection_same_tenant();

