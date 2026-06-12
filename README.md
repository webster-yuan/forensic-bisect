# forensic-bisect — Phenomenon-Driven Binary-Search Debugging

> A Claude Code / Hermes skill that replaces "read error → search code → read files → fix" with "observe phenomenon → bisect system boundaries → drill down → code is last resort."

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*[中文文档](README.zh.md)*

---

## What's New in v0.1.0

| Feature | What it does |
|---------|-------------|
| ⛔ **STOP hard-block** | 4-item checklist before any code-reading tool is allowed |
| **Layer 1.5** multi-root-cause | Detects when binary search fails (3 trigger signals → fence logging) |
| **Skip guide** | 5 scenarios where forensic-bisect adds overhead, not value |
| **Frontend/client bisect** | 6 frontend-specific bisect patterns in Layer 1 table |
| **Anti-patterns reordered** | By real frequency — "guessing root cause" now #1 |
| ⏱️ **Time budget** | Layer 0-1 must complete in 3 minutes |
| **Cannot-reproduce** | Sentinel logging strategy for intermittent bugs |

---

## The Problem

AI coding agents default to **code-first debugging**: see an error → `search_files` → `read_file` → guess fixes.

This is not how experienced developers debug. They start from the **phenomenon**, use **binary search at system boundaries**, and only look at code as a last resort.

## The Solution

A structured debugging methodology with hard guardrails:

```
⛔ STOP: 4-item checklist before touching code
    ↓
Layer 0: Confirm the phenomenon
    ↓
Layer 1: Binary-search at system boundaries (curl/log/ping, NOT code)
    ↓
Layer 1.5: Multi-root-cause detection (fence logging when bisect fails)
    ↓
Layer 2: Drill down within the identified layer
    ↓
Layer 3: Code as last resort
```

---

## When to Skip forensic-bisect

| Scenario | Why skip | Do instead |
|----------|---------|------------|
| Compiler tells you file + line | Bisect is overhead | Fix, verify compile |
| User says "config X is wrong" | Trust the user | Verify → fix → verify |
| One-line fix, immediately verifiable | Fixing is faster | Fix → verify; revert if wrong |
| Known dependency/version issue | Not a code bug | Upgrade/downgrade |

**Rule of thumb**: if the path from symptom to root cause is ≤ 2 steps, skip forensic-bisect.

---

## Core Anti-Patterns (Ordered by Frequency)

| # | Anti-Pattern | Correct Approach |
|---|-------------|-----------------|
| 1 | "I guess it's probably X" — hypothesizing before Layer 1 | Guess ≠ diagnosis. curl/log/ping first |
| 2 | Immediately `search_files` / `read_file` | Confirm Layer 0. Write down exact error first |
| 3 | Changed ≥2 files, still not fixed | You skipped bisect. Stop. Go back to Layer 1 |
| 4 | Changed multiple things at once | Change A → test. Change B → test. Never A+B together |
| 5 | Skipping diagnostic logs, going straight to code | One log line to validate your hypothesis first |

---

## Real Example: 405 Error (3 min, 0 lines of code)

```bash
# Layer 1: MCP server vs auth page
curl MCP auth_login → 200 ✅ → MCP works, problem on admin.wandox.com

# Layer 1: nginx vs application
curl POST admin.wandox.com/api/v1/* → 405
curl POST ai-api.wandox.com/api/v1/* → 422 ✅
→ nginx blocks POST /api/v1/* on admin server

# Conclusion: nginx config. Done.
```

## Real Example: Electron IPC 3-root-cause (multi-root-cause mode)

```bash
# Symptom: task status update sometimes doesn't refresh (30% repro rate)

# Layer 1 bisect → contradictory result:
#   Main process emits ✅, renderer sometimes receives ❓

# Enter Layer 1.5 → fence logging at 3 boundaries:
#   [MAIN] emit task-update id=1 ✅ → [BRIDGE] forward ✅ → [COMPONENT] received ✅
#   [MAIN] emit task-update id=2 ✅ → [BRIDGE] forward ❌         (bridge timing)
#   [MAIN] emit task-update id=3 ✅ → [BRIDGE] forward ✅ → [COMPONENT] received ❌ (unmount)
#   [MAIN] emit task-update id=4 ❌                                (pool deadlock)

# → 3 independent root causes found in one log run
```

---

## Installation

```bash
git clone https://github.com/webster-yuan/forensic-bisect.git
cd forensic-bisect
bash install.sh        # macOS / Linux / WSL
# or
.\install.ps1          # Windows PowerShell
```

Installs to `~/.claude/skills/forensic-bisect/` (Claude Code) or `~/.hermes/skills/forensic-bisect/` (Hermes).

## Relationship with systematic-debugging

- **forensic-bisect**: find WHERE the problem is (system-level, binary search)
- **systematic-debugging**: fix WHAT the problem is (code-level, root cause)

---

## License

MIT
