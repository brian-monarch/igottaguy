-- Optional free-text price context. One current entry per member per contact.
-- Members publish immediately and edit or remove only their own row.

create table public.price_entries (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references public.contacts (id) on delete cascade,
  author_id uuid not null references public.members (id) on delete restrict,
  price_text text not null,
  hidden_at timestamptz,
  hidden_by uuid references public.members (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint price_entries_one_author unique (contact_id, author_id),
  constraint price_entries_text_len check (
    char_length(btrim(price_text)) between 1 and 500
    and price_text = btrim(price_text)
  ),
  constraint price_entries_hidden_pair check (
    (hidden_at is null and hidden_by is null)
    or (hidden_at is not null and hidden_by is not null)
  )
);

comment on table public.price_entries is
  'Free-text pricing context. Not a single pricing model.';

create index price_entries_author_id_idx on public.price_entries (author_id);

create trigger trg_a_price_entries_set_updated_at
before update on public.price_entries
for each row
execute function private.set_updated_at();

create trigger trg_z_price_entries_write
before insert or update or delete on public.price_entries
for each row
execute function private.enforce_content_write();

alter table public.price_entries enable row level security;

create policy price_entries_select_visible
on public.price_entries
for select
to authenticated
using (
  (select private.is_member())
  and (
    (select private.is_admin())
    or author_id = (select auth.uid())
    or (
      hidden_at is null
      and (select private.contact_is_visible(contact_id))
    )
  )
);

create policy price_entries_insert_member
on public.price_entries
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and author_id = (select auth.uid())
  and (select private.is_member())
  and hidden_at is null
  and hidden_by is null
  and (select private.contact_is_visible(contact_id))
);

create policy price_entries_update_author_or_admin
on public.price_entries
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

create policy price_entries_delete_author_or_admin
on public.price_entries
for delete
to authenticated
using (
  (select private.is_member())
  and (
    author_id = (select auth.uid())
    or (select private.is_admin())
  )
);

revoke all on table public.price_entries from public, anon;
grant select, insert, update, delete on table public.price_entries to authenticated;
grant select, insert, update, delete on table public.price_entries to service_role;
