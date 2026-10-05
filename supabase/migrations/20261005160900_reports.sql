-- Member flags. Queue: report, then optional agent triage, then an admin decision.
-- Triage only orders the queue. It cannot change status.
-- There is no DELETE policy and no authenticated UPDATE policy.
-- Status changes happen only inside apply_moderation_decision().

create type public.report_target as enum ('contact', 'referral', 'review', 'price_entry');
create type public.report_reason as enum (
  'incorrect',
  'inappropriate',
  'obsolete',
  'duplicate',
  'other'
);
create type public.report_status as enum ('open', 'resolved', 'dismissed');
create type public.triage_label as enum (
  'likely_fine',
  'needs_a_look',
  'possible_sensitive_personal_info'
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.members (id) on delete restrict,
  target_type public.report_target not null,
  target_id uuid not null,
  reason public.report_reason not null,
  details text,
  status public.report_status not null default 'open',
  triage_label public.triage_label,
  triage_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_details_len check (
    details is null
    or (
      char_length(btrim(details)) between 1 and 2000
      and details = btrim(details)
    )
  ),
  constraint reports_triage_reason_len check (
    triage_reason is null
    or (
      char_length(btrim(triage_reason)) between 1 and 280
      and triage_reason = btrim(triage_reason)
    )
  )
);

comment on table public.reports is
  'A member flag. author_id is the reporter. Duplicate contacts use reason duplicate.';
comment on column public.reports.triage_label is
  'Agent queue order only: likely fine, needs a look, or possible sensitive personal info.';

create index reports_queue_idx
on public.reports (status, created_at);

create unique index reports_one_open_per_member_target
on public.reports (author_id, target_type, target_id)
where status = 'open';

create index reports_target_idx
on public.reports (target_type, target_id);

create or replace function private.reports_target_exists()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  found boolean := false;
begin
  if new.target_type = 'contact' then
    select exists (select 1 from public.contacts where id = new.target_id) into found;
  elsif new.target_type = 'referral' then
    select exists (select 1 from public.referrals where id = new.target_id) into found;
  elsif new.target_type = 'review' then
    select exists (select 1 from public.reviews where id = new.target_id) into found;
  elsif new.target_type = 'price_entry' then
    select exists (select 1 from public.price_entries where id = new.target_id) into found;
  end if;

  if not coalesce(found, false) then
    raise exception 'reported item was not found';
  end if;

  return new;
end;
$$;

create or replace function private.enforce_report_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce((select auth.role()), '') = 'agent_writer'
     or current_user = 'agent_writer'
  then
    if old.status <> 'open' or new.status <> 'open' then
      raise exception 'triage may only order an open report';
    end if;
    if (to_jsonb(new) - 'triage_label' - 'triage_reason' - 'updated_at')
       is distinct from
       (to_jsonb(old) - 'triage_label' - 'triage_reason' - 'updated_at')
    then
      raise exception 'triage may only order the queue';
    end if;
    return new;
  end if;

  if current_user in ('postgres', 'supabase_admin') then
    if old.status <> 'open' or new.status not in ('resolved', 'dismissed') then
      raise exception 'invalid report status transition';
    end if;
    if (to_jsonb(new) - 'status' - 'updated_at')
       is distinct from
       (to_jsonb(old) - 'status' - 'updated_at')
    then
      raise exception 'moderation may only change report status';
    end if;
    return new;
  end if;

  raise exception 'reports are updated only by triage or an admin decision';
end;
$$;

create or replace function private.audit_report_triage()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce((select auth.role()), '') = 'agent_writer'
     or current_user = 'agent_writer'
  then
    perform private.write_audit(
      null,
      'agent',
      'report.triaged',
      'reports',
      new.id,
      jsonb_build_object('triage_label', new.triage_label::text)
    );
  end if;
  return new;
end;
$$;

revoke all on function private.reports_target_exists() from public, anon, authenticated;
revoke all on function private.enforce_report_update() from public, anon, authenticated;
revoke all on function private.audit_report_triage() from public, anon, authenticated;
grant execute on function private.reports_target_exists() to authenticated, service_role;
grant execute on function private.enforce_report_update() to authenticated, service_role, agent_writer;
grant execute on function private.audit_report_triage() to authenticated, service_role, agent_writer;

create trigger trg_reports_target
before insert on public.reports
for each row
execute function private.reports_target_exists();

create trigger trg_a_reports_set_updated_at
before update on public.reports
for each row
execute function private.set_updated_at();

create trigger trg_z_reports_update
before update on public.reports
for each row
execute function private.enforce_report_update();

create trigger trg_reports_triage_audit
after update on public.reports
for each row
execute function private.audit_report_triage();

alter table public.reports enable row level security;

create policy reports_select_author_or_admin
on public.reports
for select
to authenticated
using (
  author_id = (select auth.uid())
  or (select private.is_admin())
);

create policy reports_insert_member
on public.reports
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and author_id = (select auth.uid())
  and (select private.is_member())
  and status = 'open'
  and triage_label is null
  and triage_reason is null
);

create policy reports_select_agent
on public.reports
for select
to agent_writer
using (true);

create policy reports_update_agent_triage
on public.reports
for update
to agent_writer
using (status = 'open')
with check (status = 'open');

-- No authenticated UPDATE policy: status changes only in the moderation trigger.
-- No DELETE policy: flags stay with the decision.

revoke all on table public.reports from public, anon;
grant select, insert on table public.reports to authenticated;
grant select, insert, update, delete on table public.reports to service_role;
grant select, update (triage_label, triage_reason, updated_at) on table public.reports to agent_writer;
