# Agent skills for Lamīn

Lamīn uses Supabase and PostgreSQL. The recommended project skills are:

- `supabase` — Supabase APIs, authentication, migrations, RLS, Edge Functions, and security.
- `supabase-postgres-best-practices` — PostgreSQL schema design, migrations, RLS policies/tests, indexes, and query performance.

## Install in a development environment

Requirements: Node.js 22.20 or later and a supported coding-agent environment.

From the repository root, run:

```bash
bash scripts/setup-agent-skills.sh
```

The Vercel Skills CLI may ask which coding agent to target. Select the agent used for this checkout. After installation, inspect the generated skill directories and confirm both skills' `SKILL.md` files exist.

Alternatively, run the upstream commands individually:

```bash
npx skills add supabase/agent-skills --skill supabase
npx skills add supabase/agent-skills --skill supabase-postgres-best-practices
```

Upstream sources:

- https://github.com/supabase/agent-skills
- https://github.com/vercel-labs/skills

## Safety boundary

Installing agent instructions does not run database migrations or change Supabase projects. For Lamīn work, do not target production during skill setup or testing. Review all generated files and proposed code changes before use; keep database verification isolated from production.
