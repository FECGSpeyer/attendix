-- Org-Pläne: Gruppe, die einen freien Ablaufplan (shared_plans) der
-- Organisation hinzugefügt hat. Die App setzt die Spalte beim Hinzufügen
-- („In Organisation …“) und zeigt in Termine › Org-Pläne den Namen dieser
-- Gruppe, wie bei Abläufen von Terminen. Leer bei Plänen, die vorher
-- hinzugefügt wurden. Nur eine neue, leere Spalte: bestehende Policies,
-- Ionic und das Lesen der Pläne bleiben unverändert.

alter table public.shared_plans
  add column if not exists tenant_id bigint
  references public.tenants(id) on delete set null;

-- Rückweg:
-- alter table public.shared_plans drop column if exists tenant_id;

-- Optional, einmalig: bestehende freie Org-Pläne nachtragen, wenn die
-- Person, die den Plan angelegt hat, in genau einer Gruppe der Organisation
-- Admin oder Verantwortliche ist. Alle anderen bleiben leer.
update public.shared_plans sp
set tenant_id = x.tenant_id
from (
  select p.id, min(tu."tenantId") as tenant_id
  from public.shared_plans p
  join public."tenantUsers" tu
    on tu."userId" = p.creator_user_id::text and tu.role in (1, 5)
  join public.tenant_group_tenants tgt
    on tgt.tenant_id = tu."tenantId" and tgt.tenant_group = p.org_id
  where p.org_id is not null and p.tenant_id is null
  group by p.id
  having count(distinct tu."tenantId") = 1
) x
where sp.id = x.id;
