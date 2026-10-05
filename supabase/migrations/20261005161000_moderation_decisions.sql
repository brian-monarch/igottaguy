-- One admin decision per report. The insert applies hide, remove, or dismiss
-- and writes an audit row. Decisions are immutable.
-- There is no UPDATE or DELETE policy.

create type public.moderation_action as enum ('hide', 'remove', 'dismiss');

create table public.moderation_decisions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null unique references public.reports (id) on delete restrict,
  admin_id uuid not null references public.members (id) on delete restrict,
  decision public.moderation_action not null,
  note text,
  created_at timestamptz not null default now(),
  constraint moderation_decisions_note_len check (
    note is null
    or (
      char_length(note) between 1 and 2000
      and note = btrim(note)
    )
  )
);

comment on table public.moderation_decisions is
  'Admin outcome for a flag: hide, remove, or dismiss. The note stays off the audit log.';

create or replace function private.prevent_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'this record is append-only';
end;
$$;

create or replace function private.apply_moderation_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  report public.reports%rowtype;
begin
  if (select auth.uid()) is null
     or not private.is_admin()
     or new.admin_id is distinct from (select auth.uid())
  then
    raise exception 'only an admin can record a moderation decision';
  end if;

  select *
  into report
  from public.reports
  where id = new.report_id
  for update;

  if not found or report.status <> 'open' then
    raise exception 'report is not open';
  end if;

  update public.reports
  set status = case
    when new.decision = 'dismiss' then 'dismissed'::public.report_status
    else 'resolved'::public.report_status
  end
  where id = report.id;

  if new.decision = 'hide' then
    if report.target_type = 'contact' then
      update public.contacts set hidden_at = now() where id = report.target_id;
    elsif report.target_type = 'referral' then
      update public.referrals set hidden_at = now() where id = report.target_id;
    elsif report.target_type = 'review' then
      update public.reviews set hidden_at = now() where id = report.target_id;
    elsif report.target_type = 'price_entry' then
      update public.price_entries set hidden_at = now() where id = report.target_id;
    end if;
  elsif new.decision = 'remove' then
    if report.target_type = 'contact' then
      delete from public.contacts where id = report.target_id;
    elsif report.target_type = 'referral' then
      delete from public.referrals where id = report.target_id;
    elsif report.target_type = 'review' then
      delete from public.reviews where id = report.target_id;
    elsif report.target_type = 'price_entry' then
      delete from public.price_entries where id = report.target_id;
    end if;
  end if;

  perform private.write_audit(
    (select auth.uid()),
    'admin',
    'moderation.decision',
    'moderation_decisions',
    new.id,
    jsonb_build_object(
      'decision', new.decision::text,
      'report_id', new.report_id,
      'target_type', report.target_type::text,
      'target_id', report.target_id
    )
  );

  return new;
end;
$$;

revoke all on function private.prevent_mutation() from public, anon, authenticated;
revoke all on function private.apply_moderation_decision() from public, anon, authenticated;
grant execute on function private.prevent_mutation() to authenticated, service_role, agent_writer;
grant execute on function private.apply_moderation_decision() to authenticated, service_role;

create trigger trg_moderation_decisions_apply
after insert on public.moderation_decisions
for each row
execute function private.apply_moderation_decision();

create trigger trg_moderation_decisions_immutable
before update or delete on public.moderation_decisions
for each row
execute function private.prevent_mutation();

alter table public.moderation_decisions enable row level security;

create policy moderation_decisions_select_admin
on public.moderation_decisions
for select
to authenticated
using ((select private.is_admin()));

create policy moderation_decisions_insert_admin
on public.moderation_decisions
for insert
to authenticated
with check (
  (select private.is_admin())
  and admin_id = (select auth.uid())
);

-- No UPDATE policy: a decision is final.
-- No DELETE policy: a decision is final.

revoke all on table public.moderation_decisions from public, anon;
grant select, insert on table public.moderation_decisions to authenticated;
grant select, insert, update, delete on table public.moderation_decisions to service_role;
