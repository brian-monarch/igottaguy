-- A contact belongs to one or more categories.
-- The link has no author column: the contact author owns it.
-- There is no UPDATE policy. Replace a pair by deleting and inserting it.
-- PostgREST commits each request, so create_contact and set_contact_categories
-- apply the category list in the same transaction as the deferred check.

create table public.contact_categories (
  contact_id uuid not null references public.contacts (id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (contact_id, category_id)
);

comment on table public.contact_categories is
  'Many categories per contact. Working choice from the project rules; the PRD proposes it.';

create index contact_categories_category_id_idx
on public.contact_categories (category_id);

create or replace function private.contacts_require_category()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cid uuid;
begin
  if tg_table_name = 'contacts' then
    cid := new.id;
  else
    cid := coalesce(new.contact_id, old.contact_id);
  end if;

  if exists (select 1 from public.contacts where id = cid)
     and not exists (
       select 1
       from public.contact_categories
       where contact_id = cid
     )
  then
    raise exception 'contact must belong to at least one category';
  end if;

  return null;
end;
$$;

revoke all on function private.contacts_require_category() from public, anon, authenticated;
grant execute on function private.contacts_require_category() to authenticated, service_role;

create constraint trigger trg_contacts_require_category
after insert on public.contacts
deferrable initially deferred
for each row
execute function private.contacts_require_category();

create constraint trigger trg_contact_categories_require_category
after delete on public.contact_categories
deferrable initially deferred
for each row
execute function private.contacts_require_category();

alter table public.contact_categories enable row level security;

create policy contact_categories_select_visible
on public.contact_categories
for select
to authenticated
using (
  (select private.is_member())
  and exists (
    select 1
    from public.contacts
    where id = contact_id
      and (
        hidden_at is null
        or author_id = (select auth.uid())
        or (select private.is_admin())
      )
  )
);

create policy contact_categories_insert_author
on public.contact_categories
for insert
to authenticated
with check (
  (select private.is_member())
  and exists (
    select 1
    from public.contacts
    where id = contact_id
      and author_id = (select auth.uid())
  )
);

create policy contact_categories_delete_author
on public.contact_categories
for delete
to authenticated
using (
  (select private.is_member())
  and exists (
    select 1
    from public.contacts
    where id = contact_id
      and author_id = (select auth.uid())
  )
);

-- No UPDATE policy: delete the pair and insert the replacement.

create policy contact_categories_select_agent
on public.contact_categories
for select
to agent_writer
using (true);

revoke all on table public.contact_categories from public, anon;
grant select, insert, delete on table public.contact_categories to authenticated;
grant select, insert, update, delete on table public.contact_categories to service_role;
grant select on table public.contact_categories to agent_writer;

create or replace function public.create_contact(
  contact_name text,
  category_ids uuid[],
  contact_phone text default null,
  contact_website text default null,
  contact_details jsonb default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_id uuid;
begin
  if category_ids is null or cardinality(category_ids) < 1 then
    raise exception 'contact must belong to at least one category';
  end if;

  insert into public.contacts (name, phone, website, details, author_id)
  values (
    contact_name,
    contact_phone,
    contact_website,
    coalesce(contact_details, '{}'::jsonb),
    (select auth.uid())
  )
  returning id into new_id;

  insert into public.contact_categories (contact_id, category_id)
  select new_id, category_id
  from unnest(category_ids) as category_id
  group by category_id;

  return new_id;
end;
$$;

create or replace function public.set_contact_categories(
  target_contact_id uuid,
  category_ids uuid[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if category_ids is null or cardinality(category_ids) < 1 then
    raise exception 'contact must belong to at least one category';
  end if;

  if not exists (
    select 1
    from public.contacts
    where id = target_contact_id
      and author_id = (select auth.uid())
  ) then
    raise exception 'contact not found';
  end if;

  delete from public.contact_categories
  where contact_id = target_contact_id;

  insert into public.contact_categories (contact_id, category_id)
  select target_contact_id, category_id
  from unnest(category_ids) as category_id
  group by category_id;
end;
$$;

comment on function public.create_contact(text, uuid[], text, text, jsonb) is
  'Inserts a contact and its categories in one transaction.';
comment on function public.set_contact_categories(uuid, uuid[]) is
  'Replaces the category list for a contact the caller authored.';

revoke all on function public.create_contact(text, uuid[], text, text, jsonb) from public;
revoke all on function public.set_contact_categories(uuid, uuid[]) from public;
grant execute on function public.create_contact(text, uuid[], text, text, jsonb) to authenticated, service_role;
grant execute on function public.set_contact_categories(uuid, uuid[]) to authenticated, service_role;
