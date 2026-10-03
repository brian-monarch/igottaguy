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
- `suggestions` — the only table AI features write. An admin approves a row before it changes community data.

The spec also names member, invitation, rating/review, price entry, report, moderation decision, and audit record. Price stays free text. Phones are stored E.164. A member edits or removes only their own referrals and reviews.

Stack: TypeScript, Supabase Postgres, RLS on every table.

## Agent roster

| Agent | Guardrail |
| --- | --- |
| Spec-to-schema | Map this data model to Supabase tables with RLS on every table, and stop for the owner to review each policy. |
| Seed-import | Import the cleaned Google Sheet with scripts that default to dry-run, phones in E.164, and price left as free text. |
| Feature slices | One vertical slice per branch and PR, small diff, with a test and a mobile screenshot check. |
| Reviewer | Check RLS, secrets, 44px targets, WCAG 2.2 AA contrast, tests, and spec scope. Leave the merge to the owner. |
| Freshness checker | Record possible stale or invalid fields (websites, contact info) in `suggestions` for an admin to approve. |
| Duplicate detector | Report likely duplicate contacts for an administrator to consolidate. |
| Moderation triage | Prepare flagged and pending items for an administrator to decide. |
| Dependency/drift | Report dependency and schema drift for the owner to act on. |
| Neighbor concierge | Answer from published directory records, and file anything new in `suggestions` for admin approval. |
| Add-a-Guy assistant | Search existing contacts first, then draft a contact or referral into `suggestions` for admin approval. |

## Review rule

The owner reviews every RLS policy and merges every PR.
