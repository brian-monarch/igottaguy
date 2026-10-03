I Gotta Guy · Agent playbook

# Where Grok agents earn their keep: build, maintain, support

Two kinds of agent matter here. Build-time agents help you write the app in Cursor. Run-time agents are small programs inside the app that call Grok to do recurring work. Learning the difference is the core skill.

## First, what "Grok bots" can and cannot do today

BUILD-TIME

### Grok as a model inside Cursor

`grok-code-fast-1` is xAI's agentic coding model and was launched with Cursor as a partner. Pick it in Cursor's model menu and run it in Agent mode. Treat it as a fast, cheap worker for scoped tasks, and a stronger model for architecture and RLS review. Availability and pricing change, so check the picker.

RUN-TIME

### Grok through the xAI API

The API runs an agent loop for you with server-side tools: web search, X search, a Python sandbox, and document search. It also supports your own functions and remote MCP servers. This is what powers the freshness checker and the support concierge below.

**Correction to my earlier note.** I called Grok a weak fit for code. It is a legitimate coding model in Cursor. Its real edge for you is live web access at run time. A standalone Grok coding CLI (Grok Build) was still unreleased in the sources I found, which date to April 2026, so confirm its status before planning around it.

## Agent roster by lifecycle stage

### Spec-to-schema agent

Cursor Agent · day 1

Job

Turns the PRD into Supabase migrations, TypeScript types, and RLS policies, one table per commit.

Guardrail

You review every policy. Test with two member accounts: one must fail to edit the other's review.

Context

`.cursorrules` plus the PRD file in the repo.

You learn

Writing constraints the model must work inside.

### Seed-import agent

Cursor Agent · day 1

Job

Writes the one-time script that maps the Sheet's three tabs into `contacts`, `referrals`, and `categories`.

Guardrail

Dry-run mode prints what it would insert. You read the output before any write.

You learn

Agent plus dry-run as a safe default for data work.

### Feature-slice agents

Cursor Agent · days 2 to 6

Job

One vertical slice per task: search, contact profile, Add a Guy form, review form. Each ships with a test and a mobile screenshot check.

Guardrail

One slice per branch and per pull request. Small diffs keep review honest.

You learn

Task sizing. Agents fail on big vague asks and shine on tight ones.

### Reviewer agent

On every pull request

Job

A second model reads the diff with a checklist: RLS present, no secrets in client code, 44px tap targets, WCAG AA contrast against your five colors.

Guardrail

Use a different model than the one that wrote the code, so it does not grade its own work.

You learn

Separating the builder from the checker.

### Freshness checker

Weekly schedule · PRD Phase 3

Job

Checks each contact's website is still live and the business still appears to operate. Uses Grok web search. Writes findings to a `suggestions` table.

Guardrail

Read-only on contact data. It can only insert suggestions. An admin approves or rejects each one.

Where

Supabase Edge Function on a cron schedule. The xAI key lives in server secrets, never in the browser.

You learn

Tool-using agents, scheduled runs, and structured output.

### Duplicate detector

On "Add a Guy" submit

Job

Compares a new contact to existing ones by name, phone, and category. Returns likely matches with a confidence note.

Guardrail

Cheap first pass in SQL (normalized phone, trigram name match). The model only judges the ambiguous cases.

You learn

When not to use an LLM, and how to combine it with deterministic code.

### Moderation triage

On new contact, edit, or flag

Job

Pre-sorts the admin queue: likely fine, needs a look, possible sensitive personal info. Adds a one-line reason.

Guardrail

It orders the queue and never approves or rejects. Your PRD forbids autonomous publishing.

You learn

Human-in-the-loop design.

### Dependency and drift agent

Monthly · Cursor background agent

Job

Opens a pull request for dependency updates and runs the tests. Flags schema changes that lack a matching policy.

Guardrail

Pull request only. You merge.

You learn

Agents that work while you are away, with a clear review gate.

### Neighbor concierge

In-app search box

Job

Turns "my sitter cancelled, need someone Friday near Wayzata" into a category, filters, and a ranked shortlist from your own data.

Guardrail

Answers only from directory records and cites each profile. If nothing fits it says so. It never invents a provider.

Pattern

Custom function calls: `search_contacts`, `get_profile`. The model picks the call and your code runs it under the member's own permissions.

You learn

Function calling and retrieval over your own data.

### Add-a-Guy assistant

In the contribution form

Job

Member pastes a text message or a link. The agent drafts the fields: name, category, phone, notes. The member edits and submits.

Guardrail

Fills a draft form only. The member is the author of record.

You learn

Extraction into a schema with validation.

### Admin help desk

Cursor chat with project docs

Job

You ask "why did this member see no results?" and an agent with read-only access to logs and a staging database investigates.

Guardrail

Read-only database role. No production writes from an agent.

You learn

Least-privilege credentials for agents.

### Invite and onboarding drafter

As needed

Job

Drafts invitation texts and a short how-to in plain language for neighbors who are not technical.

Guardrail

You send everything.

You learn

Low-risk first use of an agent while you build confidence.

## The autonomy ladder

Move each agent up one rung only after it has been right for a few weeks. Select a rung to see what it demands from you.

## What your Google Sheet means for the build

| Finding | Impact |
| --- | --- |
| Three data tabs hold only 11 records in total: 9 contractors, 1 sitter, 1 restaurant. | The import is an hour of work. Hand-check every row instead of building cleanup tooling. |
| Each tab has different columns. Sitters have rate, availability, and transport. Restaurants have city and food type. | Keep a shared `contacts` table and put category-specific details in a `details` JSON column. |
| Referrers are households ("Monarch's", "Schwartz's"), not individual accounts. | Add a `referrer_label` text field to seed referrals now. Link them to real members as people join. |
| "Lawn, Snow" is one cell with two categories. | This validates the multi-category join table. |
| Price appears as `$` to `$$$$` and as dollar ranges. Phones use mixed formats. 4 of 9 contractors have links. | Normalize phones to E.164 on import. Keep price as free text, which matches your PRD. |
| The Lookups tab lists categories, referrers, rate bands, and food types. | Use it directly as the category seed list. |

## Your first three moves

1. **Set up the repo and rules.** Create the GitHub repo, a Supabase project, and a `.cursorrules` file. Put the PRD and a one-page `AGENTS.md` in the repo so every agent shares the same context.
2. **Run the spec-to-schema agent.** Ask it for migrations and RLS only, no UI. Review the policies, then test them with two accounts.
3. **Build the suggestions table before any AI feature.** Every run-time agent writes to it, so the approval path exists from the start.