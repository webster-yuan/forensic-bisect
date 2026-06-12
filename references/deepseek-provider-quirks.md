# DeepSeek Provider Quirks

Critical limitations of DeepSeek's Anthropic-compatible endpoint (`api.deepseek.com/anthropic`) that cause hard-to-diagnose bugs downstream.

---

## 1. No Prompt Caching

Anthropic's native API supports prompt caching — system prompts and long tool lists are cached server-side and only charged at 10% cost on subsequent turns. DeepSeek's `/anthropic` endpoint does NOT implement this.

**Impact**: Claude Code with 185 skills + large system prompt (~50K tokens) pays the full input cost every turn. First-token latency is 10-30s because DeepSeek must re-process all ~50K tokens.

**Mitigation**: Use skill-scout to reduce loaded skills, or switch to native Anthropic for long sessions.

---

## 2. No `reasoning_content` Separation

DeepSeek's native `/chat/completions` endpoint streams `reasoning_content` and `content` as separate fields. The Anthropic-compatible endpoint merges them — all text arrives as a single `content` stream.

**Impact**: OpenCode wraps everything as `type: "text"` parts. `type: "reasoning"` parts are never created. Frontend thinking/conclusion isolation filters (like `reasoningPartIds.has(partId)`) have zero effect.

**Symptom pattern**: 
- Frontend code filtering by part type works correctly
- But all parts have `type: "text"` — no `type: "reasoning"` ever appears
- Thinking text leaks into conclusion area

**Fix direction**: Use DeepSeek's OpenAI-compatible endpoint (`api.deepseek.com/v1`) instead of `/anthropic`, so OpenCode's OpenAI-compatible adapter can properly separate reasoning_content.

---

## 3. System Prompt Format Compatibility (HISTORICAL — resolved as of v2.1.159+)

Anthropic API v2.1.156+ moved `system` from top-level field to `messages[].role: "system"`. DeepSeek initially only supported the old format, causing 400 errors. As of 2026-06, DeepSeek's endpoint has been updated to support both formats.

**Historical fix**: `npm install -g @anthropic-ai/claude-code@2.1.152 --save-exact`

**Current status**: No longer needed. v2.1.159+ works with DeepSeek.
