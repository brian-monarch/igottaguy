-- RLS coverage for the directory schema.
-- Run with: supabase test db
-- The required case is member B failing to edit member A's review.

begin;

create extension if not exists pgtap with schema extensions;

grant usage on schema extensions to anon, authenticated, agent_writer;
grant execute on all functions in schema extensions to anon, authenticated, agent_writer;

select set_config('search_path', 'extensions, public, private', true);

create temp table fixture (
  key text primary key,
  id uuid
);

create temp table secrets (
  key text primary key,
  value text
);

grant all on fixture to anon, authenticated, agent_writer;
grant all on secrets to anon, authenticated, agent_writer;

create or replace function pg_temp.assume(p_uid uuid, p_email text, p_role text)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_uid::text, 'role', p_role, 'email', p_email)::text,
    true
  );
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  perform set_config('request.jwt.claim.role', p_role, true);
  execute format('set local role %I', p_role);
end;
$$;

-- Fills whatever auth.users requires, so the same test runs on the local stub
-- and on a full Supabase auth schema.
create or replace function pg_temp.create_auth_user(p_id uuid, p_email text)
returns void
language plpgsql
as $$
declare
  col record;
  col_list text := '';
  val_list text := '';
  expr text;
begin
  for col in
    select column_name, data_type, is_nullable, column_default, is_generated
    from information_schema.columns
    where table_schema = 'auth'
      and table_name = 'users'
      and is_generated = 'NEVER'
    order by ordinal_position
  loop
    if col.column_name = 'id' then
      expr := quote_literal(p_id);
    elsif col.column_name = 'email' then
      expr := quote_literal(p_email);
    elsif col.column_name in ('aud', 'role') then
      expr := quote_literal('authenticated');
    elsif col.column_name = 'instance_id' then
      expr := quote_literal('00000000-0000-0000-0000-000000000000');
    elsif col.column_name in ('raw_app_meta_data', 'raw_user_meta_data') then
      expr := quote_literal('{"provider":"email","providers":["email"]}') || '::jsonb';
    elsif col.column_name in ('created_at', 'updated_at', 'email_confirmed_at') then
      expr := 'now()';
    elsif col.is_nullable = 'YES' or col.column_default is not null then
      continue;
    elsif col.data_type in ('text', 'character varying') then
      expr := quote_literal('');
    elsif col.data_type = 'boolean' then
      expr := 'false';
    elsif col.data_type = 'jsonb' then
      expr := '''{}''::jsonb';
    elsif col.data_type = 'uuid' then
      expr := quote_literal('00000000-0000-0000-0000-000000000000');
    elsif col.data_type in ('integer', 'smallint', 'bigint', 'numeric') then
      expr := '0';
    else
      continue;
    end if;

    col_list := col_list || quote_ident(col.column_name) || ',';
    val_list := val_list || expr || ',';
  end loop;

  execute 'insert into auth.users (' || rtrim(col_list, ',') || ') values (' || rtrim(val_list, ',') || ')';
end;
$$;

select pg_temp.create_auth_user('00000000-0000-0000-0000-0000000000a1', 'admin@example.com');
select pg_temp.create_auth_user('00000000-0000-0000-0000-0000000000a2', 'ada@example.com');
select pg_temp.create_auth_user('00000000-0000-0000-0000-0000000000b3', 'ben@example.com');
select pg_temp.create_auth_user('00000000-0000-0000-0000-0000000000c4', 'outsider@example.com');
select pg_temp.create_auth_user('00000000-0000-0000-0000-0000000000d5', 'new@example.com');

insert into public.members (id, display_name, role)
values
  ('00000000-0000-0000-0000-0000000000a1', 'Admin', 'admin'),
  ('00000000-0000-0000-0000-0000000000a2', 'Ada', 'member'),
  ('00000000-0000-0000-0000-0000000000b3', 'Ben', 'member');

insert into fixture (key, id)
values
  ('admin', '00000000-0000-0000-0000-0000000000a1'),
  ('ada', '00000000-0000-0000-0000-0000000000a2'),
  ('ben', '00000000-0000-0000-0000-0000000000b3'),
  ('outsider', '00000000-0000-0000-0000-0000000000c4'),
  ('new', '00000000-0000-0000-0000-0000000000d5'),
  ('category', (select id from public.categories where slug = 'plumbers'));

select plan(46);

-- Anonymous and non-members cannot read the directory.
select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000c4',
  'outsider@example.com',
  'anon'
);

select throws_ok(
  'select id from public.members',
  '42501',
  null,
  'anon cannot read members'
);

select throws_ok(
  'select id from public.reviews',
  '42501',
  null,
  'anon cannot read reviews'
);

select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000c4',
  'outsider@example.com',
  'authenticated'
);

select is_empty(
  'select id from public.contacts',
  'authenticated user without a member row sees no contacts'
);

select is_empty(
  'select id from public.members',
  'authenticated user without a member row sees no member names'
);

-- Ada publishes a contact, referral, review, and price.
select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000a2',
  'ada@example.com',
  'authenticated'
);

insert into fixture (key, id)
values (
  'contact',
  public.create_contact(
    contact_name => 'Pat Plumber',
    category_ids => array[(select id from fixture where key = 'category')]::uuid[],
    contact_phone => '+16125550100',
    contact_details => '{"trade":"pipes"}'::jsonb
  )
);

with inserted as (
  insert into public.reviews (contact_id, author_id, rating, body)
  values (
    (select id from fixture where key = 'contact'),
    '00000000-0000-0000-0000-0000000000a2',
    5,
    'Showed up on time'
  )
  returning id
)
insert into fixture (key, id)
select 'review', id
from inserted;

select lives_ok(
  $$
  insert into public.referrals (contact_id, author_id, body)
  select id, '00000000-0000-0000-0000-0000000000a2', 'Fixed the kitchen sink'
  from fixture
  where key = 'contact'
  $$,
  'author can add a referral'
);

select lives_ok(
  $$
  insert into public.price_entries (contact_id, author_id, price_text)
  select id, '00000000-0000-0000-0000-0000000000a2', '$150 for the visit'
  from fixture
  where key = 'contact'
  $$,
  'author can add a price entry'
);

-- Ben can read Ada's review and cannot change it.
select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000b3',
  'ben@example.com',
  'authenticated'
);

select is(
  (
    select body
    from public.reviews
    where author_id = '00000000-0000-0000-0000-0000000000a2'
  ),
  'Showed up on time',
  'member Ben can read Ada review'
);

select is_empty(
  $$
  update public.reviews
  set body = 'hacked'
  where author_id = '00000000-0000-0000-0000-0000000000a2'
  returning id
  $$,
  'member Ben cannot edit Ada review'
);

select is_empty(
  $$
  delete from public.reviews
  where author_id = '00000000-0000-0000-0000-0000000000a2'
  returning id
  $$,
  'member Ben cannot delete Ada review'
);

select is_empty(
  $$
  update public.referrals
  set body = 'hacked'
  where author_id = '00000000-0000-0000-0000-0000000000a2'
  returning id
  $$,
  'member Ben cannot edit Ada referral'
);

select is_empty(
  $$
  update public.price_entries
  set price_text = 'free'
  where author_id = '00000000-0000-0000-0000-0000000000a2'
  returning id
  $$,
  'member Ben cannot edit Ada price'
);

select lives_ok(
  $$
  insert into public.reviews (contact_id, author_id, rating, body)
  select id, '00000000-0000-0000-0000-0000000000b3', 4, 'Would call again'
  from fixture
  where key = 'contact'
  $$,
  'Ben can review the same contact'
);

select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000a2',
  'ada@example.com',
  'authenticated'
);

select is_empty(
  $$
  update public.reviews
  set body = 'nope'
  where author_id = '00000000-0000-0000-0000-0000000000b3'
  returning id
  $$,
  'member Ada cannot edit Ben review'
);

select lives_ok(
  $$
  update public.reviews
  set body = 'Showed up on time and explained the bill'
  where author_id = '00000000-0000-0000-0000-0000000000a2'
  $$,
  'Ada can edit her own review'
);

select throws_ok(
  $$
  update public.members
  set role = 'admin'
  where id = '00000000-0000-0000-0000-0000000000a2'
  $$,
  'P0001',
  'members cannot change role or membership status',
  'a member cannot promote themselves'
);

select throws_ok(
  $$
  insert into public.referrals (contact_id, author_id, body, referrer_label)
  select id, '00000000-0000-0000-0000-0000000000a2', 'Neighbor said so', 'Schwartz''s'
  from fixture
  where key = 'contact'
  $$,
  'P0001',
  'referrer_label is only set by import',
  'members cannot set referrer_label'
);

select throws_ok(
  $$
  insert into public.suggestions (kind, reason)
  values ('freshness', 'Website no longer responds')
  $$,
  '42501',
  null,
  'a member cannot insert a suggestion'
);

reset role;

select is(
  (
    select body
    from public.reviews
    where author_id = '00000000-0000-0000-0000-0000000000a2'
  ),
  'Showed up on time and explained the bill',
  'Ada review survived Ben edit attempt'
);

select is(
  (select count(*)::integer from public.reviews),
  2,
  'both reviews are still stored'
);

-- Admin can hide and cannot rewrite.
select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000a1',
  'admin@example.com',
  'authenticated'
);

select throws_ok(
  $$
  update public.reviews
  set body = 'rewritten by admin'
  where author_id = '00000000-0000-0000-0000-0000000000a2'
  $$,
  'P0001',
  'admins may only hide or restore content',
  'admin cannot rewrite another member review'
);

select lives_ok(
  $$
  update public.reviews
  set hidden_at = now()
  where author_id = '00000000-0000-0000-0000-0000000000a2'
  $$,
  'admin can hide a review'
);

select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000b3',
  'ben@example.com',
  'authenticated'
);

select is_empty(
  $$
  select id from public.reviews
  where author_id = '00000000-0000-0000-0000-0000000000a2'
  $$,
  'Ben cannot read a hidden review'
);

select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000a2',
  'ada@example.com',
  'authenticated'
);

select is(
  (select count(*)::integer from public.reviews where author_id = '00000000-0000-0000-0000-0000000000a2'),
  1,
  'author can still read a hidden review'
);

reset role;

select ok(
  exists (
    select 1
    from public.audit_log
    where action = 'content.hidden'
      and entity_type = 'reviews'
      and entity_id = (
        select id from public.reviews
        where author_id = '00000000-0000-0000-0000-0000000000a2'
      )
  ),
  'hiding a review writes an audit row'
);

-- Flag, triage, decision.
select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000b3',
  'ben@example.com',
  'authenticated'
);

insert into fixture (key, id)
select
  'price',
  id
from public.price_entries
where author_id = '00000000-0000-0000-0000-0000000000a2';

select lives_ok(
  $$
  insert into public.reports (author_id, target_type, target_id, reason, details)
  select
    '00000000-0000-0000-0000-0000000000b3',
    'price_entry',
    id,
    'obsolete',
    'The visit fee changed last spring'
  from fixture
  where key = 'price'
  $$,
  'Ben can flag Ada price entry'
);

select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000a2',
  'ada@example.com',
  'authenticated'
);

select is_empty(
  'select id from public.reports',
  'Ada cannot read Ben flag'
);

select pg_temp.assume(
  '00000000-0000-0000-0000-000000000099',
  'agent@example.com',
  'agent_writer'
);

select lives_ok(
  $$
  update public.reports
  set triage_label = 'needs_a_look',
      triage_reason = 'Price text may be stale'
  where author_id = '00000000-0000-0000-0000-0000000000b3'
  $$,
  'agent triage orders the open flag'
);

select throws_ok(
  $$
  update public.reports
  set status = 'resolved'
  where author_id = '00000000-0000-0000-0000-0000000000b3'
  $$,
  '42501',
  null,
  'agent cannot resolve a flag'
);

select lives_ok(
  $$
  insert into public.suggestions (kind, reason, contact_id)
  select 'freshness', 'Website no longer responds', id
  from fixture
  where key = 'contact'
  $$,
  'agent can insert a pending suggestion'
);

reset role;

select is(
  (select status::text from public.reports where author_id = '00000000-0000-0000-0000-0000000000b3'),
  'open',
  'triage leaves the flag open'
);

select ok(
  exists (
    select 1
    from public.audit_log
    where action = 'report.triaged'
      and actor_role = 'agent'
  ),
  'triage writes an audit row'
);

select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000a1',
  'admin@example.com',
  'authenticated'
);

select lives_ok(
  $$
  insert into public.moderation_decisions (report_id, admin_id, decision, note)
  select id, '00000000-0000-0000-0000-0000000000a1', 'hide', 'Stale price'
  from public.reports
  where author_id = '00000000-0000-0000-0000-0000000000b3'
  $$,
  'admin records a hide decision'
);

select lives_ok(
  $$
  update public.suggestions
  set status = 'approved',
      decision_note = 'Noted for a later edit'
  where reason = 'Website no longer responds'
  $$,
  'admin can approve a suggestion'
);

reset role;

select is(
  (select status::text from public.reports where author_id = '00000000-0000-0000-0000-0000000000b3'),
  'resolved',
  'decision resolves the flag'
);

select is(
  (
    select hidden_at is not null
    from public.price_entries
    where author_id = '00000000-0000-0000-0000-0000000000a2'
  ),
  true,
  'hide decision hides the price entry'
);

select is(
  (select name from public.contacts where name = 'Pat Plumber'),
  'Pat Plumber',
  'approving a suggestion does not change the contact'
);

select is(
  (select status::text from public.suggestions where reason = 'Website no longer responds'),
  'approved',
  'suggestion is approved and still not applied'
);

select ok(
  exists (
    select 1
    from public.audit_log
    where action = 'moderation.decision'
      and actor_role = 'admin'
  ),
  'moderation decision writes an audit row'
);

select ok(
  exists (
    select 1
    from public.audit_log
    where action = 'suggestion.created'
      and actor_role = 'agent'
  )
  and exists (
    select 1
    from public.audit_log
    where action = 'suggestion.reviewed'
      and actor_role = 'admin'
  ),
  'suggestion create and review are audited'
);

-- Invite preview is the only anonymous read.
select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000a1',
  'admin@example.com',
  'authenticated'
);

with inserted as (
  insert into public.invitations (email, token, invited_by)
  values (
    'new@example.com',
    repeat('a', 64),
    '00000000-0000-0000-0000-0000000000a1'
  )
  returning token
)
insert into secrets (key, value)
select 'token', token
from inserted;

select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000d5',
  'new@example.com',
  'anon'
);

select throws_ok(
  'select email from public.invitations',
  '42501',
  null,
  'anon cannot read the invitations table'
);

select is(
  (
    select email
    from public.invitation_preview((select value from secrets where key = 'token'))
  ),
  'new@example.com',
  'anon can preview one pending invite by token'
);

select is_empty(
  $$ select email from public.invitation_preview('not-a-real-token') $$,
  'unknown token previews nothing'
);

select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000d5',
  'new@example.com',
  'authenticated'
);

select lives_ok(
  format(
    'select public.accept_invitation(%L, %L)',
    (select value from secrets where key = 'token'),
    'New Neighbor'
  ),
  'invited member can accept'
);

select is(
  (
    select display_name
    from public.members
    where id = '00000000-0000-0000-0000-0000000000d5'
  ),
  'New Neighbor',
  'acceptance creates the member profile'
);

select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000a2',
  'ada@example.com',
  'authenticated'
);

select throws_ok(
  $$
  do $body$
  begin
    insert into public.contacts (name, author_id)
    values ('Lonely', '00000000-0000-0000-0000-0000000000a2');
    set constraints all immediate;
  end
  $body$;
  $$,
  'P0001',
  'contact must belong to at least one category',
  'a contact needs at least one category'
);

-- The last admin cannot be removed. The outer transaction rolls back either way.
select pg_temp.assume(
  '00000000-0000-0000-0000-0000000000a1',
  'admin@example.com',
  'authenticated'
);

select throws_ok(
  $$
  update public.members
  set removed_at = now()
  where id = '00000000-0000-0000-0000-0000000000a1'
  $$,
  'P0001',
  'cannot remove or demote the last admin',
  'the last admin cannot be removed'
);

select * from finish();

rollback;
