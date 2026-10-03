# I Gotta Guy

Private, invite-only neighborhood recommendation app. Requirements live in `docs/PRD.md`.

## Run

1. `npm install`
2. Copy `.env.example` to `.env.local` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` (the anon key only; never a service-role key).
3. `npm run dev`

`src/lib/supabase.ts` throws if those variables are missing.

## Test

- `npm run typecheck`
- `npm run lint`
- `npm test`
- `npm run build`

## Folder map

- `src/components` shared UI, including the app shell
- `src/features` feature slices (empty until the first feature)
- `src/routes` route screens
- `src/lib` shared clients
- `src/types` shared TypeScript types
- `supabase/migrations` schema changes
- `supabase/tests` database policy tests
- `supabase/functions` Edge Functions
- `scripts` one-off scripts
- `tests/validation` validation tests outside `src`
- `docs` PRD, decisions, and the agent playbook
- `.cursor/rules` Cursor project rules
- `.claude` Claude review commands and agents
