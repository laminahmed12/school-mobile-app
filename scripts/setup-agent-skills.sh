#!/usr/bin/env bash
set -euo pipefail

# Run from the Lamīn repository root. Requires Node.js >= 22.20.
# The skills CLI may ask which agent(s) should receive the project-local skills.
npx skills add supabase/agent-skills --skill supabase
npx skills add supabase/agent-skills --skill supabase-postgres-best-practices

echo "Skill installation commands completed. Verify the generated skill directories before relying on them."
