-- Members, roles, and private helpers.
-- A member row is the directory identity (PRD: member). id matches auth.users.
-- There is no INSERT policy: accept_invitation() (security definer) creates rows
-- after a valid invite, and the service role inserts the first admin.
-- There is no DELETE policy: administrators remove a member by setting removed_at.
-- Schema private is for triggers and helpers. Do not add it to api.schemas.

create schema if not exists private;

revoke all on schema private from public;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'agent_writer') then
    create role agent_writer nologin noinherit;
  end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role, agent_writer;
grant usage on schema private to authenticated, service_role, agent_writer;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticator') then
    grant agent_writer to authenticator;
  end if;
end
$$;

create type public.member_role as enum ('member', 'admin');

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function private.set_updated_at() from public, anon, authenticated;
grant execute on function private.set_updated_at() to authenticated, service_role, agent_writer;

create table public.members (
  id uuid primary key references auth.users (id) on delete restrict,
  display_name text not null,
  avatar_url text,
  role public.member_role not null default 'member',
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint members_display_name_len check (
    char_length(display_name) between 1 and 80
    and display_name = btrim(display_name)
  ),
  constraint members_avatar_url_https check (
    avatar_url is null
    or (
      char_length(avatar_url) between 12 and 500
      and avatar_url ~ '^https://[^[:space:]]+$'
    )
  )
);

comment on table public.members is
  'Directory member. Contributor identity is display_name, visible only to members. Email stays in auth.';

create or replace function private.is_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.members
    where id = (select auth.uid())
      and removed_at is null
  );
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.members
    where id = (select auth.uid())
      and role = 'admin'
      and removed_at is null
  );
$$;

revoke all on function private.is_member() from public, anon, authenticated;
revoke all on function private.is_admin() from public, anon, authenticated;
grant execute on function private.is_member() to authenticated, service_role, agent_writer;
grant execute on function private.is_admin() to authenticated, service_role, agent_writer;

create or replace function private.enforce_member_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- accept_invitation() is security definer, so this nested trigger sees the owner.
  -- service_role and SQL bootstrap (postgres) may insert the first admin.
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;
  raise exception 'members are created by accepting an invitation';
end;
$$;

create or replace function private.enforce_member_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if new.id is distinct from old.id
     or new.created_at is distinct from old.created_at
  then
    raise exception 'member identity is immutable';
  end if;

  if coalesce((select auth.role()), '') = 'service_role'
     or (
       coalesce((select auth.role()), '') = ''
       and current_user in ('postgres', 'supabase_admin', 'service_role')
     )
  then
    return new;
  end if;

  if coalesce((select auth.role()), '') <> 'authenticated' or uid is null then
    raise exception 'not allowed';
  end if;

  if (old.role = 'admin' and old.removed_at is null)
     and (new.role is distinct from 'admin' or new.removed_at is not null)
     and not exists (
       select 1
       from public.members
       where role = 'admin'
         and removed_at is null
         and id <> old.id
     )
  then
    raise exception 'cannot remove or demote the last admin';
  end if;

  if private.is_admin()
     and (
       new.role is distinct from old.role
       or new.removed_at is distinct from old.removed_at
     )
  then
    if (to_jsonb(new) - 'role' - 'removed_at' - 'updated_at')
       is distinct from
       (to_jsonb(old) - 'role' - 'removed_at' - 'updated_at')
    then
      raise exception 'admins may only change role or membership status';
    end if;
    return new;
  end if;

  if old.id = uid and private.is_member() then
    if new.role is distinct from old.role
       or new.removed_at is distinct from old.removed_at
    then
      raise exception 'members cannot change role or membership status';
    end if;
    return new;
  end if;

  raise exception 'members may only edit their own profile';
end;
$$;

create or replace function private.prevent_member_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return old;
  end if;
  raise exception 'remove members by setting removed_at';
end;
$$;

revoke all on function private.enforce_member_insert() from public, anon, authenticated;
revoke all on function private.enforce_member_update() from public, anon, authenticated;
revoke all on function private.prevent_member_delete() from public, anon, authenticated;
grant execute on function private.enforce_member_insert() to authenticated, service_role;
grant execute on function private.enforce_member_update() to authenticated, service_role;
grant execute on function private.prevent_member_delete() to authenticated, service_role;

create trigger trg_members_insert
before insert on public.members
for each row
execute function private.enforce_member_insert();

create trigger trg_a_members_set_updated_at
before update on public.members
for each row
execute function private.set_updated_at();

create trigger trg_z_members_update
before update on public.members
for each row
execute function private.enforce_member_update();

create trigger trg_members_delete
before delete on public.members
for each row
execute function private.prevent_member_delete();

alter table public.members enable row level security;

-- SELECT: any current member can see contributor names. Anon has no grant.
create policy members_select_member
on public.members
for select
to authenticated
using ((select private.is_member()));

-- UPDATE self: profile fields only. The trigger rejects role and removed_at.
create policy members_update_self
on public.members
for update
to authenticated
using (
  id = (select auth.uid())
  and (select private.is_member())
)
with check (id = (select auth.uid()));

-- UPDATE admin: role and removed_at only. The trigger rejects profile edits.
create policy members_update_admin
on public.members
for update
to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- No INSERT policy: see file header.
-- No DELETE policy: removal is removed_at.

revoke all on table public.members from public, anon;
grant select, update on table public.members to authenticated;
grant select, insert, update, delete on table public.members to service_role;
