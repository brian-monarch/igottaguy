-- Referrals. One member referral per contact. referrer_label is only for
-- imported household names ("Monarch's") that are not member accounts yet.
-- Members cannot set that label. Live publication, author edit, admin hide.

create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references public.contacts (id) on delete cascade,
  author_id uuid not null references public.members (id) on delete restrict,
  body text not null,
  referrer_label text,
  hidden_at timestamptz,
  hidden_by uuid references public.members (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referrals_body_len check (
    char_length(btrim(body)) between 1 and 4000
    and body = btrim(body)
  ),
  constraint referrals_label_len check (
    referrer_label is null
    or (
      char_length(referrer_label) between 1 and 120
      and referrer_label = btrim(referrer_label)
    )
  ),
  constraint referrals_hidden_pair check (
    (hidden_at is null and hidden_by is null)
    or (hidden_at is not null and hidden_by is not null)
  )
);

comment on table public.referrals is
  'A member recommendation. referrer_label preserves a sheet household until that neighbor joins.';
comment on column public.referrals.referrer_label is
  'Import-only household label. Authenticated members cannot set or change it.';

create unique index referrals_one_member_per_contact
on public.referrals (contact_id, author_id)
where referrer_label is null;

create unique index referrals_one_label_per_contact
on public.referrals (contact_id, lower(referrer_label))
where referrer_label is not null;

create index referrals_author_id_idx on public.referrals (author_id);

create trigger trg_a_referrals_set_updated_at
before update on public.referrals
for each row
execute function private.set_updated_at();

create trigger trg_z_referrals_write
before insert or update or delete on public.referrals
for each row
execute function private.enforce_content_write();

alter table public.referrals enable row level security;

create policy referrals_select_visible
on public.referrals
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

create policy referrals_insert_member
on public.referrals
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

create policy referrals_update_author_or_admin
on public.referrals
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

create policy referrals_delete_author_or_admin
on public.referrals
for delete
to authenticated
using (
  (select private.is_member())
  and (
    author_id = (select auth.uid())
    or (select private.is_admin())
  )
);

revoke all on table public.referrals from public, anon;
grant select, insert, update, delete on table public.referrals to authenticated;
grant select, insert, update, delete on table public.referrals to service_role;
