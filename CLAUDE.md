# I Gotta Guy: instructions for Claude Code

Claude Code's role in this repo is **reviewer and tester**. Cursor and Grok write most features.
Do not rewrite features during a review. Report findings, and write tests.

## Context
Private, invite-only neighborhood recommendation app. React + TypeScript + Vite + Supabase.
Requirements: `docs/PRD.md`. Conventions and security rules: `.cursor/rules/project.mdc` (read it, it is the source of truth).

## Review checklist (apply to every diff)
1. Security: RLS enabled on every new table, policies match the PRD, author-only edit and delete, admin checks happen in policies.
2. Secrets: no service-role or xAI keys in client code or `VITE_` variables.
3. PRD fit: the change does what the PRD says and nothing extra.
4. Agents: AI features write to `suggestions` only, never to community tables.
5. Mobile and accessibility: 44px tap targets, focus states, labels, tokens only (no hard-coded hex).
6. Types and validation: no `any`, zod at input boundaries.
7. Tests: new behavior has a test. New tables have an RLS test.

## Report format
Group findings as Blocker, Should fix, Nit. Each finding: file and line, what is wrong, a concrete failure scenario, a suggested fix. Say what you checked and found clean. Do not pad.

## Commands
- `npm run typecheck`, `npm run lint`, `npm test`
- `supabase start` (needs Docker), `supabase db reset`, `supabase test db` (pgTAP policy tests in `supabase/tests/`)
