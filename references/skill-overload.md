# Skill Overload Management

## The Problem

Having too many skills in `~/.claude/skills/` (or equivalent) is **counterproductive**:

1. **Token bloat**: Every skill's `name` + `description` is injected into the system prompt's `<available_skills>` block. 185 skills ≈ thousands of tokens burned before the conversation starts.

2. **Choice noise**: The LLM must scan all descriptions to decide which skill to load. More skills = higher probability of loading the wrong one, or none at all.

3. **Cold storage**: 90% of skills are domain-specific (healthcare, logistics, customs compliance, etc.) and will never match the user's work.

## Diagnosis

```bash
# Count active skills
ls ~/.claude/skills/ | wc -l

# Check cc-switch DB to see what's enabled per platform
sqlite3 ~/.cc-switch/cc-switch.db \
  "SELECT COUNT(*) FROM skills WHERE enabled_claude = 1"
```

If count > 30 and most are irrelevant to the user's stack, it's a problem.

## Solution Patterns

### Pattern A: Cold Storage (recommended)

Keep 10-20 core skills in `~/.claude/skills/`. Move the rest to `~/.claude/skills-library/`. A Skill Router (see `D:\yw\skill-router` project) can load from the cold library on demand.

```bash
mkdir ~/.claude/skills-library
mv ~/.claude/skills/healthcare-* ~/.claude/skills-library/
# ... repeat for irrelevant domains
```

### Pattern B: cc-switch Repo Management

In cc-switch, disable skill repos that pull in irrelevant skills:
- Open cc-switch → Skills → Repos
- Disable repos whose skills don't match your stack

### Pattern C: Per-Platform Gating

Use cc-switch's per-platform enable flags:
```sql
-- Enable only core skills for Claude
UPDATE skills SET enabled_claude = 0;
UPDATE skills SET enabled_claude = 1 WHERE name IN (
  'forensic-bisect', 'crewkit', 'coding-standards', ...
);
```

Note: cc-switch's auto-sync may override this. Pattern A is more reliable.

## Keep List Heuristic

Keep skills that match:
1. Your language/framework stack (TypeScript, React, Python, etc.)
2. Your workflow (debugging, planning, testing, code review)
3. Your infrastructure (Docker, GitHub, deployment)
4. Your methodology (forensic-bisect, crewkit)

Aim for **15-25 skills** total.
