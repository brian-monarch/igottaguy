---
description: Review the current branch against main using the I Gotta Guy checklist
allowed-tools: Read, Grep, Glob, Bash(git diff:*), Bash(git log:*), Bash(git status:*)
---
Review the changes on this branch compared with main.

1. Run `git diff main...HEAD` and read every changed file in full, not only the diff hunks.
2. Apply the review checklist in CLAUDE.md.
3. If anything under `supabase/migrations/` changed, delegate it to the rls-reviewer subagent and include its findings.
4. Do not edit files. Report using the format in CLAUDE.md.

Focus area, if provided: $ARGUMENTS
