# CLAUDE.md — forensic-bisect reference

This project uses the **forensic-bisect** debugging methodology.

## Quick Reference: 4-Layer Debugging

### Layer 0: Confirm
- Exact error message
- Reproduction steps
- Which component?

### Layer 1: Bisect
| Problem type | Bisect test |
|-------------|------------|
| Frontend error | curl backend directly |
| Backend error | curl bypass gateway |
| DB issue | direct DB client |
| Third-party | curl third-party API |
| Auth issue | curl with token |

### Layer 2: Drill down
Gateway → Service → Endpoint → Function

### Layer 3: Code
**Only when all system tests are exhausted.**

## Anti-patterns

| Don't | Do |
|-------|-----|
| `search_files` on error string | Confirm phenomenon first |
| `read_file` immediately | curl to isolate boundaries |
| "I read some code, maybe..." | "I haven't read code yet, let me curl first" |
| Multiple changes at once | One boundary test at a time |

## Decision rule

If you haven't done at least one system-level binary-search test, **you haven't started debugging yet.**
