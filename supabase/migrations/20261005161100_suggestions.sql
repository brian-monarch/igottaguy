-- AI output waits here. Agents insert status pending and a short reason.
-- An admin approves or rejects. Approval records the decision and an audit row.
-- It does not copy payload into community tables. There is no DELETE policy.

create type public.suggestion_status as enum ('pending', 'approved', 'rejected');
create type public.suggestion_kind as enum (
  'freshness',
  'alternative',
  'duplicate',
  'external_review',
  'other'
);

create table public.suggestions (
  id uuid primary key default gen_random_uuid(),
  status public.suggestion_status not null default 'pending',
  kind public.suggestion_kind not null,
  reason text not null,
  contact_id uuid references public.contacts (id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  reviewed_by uuid references public.members (id) on delete restrict,
  reviewed_at timestamptz,
  decision_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint suggestions_reason_len check (
    char_length(btrim(reason)) between 1 and 280
    and reason = btrim(reason)
  ),
  constraint suggestions_payload_object check (
    jsonb_typeof(payload) = 'object'
    and octet_length(payload::text) <= 16000
  ),
  constraint suggestions_review_pair check (
    (
      status = 'pending'
      and reviewed_by is null
      and reviewed_at is null
    )
    or (
      status <> 'pending'
      and reviewed_by is not null
      and reviewed_at is not null
    )
  ),
  constraint suggestions_note_len check (
    decision_note is null
    or (
      char_length(btrim(decision_note)) between 1 and 2000
      and decision_note = btrim(decision_note)
    )
  )
);

comment on table public.suggestions is
  'Pending AI output. Approval does not publish payload into community tables.';

create index suggestions_status_idx on public.suggestions (status, created_at);
create index suggestions_contact_id_idx on public.suggestions (contact_id);

create or replace function private.suggestions_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending' or new.reviewed_by is not null or new.reviewed_at is not null then
      raise exception 'suggestions are created pending';
    end if;
    if coalesce((select auth.role()), '') = 'authenticated' then
      raise exception 'members cannot create suggestions';
    end if;
    return new;
  end if;

  if new.contact_id is null
     and old.contact_id is not null
     and (to_jsonb(new) - 'contact_id' - 'updated_at')
       is not distinct from
       (to_jsonb(old) - 'contact_id' - 'updated_at')
  then
    return new;
  end if;

  if coalesce((select auth.role()), '') <> 'authenticated' or not private.is_admin() then
    raise exception 'only an admin can review a suggestion';
  end if;

  if old.status <> 'pending' or new.status not in ('approved', 'rejected') then
    raise exception 'invalid suggestion transition';
  end if;

  if (to_jsonb(new) - 'status' - 'reviewed_at' - 'reviewed_by' - 'decision_note' - 'updated_at')
     is distinct from
     (to_jsonb(old) - 'status' - 'reviewed_at' - 'reviewed_by' - 'decision_note' - 'updated_at')
  then
    raise exception 'only the review fields can change';
  end if;

  new.reviewed_by := (select auth.uid());
  new.reviewed_at := now();
  return new;
end;
$$;

create or replace function private.audit_suggestion_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform private.write_audit(
      null,
      'agent',
      'suggestion.created',
      'suggestions',
      new.id,
      jsonb_build_object('kind', new.kind::text)
    );
    return new;
  end if;

  if new.status is distinct from old.status and new.status in ('approved', 'rejected') then
    perform private.write_audit(
      (select auth.uid()),
      'admin',
      'suggestion.reviewed',
      'suggestions',
      new.id,
      jsonb_build_object('status', new.status::text, 'kind', new.kind::text)
    );
  end if;

  return new;
end;
$$;

revoke all on function private.suggestions_before_write() from public, anon, authenticated;
revoke all on function private.audit_suggestion_write() from public, anon, authenticated;
grant execute on function private.suggestions_before_write() to authenticated, service_role, agent_writer;
grant execute on function private.audit_suggestion_write() to authenticated, service_role, agent_writer;

create trigger trg_a_suggestions_set_updated_at
before update on public.suggestions
for each row
execute function private.set_updated_at();

create trigger trg_z_suggestions_write
before insert or update on public.suggestions
for each row
execute function private.suggestions_before_write();

create trigger trg_suggestions_audit
after insert or update on public.suggestions
for each row
execute function private.audit_suggestion_write();

create trigger trg_suggestions_immutable
before delete on public.suggestions
for each row
execute function private.prevent_mutation();

alter table public.suggestions enable row level security;

create policy suggestions_select_admin
on public.suggestions
for select
to authenticated
using ((select private.is_admin()));

create policy suggestions_insert_agent
on public.suggestions
for insert
to agent_writer
with check (
  status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and char_length(btrim(reason)) between 1 and 280
);

create policy suggestions_update_admin
on public.suggestions
for update
to authenticated
using (
  (select private.is_admin())
  and status = 'pending'
)
with check (
  (select private.is_admin())
  and status in ('approved', 'rejected')
);

-- No DELETE policy: suggestion history stays.

revoke all on table public.suggestions from public, anon;
grant select, update on table public.suggestions to authenticated;
grant select, insert, update, delete on table public.suggestions to service_role;
grant insert on table public.suggestions to agent_writer;
