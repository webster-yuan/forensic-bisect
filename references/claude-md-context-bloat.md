# CLAUDE.md Context Bloat

## 现象
同一模型同一问题，项目目录外 vs 内，回复速度差异明显。wandox_work AGENTS.md 25KB。

## 根因
Claude Code / OpenCode 自动读取项目根 CLAUDE.md/AGENTS.md，注入 system prompt。
25KB ≈ 6,300 tokens，排查 bug 时完全用不上。DeepSeek v4-pro 无 prompt caching。

## 诊断
```bash
find . \( -name "CLAUDE.md" -o -name "AGENTS.md" \) | xargs wc -c
```

## 修复
项目根 CLAUDE.md < 2KB。完整工作流留在 skill SKILL.md 中按需加载。
