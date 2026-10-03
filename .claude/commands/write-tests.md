---
description: Write tests for a feature or table, including two-user RLS tests
argument-hint: <feature or table name>
---
Write tests for: $ARGUMENTS

- Read the implementation and the PRD requirement first, and test the requirement, not just the code as written.
- For UI: Vitest + Testing Library. Cover loading, empty, error, and success states.
- For database tables: write a pgTAP test in `supabase/tests/` that proves, using two member users and one admin, that members can read, that only the author can update or delete, that unauthenticated access fails, and that admin rules hold.
- Run the tests. If a test fails because of a real bug, do not change the implementation. Report the bug with the failing test.
