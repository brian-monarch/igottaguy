-- Invitations. Admins create them. The invited person accepts after signing in
-- with the invited email. Anon cannot read the table; the public invite page
-- calls invitation_preview(token), which returns one pending invite or no row.
-- There is no DELETE policy: an admin revokes by setting status to revoked.

create schema if not exists extensions;

create extension if not exists pgcrypto with schema extensions;

create type public.invitation_status as enum ('pending', 'accepted', 'revoked');

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  token text not null unique,
  role public.member_role not null default 'member',
  status public.invitation_status not null default 'pending',
  invited_by uuid not null references public.members (id) on delete restrict,
  accepted_by uuid references public.members (id) on delete restrict,
  expires_at timestamptz not null default (now() + interval '14 days'),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint invitations_email_shape check (
    email = lower(email)
    and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  constraint invitations_token_len check (char_length(token) >= 32),
  constraint invitations_expiry_after_create check (expires_at > created_at),
  constraint invitations_acceptance_pair check (
    (
      status = 'accepted'
      and accepted_by is not null
      and accepted_at is not null
    )
    or (
      status <> 'accepted'
      and accepted_by is null
      and accepted_at is null
    )
  )
);

comment on table public.invitations is
  'Invite-only membership. Pending email is unique. Default expiry is 14 days, which the PRD does not specify.';

create unique index invitations_one_pending_email
on public.invitations (email)
where status = 'pending';

create index invitations_invited_by_idx
on public.invitations (invited_by);

create or replace function private.invitations_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.email := lower(btrim(new.email));

  if tg_op = 'INSERT' then
    new.token := encode(extensions.gen_random_bytes(32), 'hex');
    new.accepted_by := null;
    new.accepted_at := null;
    new.status := 'pending';
    if (select auth.uid()) is not null then
      new.invited_by := (select auth.uid());
    end if;
    return new;
  end if;

  if new.id is distinct from old.id
     or new.token is distinct from old.token
     or new.invited_by is distinct from old.invited_by
     or new.created_at is distinct from old.created_at
  then
    raise exception 'invitation identity fields are immutable';
  end if;

  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    if (to_jsonb(new) - 'status' - 'accepted_by' - 'accepted_at' - 'updated_at')
       is distinct from
       (to_jsonb(old) - 'status' - 'accepted_by' - 'accepted_at' - 'updated_at')
    then
      raise exception 'acceptance cannot change invitation terms';
    end if;
    if new.accepted_by is distinct from (select auth.uid())
       or new.email <> lower(btrim(coalesce((select auth.jwt()) ->> 'email', '')))
       or old.status <> 'pending'
       or old.expires_at <= now()
    then
      raise exception 'invitation not found';
    end if;
    return new;
  end if;

  if not private.is_admin() then
    raise exception 'only an admin can change an invitation';
  end if;

  if old.status <> 'pending' then
    raise exception 'closed invitations cannot be changed';
  end if;

  if new.accepted_by is not null or new.accepted_at is not null or new.status = 'accepted' then
    raise exception 'acceptance is recorded by accept_invitation';
  end if;

  return new;
end;
$$;

revoke all on function private.invitations_before_write() from public, anon, authenticated;
grant execute on function private.invitations_before_write() to authenticated, service_role;

create trigger trg_a_invitations_set_updated_at
before update on public.invitations
for each row
execute function private.set_updated_at();

create trigger trg_z_invitations_write
before insert or update on public.invitations
for each row
execute function private.invitations_before_write();

alter table public.invitations enable row level security;

-- SELECT: admins see the queue. The invited account sees only its own email.
create policy invitations_select_admin_or_invitee
on public.invitations
for select
to authenticated
using (
  (select private.is_admin())
  or (
    email = lower(btrim(coalesce((select auth.jwt()) ->> 'email', '')))
    and email <> ''
  )
);

-- INSERT: administrators only. invited_by is forced to the caller.
create policy invitations_insert_admin
on public.invitations
for insert
to authenticated
with check (
  (select private.is_admin())
  and invited_by = (select auth.uid())
  and status = 'pending'
  and accepted_by is null
);

-- UPDATE: administrators revoke or correct a pending invite.
-- Acceptance is checked in the trigger against the caller email.
create policy invitations_update_admin
on public.invitations
for update
to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- No DELETE policy: revoke through status.

revoke all on table public.invitations from public, anon;
grant select, insert, update on table public.invitations to authenticated;
grant select, insert, update, delete on table public.invitations to service_role;

create or replace function public.invitation_preview(invite_token text)
returns table (
  email text,
  expires_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select i.email, i.expires_at
  from public.invitations i
  where i.token = invite_token
    and i.status = 'pending'
    and i.expires_at > now()
    and char_length(coalesce(invite_token, '')) >= 32
$$;

comment on function public.invitation_preview(text) is
  'Public invite page. Returns nothing for unknown, expired, or revoked tokens.';

create or replace function public.accept_invitation(invite_token text, display_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite public.invitations%rowtype;
  caller uuid := (select auth.uid());
  caller_email text := lower(btrim(coalesce((select auth.jwt()) ->> 'email', '')));
  clean_name text := btrim(display_name);
begin
  if caller is null or caller_email = '' then
    raise exception 'authentication required';
  end if;

  if clean_name is null or char_length(clean_name) < 1 or char_length(clean_name) > 80 then
    raise exception 'display name is required';
  end if;

  if exists (select 1 from public.members m where m.id = caller) then
    raise exception 'member profile already exists';
  end if;

  select *
  into invite
  from public.invitations
  where token = invite_token
    and status = 'pending'
    and expires_at > now()
    and email = caller_email
  for update;

  if not found then
    raise exception 'invitation not found';
  end if;

  insert into public.members (id, display_name, role)
  values (caller, clean_name, invite.role);

  update public.invitations
  set
    status = 'accepted',
    accepted_by = caller,
    accepted_at = now()
  where id = invite.id;

  return caller;
end;
$$;

comment on function public.accept_invitation(text, text) is
  'Creates the member row for the signed-in invited email and marks the invite accepted.';

revoke all on function public.invitation_preview(text) from public;
revoke all on function public.accept_invitation(text, text) from public;
grant execute on function public.invitation_preview(text) to anon, authenticated, service_role;
grant execute on function public.accept_invitation(text, text) to authenticated, service_role;
