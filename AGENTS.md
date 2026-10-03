# AGENTS.md — I Gotta Guy

Shared context for every coding agent. Spec: `Project PRD .md`. `I Gotta Guy.md` matches it aside from a trailing newline.

## What this is

I Gotta Guy is a mobile-first, private neighborhood recommendation app. Friends, family, and neighbors find and share trusted contacts — babysitters, plumbers, restaurants, kid activities, and the other household and family needs in the spec — instead of maintaining a shared Google Sheet. Profiles hold referrals, ratings, reviews, pricing context, contact methods, and website links. The MVP is a small invite-only community with simple search, browse, and contribution. AI enrichment and external review discovery wait until after the MVP, and AI never publishes on its own.

Initial categories: babysitters, plumbers, landscapers, snow removal, roofers, appliance support, handymen, utilities, services, hobbies, restaurants, and kid activities.

## Data model

- `contacts` — shared contact table. Category-specific fields live in a `details` JSON column.
- `categories` — browse and search taxonomy.
- A multi-category join table, so one contact can sit in several categories.
- `referrals` — contributor, recommendation text, and date submitted, plus `referrer_label` (text) for a household referrer such as "Monarch's".
- `suggestions` — AI-generated output only. An admin approves a row before it changes community data. Member submissions do not land here.

The spec also names member, invitation, rating/review, price entry, report, moderation decision, and audit record. Price stays free text. Phones are stored E.164.

Stack: TypeScript, Supabase Postgres, RLS on every table.

## Publishing and moderation (settled)

Member submissions publish immediately: new contacts, edits, referrals, ratings, and reviews. RLS lets a member insert and edit or remove their own content directly. Admins can hide or remove any content. A report goes to the admin queue, an admin decides, and the decision is stored as an audit record. Moderation triage only orders that flag queue. Only AI-generated output goes through `suggestions` for admin approval. This closes the spec’s proposed pre-publish hold on new contacts and edits.

## Agent roster

| Agent | Guardrail |
| --- | --- |
| Spec-to-schema | Map this data model to Supabase tables. RLS lets a member insert and edit or remove their own content directly, and lets an admin hide or remove any content. Stop for the owner to review each policy. |
| Seed-import | Import the cleaned Google Sheet with scripts that default to dry-run, phones in E.164, and price left as free text. |
| Feature slices | One vertical slice per branch and PR, small diff, with a test and a mobile screenshot check. |
| Reviewer | Check RLS, secrets, 44px targets, WCAG 2.2 AA contrast, tests, and spec scope. Leave the merge to the owner. |
| Freshness checker | Record possible stale or invalid fields (websites, contact info) in `suggestions` for an admin to approve. |
| Duplicate detector | Report likely duplicate contacts for an administrator to consolidate. |
| Moderation triage | Order the flag queue only (report, then admin queue, then admin decision, with an audit record). |
| Dependency/drift | Report dependency and schema drift for the owner to act on. |
| Neighbor concierge | Answer from published directory records, and file anything new in `suggestions` for admin approval. |
| Add-a-Guy assistant | Search existing contacts first. A member’s own submission publishes immediately. AI-generated draft text goes to `suggestions` for admin approval. |

## Review rule

The owner reviews every RLS policy and merges every PR.
