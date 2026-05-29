# forensic-bisect — Phenomenon-Driven Binary-Search Debugging

> A Claude Code / Hermes skill that replaces "read error → search code → read files → fix" with "observe phenomenon → bisect system boundaries → drill down → code is last resort."

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*[中文文档](README.zh.md)*

---

## The Problem

AI coding agents (OpenCode, Claude Code, etc.) default to **code-first debugging**: see an error, immediately `search_files` for the error string, `read_file` the source, and start guessing fixes.

This is **not how experienced developers debug**. They start from the **phenomenon**, use **binary search at system boundaries** to isolate the problem, and only look at code as a last resort.

## The Solution

forensic-bisect provides a structured 4-layer debugging methodology:

```
Layer 0: Confirm the phenomenon
  → exact error message, reproduction steps, which component?

Layer 1: Binary-search at system boundaries
  → one curl/MCP call splits the problem space in half

Layer 2: Drill down within the identified layer
  → gateway → service → endpoint → function

Layer 3: Code as last resort
  → only when all system-level tests are exhausted
```

## Real Example: 405 Error Debugging

**Problem**: "Request failed with status code 405" when clicking authorize.

**Traditional AI approach**: search code for "405" → read auth files → guess fixes.

**forensic-bisect approach** (3 minutes, 0 lines of code):
```bash
# Layer 1: MCP server vs auth page
curl MCP auth_login → 200 ✅ → MCP works, problem on admin.wandox.com

# Layer 1: nginx vs application
curl POST admin.wandox.com/api/v1/auth/login → 405
curl POST ai-api.wandox.com/api/v1/auth/login → 422 ✅
→ nginx blocks POST /api/v1/*

# Conclusion: nginx config issue, done.
```

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/forensic-bisect.git
cd forensic-bisect
bash install.sh        # macOS / Linux / WSL
# or
.\install.ps1          # Windows PowerShell
```

Installs to `~/.claude/skills/forensic-bisect/` (Claude Code) or `~/.hermes/skills/forensic-bisect/` (Hermes).

## Relationship with systematic-debugging

- **forensic-bisect**: find WHERE the problem is (system-level, binary search)
- **systematic-debugging**: fix WHAT the problem is (code-level, root cause)

Use forensic-bisect first to isolate the component, then switch to systematic-debugging if the issue is within code.

---

## License

MIT
