# Decisions

- Tailwind CSS 3 with PostCSS, so the five color tokens live in `tailwind.config.ts` as the project rules require.
- 2026-10-05: Member submissions (contacts, edits, referrals, ratings, reviews) publish immediately; members insert and edit/remove only their own content; admins can hide/remove any content; flags follow report -> admin queue -> admin decision with an audit record; only AI-generated output goes through `suggestions` for admin approval.
- 2026-10-05: Price entries follow that same immediate-publish rule.
- 2026-10-05: Agent triage only orders an open flag and cannot hide, remove, or resolve it.
- 2026-10-05: A review is one row per member per contact, with an optional 1–5 rating and optional text, and at least one of those is required.
- 2026-10-05: Approving a suggestion records the decision and an audit row. It does not copy `payload` into community tables.
- 2026-10-05: The first admin is inserted with the service role. Later members join by accepting an invitation. Invites expire after 14 days unless an admin sets another time.
- 2026-10-05: Duplicate contacts are reported for an admin to consolidate. Phone and name are not unique constraints.
- 2026-10-05: Working choices pending owner confirmation: `contacts.details` jsonb, `contact_categories`, and `referrals.referrer_label` for sheet households that are not member accounts yet.
