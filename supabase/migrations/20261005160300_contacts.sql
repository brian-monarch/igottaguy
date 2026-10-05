-- Contacts. Members publish immediately. They edit or remove only their own
-- rows. Admins may hide or restore (hidden_at) or delete, and may not rewrite
-- the body of someone else's contact.
-- details jsonb holds category-specific fields (sitter rate, restaurant city).
-- That shape is a working choice from the project rules, not a PRD field list.
-- Phone is E.164. Price does not live on this row.

create extension if not exists pg_trgm with schema extensions;

create or replace function private.enforce_content_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  jwt_role text := coalesce((select auth.role()), '');
begin
  if jwt_role = 'service_role'
     or (
       jwt_role = ''
       and current_user in ('postgres', 'supabase_admin', 'service_role')
     )
  then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if jwt_role <> 'authenticated' then
    raise exception 'not allowed';
  end if;

  if uid is null or not private.is_member() then
    raise exception 'not a member';
  end if;

  if tg_op = 'DELETE' then
    if old.author_id is distinct from uid and not private.is_admin() then
      raise exception 'members may only remove their own content';
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    if new.author_id is distinct from uid then
      raise exception 'author_id must be the signed-in member';
    end if;
    if new.hidden_at is not null or new.hidden_by is not null then
      raise exception 'new content cannot be hidden';
    end if;
    if (to_jsonb(new) ? 'referrer_label')
       and nullif(to_jsonb(new) ->> 'referrer_label', '') is not null
    then
      raise exception 'referrer_label is only set by import';
    end if;
    return new;
  end if;

  if private.is_admin()
     and (
       new.hidden_at is distinct from old.hidden_at
       or new.hidden_by is distinct from old.hidden_by
     )
  then
    if (to_jsonb(new) - 'hidden_at' - 'hidden_by' - 'updated_at' - 'search_vector')
       is distinct from
       (to_jsonb(old) - 'hidden_at' - 'hidden_by' - 'updated_at' - 'search_vector')
    then
      raise exception 'admins may only hide or restore content';
    end if;
    if new.hidden_at is null then
      new.hidden_by := null;
    else
      new.hidden_by := uid;
    end if;
    return new;
  end if;

  if old.author_id = uid then
    if (to_jsonb(new) -> 'author_id') is distinct from (to_jsonb(old) -> 'author_id')
       or (to_jsonb(new) -> 'id') is distinct from (to_jsonb(old) -> 'id')
       or (to_jsonb(new) -> 'created_at') is distinct from (to_jsonb(old) -> 'created_at')
       or (to_jsonb(new) -> 'contact_id') is distinct from (to_jsonb(old) -> 'contact_id')
       or (to_jsonb(new) -> 'hidden_at') is distinct from (to_jsonb(old) -> 'hidden_at')
       or (to_jsonb(new) -> 'hidden_by') is distinct from (to_jsonb(old) -> 'hidden_by')
       or (to_jsonb(new) -> 'referrer_label') is distinct from (to_jsonb(old) -> 'referrer_label')
    then
      raise exception 'members may only edit their own content fields';
    end if;
    return new;
  end if;

  if private.is_admin() then
    raise exception 'admins may only hide or restore content';
  end if;

  raise exception 'members may only edit their own content';
end;
$$;

revoke all on function private.enforce_content_write() from public, anon, authenticated;
grant execute on function private.enforce_content_write() to authenticated, service_role;

create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  website text,
  details jsonb not null default '{}'::jsonb,
  author_id uuid not null references public.members (id) on delete restrict,
  hidden_at timestamptz,
  hidden_by uuid references public.members (id) on delete restrict,
  search_vector tsvector generated always as (
    to_tsvector('english', name || ' ' || coalesce(details::text, ''))
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint contacts_name_len check (
    char_length(name) between 1 and 200
    and name = btrim(name)
  ),
  constraint contacts_phone_e164 check (
    phone is null or phone ~ '^\+[1-9]\d{1,14}$'
  ),
  constraint contacts_website_url check (
    website is null
    or (
      char_length(website) <= 500
      and website ~ '^https?://[^[:space:]]+$'
    )
  ),
  constraint contacts_details_object check (
    jsonb_typeof(details) = 'object'
    and octet_length(details::text) <= 8000
  ),
  constraint contacts_hidden_pair check (
    (hidden_at is null and hidden_by is null)
    or (hidden_at is not null and hidden_by is not null)
  )
);

comment on table public.contacts is
  'A recommended person, business, place, or activity. Category-specific fields live in details.';
comment on column public.contacts.phone is
  'E.164. The app normalizes before insert; this constraint rejects other shapes.';
comment on column public.contacts.details is
  'Category-specific JSON object, for example sitter rate or restaurant city. Validated in the app.';

create or replace function private.contact_is_visible(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_member()
    and exists (
      select 1
      from public.contacts
      where id = target
        and hidden_at is null
    );
$$;

revoke all on function private.contact_is_visible(uuid) from public, anon, authenticated;
grant execute on function private.contact_is_visible(uuid) to authenticated, service_role;

create index contacts_author_id_idx on public.contacts (author_id);
create index contacts_phone_idx on public.contacts (phone) where phone is not null;
create index contacts_search_idx on public.contacts using gin (search_vector);
create index contacts_name_trgm_idx on public.contacts using gin (name extensions.gin_trgm_ops);

create trigger trg_a_contacts_set_updated_at
before update on public.contacts
for each row
execute function private.set_updated_at();

create trigger trg_z_contacts_write
before insert or update or delete on public.contacts
for each row
execute function private.enforce_content_write();

alter table public.contacts enable row level security;

create policy contacts_select_visible
on public.contacts
for select
to authenticated
using (
  (select private.is_member())
  and (
    hidden_at is null
    or author_id = (select auth.uid())
    or (select private.is_admin())
  )
);

create policy contacts_insert_member
on public.contacts
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and author_id = (select auth.uid())
  and (select private.is_member())
  and hidden_at is null
  and hidden_by is null
);

create policy contacts_update_author_or_admin
on public.contacts
for update
to authenticated
using (
  (select private.is_member())
  and (
    author_id = (select auth.uid())
    or (select private.is_admin())
  )
)
with check (
  (select private.is_member())
  and (
    author_id = (select auth.uid())
    or (select private.is_admin())
  )
);

create policy contacts_delete_author_or_admin
on public.contacts
for delete
to authenticated
using (
  (select private.is_member())
  and (
    author_id = (select auth.uid())
    or (select private.is_admin())
  )
);

-- Freshness and duplicate agents read contacts, including hidden rows.
create policy contacts_select_agent
on public.contacts
for select
to agent_writer
using (true);

revoke all on table public.contacts from public, anon;
grant select, insert, update, delete on table public.contacts to authenticated;
grant select, insert, update, delete on table public.contacts to service_role;
grant select on table public.contacts to agent_writer;
