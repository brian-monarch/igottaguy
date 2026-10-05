-- Rating and written review share one row: one per member per contact.
-- The 1-5 scale is an assumption; the PRD does not fix a scale or split the two.
-- At least a rating or a written review is required. Price stays on price_entries.

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references public.contacts (id) on delete cascade,
  author_id uuid not null references public.members (id) on delete restrict,
  rating smallint,
  body text,
  hidden_at timestamptz,
  hidden_by uuid references public.members (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reviews_one_author unique (contact_id, author_id),
  constraint reviews_rating_scale check (rating is null or rating between 1 and 5),
  constraint reviews_body_len check (
    body is null
    or (
      char_length(btrim(body)) between 1 and 4000
      and body = btrim(body)
    )
  ),
  constraint reviews_rating_or_body check (rating is not null or body is not null),
  constraint reviews_hidden_pair check (
    (hidden_at is null and hidden_by is null)
    or (hidden_at is not null and hidden_by is not null)
  )
);

comment on table public.reviews is
  'One rating and/or written review per member per contact. Rating is 1 through 5.';

create index reviews_author_id_idx on public.reviews (author_id);

create trigger trg_a_reviews_set_updated_at
before update on public.reviews
for each row
execute function private.set_updated_at();

create trigger trg_z_reviews_write
before insert or update or delete on public.reviews
for each row
execute function private.enforce_content_write();

alter table public.reviews enable row level security;

create policy reviews_select_visible
on public.reviews
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

create policy reviews_insert_member
on public.reviews
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

create policy reviews_update_author_or_admin
on public.reviews
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

create policy reviews_delete_author_or_admin
on public.reviews
for delete
to authenticated
using (
  (select private.is_member())
  and (
    author_id = (select auth.uid())
    or (select private.is_admin())
  )
);

revoke all on table public.reviews from public, anon;
grant select, insert, update, delete on table public.reviews to authenticated;
grant select, insert, update, delete on table public.reviews to service_role;

-- Proposed PRD aggregate. security_invoker keeps review RLS in force.
create view public.contact_rating_summaries
with (security_invoker = true) as
select
  reviews.contact_id,
  count(reviews.rating) as rating_count,
  round(avg(reviews.rating), 2) as average_rating,
  count(reviews.body) as review_count
from public.reviews
where reviews.hidden_at is null
  and private.contact_is_visible(reviews.contact_id)
group by reviews.contact_id;

comment on view public.contact_rating_summaries is
  'Visible rating average and counts. Hidden reviews and hidden contacts are excluded.';

revoke all on table public.contact_rating_summaries from public, anon;
grant select on table public.contact_rating_summaries to authenticated, service_role;
