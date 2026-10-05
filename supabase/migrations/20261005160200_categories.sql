-- Shared category taxonomy. Not member-authored, so writes are admin-only.
-- The seed list is the PRD's initial household and family coverage.

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  sort_order integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint categories_slug_shape check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint categories_name_len check (
    char_length(name) between 1 and 80
    and name = btrim(name)
  )
);

comment on table public.categories is
  'Directory categories. Initial rows match the PRD list; admins can add more.';

create trigger trg_a_categories_set_updated_at
before update on public.categories
for each row
execute function private.set_updated_at();

alter table public.categories enable row level security;

create policy categories_select_member
on public.categories
for select
to authenticated
using ((select private.is_member()));

create policy categories_insert_admin
on public.categories
for insert
to authenticated
with check ((select private.is_admin()));

create policy categories_update_admin
on public.categories
for update
to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy categories_delete_admin
on public.categories
for delete
to authenticated
using ((select private.is_admin()));

create policy categories_select_agent
on public.categories
for select
to agent_writer
using (true);

revoke all on table public.categories from public, anon;
grant select, insert, update, delete on table public.categories to authenticated;
grant select, insert, update, delete on table public.categories to service_role;
grant select on table public.categories to agent_writer;

insert into public.categories (slug, name, sort_order)
values
  ('babysitters', 'Babysitters', 10),
  ('plumbers', 'Plumbers', 20),
  ('landscapers', 'Landscapers', 30),
  ('snow-removal', 'Snow removal', 40),
  ('roofers', 'Roofers', 50),
  ('appliance-support', 'Appliance support', 60),
  ('handymen', 'Handymen', 70),
  ('utilities', 'Utilities', 80),
  ('services', 'Services', 90),
  ('hobbies', 'Hobbies', 100),
  ('restaurants', 'Restaurants', 110),
  ('kid-activities', 'Kid activities', 120);
