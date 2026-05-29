#!/usr/bin/env bash
# forensic-bisect install script (Unix / macOS / WSL)
# Copies forensic-bisect skill to ~/.claude/skills/forensic-bisect/ and ~/.hermes/skills/forensic-bisect/
set -euo pipefail

CLAUDE_SKILL_DIR="${HOME}/.claude/skills/forensic-bisect"
HERMES_SKILL_DIR="${HOME}/.hermes/skills/forensic-bisect"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== forensic-bisect installer ==="

# Install to Claude Code
if command -v claude &> /dev/null; then
  if [ -d "$CLAUDE_SKILL_DIR" ]; then
    echo "Claude Code: already installed at $CLAUDE_SKILL_DIR (skipping)"
  else
    mkdir -p "$CLAUDE_SKILL_DIR"
    cp "$SCRIPT_DIR/SKILL.md" "$CLAUDE_SKILL_DIR/"
    echo "Claude Code: installed to $CLAUDE_SKILL_DIR"
  fi
fi

# Install to Hermes
if command -v hermes &> /dev/null; then
  if [ -d "$HERMES_SKILL_DIR" ]; then
    echo "Hermes: already installed at $HERMES_SKILL_DIR (skipping)"
  else
    mkdir -p "$HERMES_SKILL_DIR"
    cp "$SCRIPT_DIR/SKILL.md" "$HERMES_SKILL_DIR/"
    echo "Hermes: installed to $HERMES_SKILL_DIR"
  fi
fi

echo "Done! Restart Claude Code or Hermes to pick up the skill."
echo ""
echo "To verify: ask your agent '排查这个问题' and it should load forensic-bisect."
