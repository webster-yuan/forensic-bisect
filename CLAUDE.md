# CLAUDE.md

This file provides guidance to Claude Code when working in the forensic-bisect repository.

## Project Overview

forensic-bisect is a Claude Code / Hermes skill that implements **phenomenon-driven binary-search debugging** — start from the observed symptom, bisect at system boundaries, and only read code as a last resort.

## Repo Structure

```
forensic-bisect/
├── SKILL.md              # Skill definition (entry point)
├── README.md             # GitHub-facing README (English)
├── README.zh.md          # GitHub-facing README (Chinese)
├── LICENSE               # MIT
├── install.sh            # Unix install script
├── install.ps1           # Windows install script
├── CLAUDE.md             # This file
├── templates/            # Project scaffold files
│   └── CLAUDE.md         # Quick reference for projects
└── .gitignore
```

## Conventions

- SKILL.md is the main file — self-contained methodology
- README.md targets GitHub visitors — "why", not just "what"
- README.zh.md mirrors README.md in Chinese
- Template files are lightweight; SKILL.md has the full content
- Keep the skill file focused: methodology, not implementation details

## When Editing

- The 4-layer framework is the core structure — don't break it
- Every principle must have a concrete example
- Anti-patterns table is as important as the methodology itself
