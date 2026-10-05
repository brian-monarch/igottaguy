-- Append-only audit. Admin and agent actions are recorded here.
-- Metadata must not carry phone numbers, emails, review text, or tokens.
-- There is no UPDATE or DELETE policy. A trigger rejects both.

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.members (id) on delete restrict,
  actor_role text not null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint audit_log_actor_role_known check (actor_role in ('admin', 'agent', 'system')),
  constraint audit_log_admin_has_actor check (actor_role <> 'admin' or actor_id is not null),
  constraint audit_log_agent_has_no_member check (actor_role <> 'agent' or actor_id is null),
  constraint audit_log_action_shape check (
    action ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]+)+$'
  ),
  constraint audit_log_entity_type_shape check (entity_type ~ '^[a-z][a-z0-9_]{0,63}$'),
  constraint audit_log_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint audit_log_metadata_private check (
    not (
      metadata ?| array[
        'phone',
        'email',
        'body',
        'review',
        'review_text',
        'price_text',
        'token',
        'website',
        'avatar_url'
      ]
    )
  )
);

comment on table public.audit_log is
  'Append-only record of admin and agent actions. Do not store phone, email, or review text.';

create index audit_log_entity_idx
on public.audit_log (entity_type, entity_id, created_at desc);

create or replace function private.audit_log_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'audit_log is append-only';
  end if;
  return new;
end;
$$;

create or replace function private.write_audit(
  p_actor_id uuid,
  p_actor_role text,
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_metadata jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_log (actor_id, actor_role, action, entity_type, entity_id, metadata)
  values (
    p_actor_id,
    p_actor_role,
    p_action,
    p_entity_type,
    p_entity_id,
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

create or replace function private.audit_content_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_id uuid;
  next_action text;
begin
  if not private.is_admin() then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    row_id := old.id;
    next_action := 'content.removed';
  elsif new.hidden_at is distinct from old.hidden_at then
    row_id := new.id;
    next_action := case
      when new.hidden_at is null then 'content.restored'
      else 'content.hidden'
    end;
  else
    return new;
  end if;

  perform private.write_audit(
    (select auth.uid()),
    'admin',
    next_action,
    tg_table_name,
    row_id,
    '{}'::jsonb
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.audit_log_guard() from public, anon, authenticated;
revoke all on function private.write_audit(uuid, text, text, text, uuid, jsonb) from public, anon, authenticated;
revoke all on function private.audit_content_moderation() from public, anon, authenticated;
grant execute on function private.audit_log_guard() to authenticated, service_role, agent_writer;
grant execute on function private.audit_content_moderation() to authenticated, service_role;

create trigger trg_audit_log_guard
before insert or update or delete on public.audit_log
for each row
execute function private.audit_log_guard();

create trigger trg_contacts_audit
after update or delete on public.contacts
for each row
execute function private.audit_content_moderation();

create trigger trg_referrals_audit
after update or delete on public.referrals
for each row
execute function private.audit_content_moderation();

create trigger trg_reviews_audit
after update or delete on public.reviews
for each row
execute function private.audit_content_moderation();

create trigger trg_price_entries_audit
after update or delete on public.price_entries
for each row
execute function private.audit_content_moderation();

alter table public.audit_log enable row level security;

create policy audit_log_select_admin
on public.audit_log
for select
to authenticated
using ((select private.is_admin()));

-- Agents may record their own actions. Triggers insert the rest as the owner.
create policy audit_log_insert_agent
on public.audit_log
for insert
to agent_writer
with check (
  actor_id is null
  and actor_role = 'agent'
  and action ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]+)+$'
);

-- No UPDATE policy: append-only.
-- No DELETE policy: append-only.

revoke all on table public.audit_log from public, anon;
grant select on table public.audit_log to authenticated;
grant select, insert, update, delete on table public.audit_log to service_role;
grant insert on table public.audit_log to agent_writer;
