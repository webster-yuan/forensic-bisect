# Thinking-Conclusion Isolation — Diagnostic Pattern

## Problem

In Electron + SSE streaming, the agent's planning/thinking text leaks into the conclusion area. The fix went through 3 iterations before finding the right approach.

## Diagnostic Flow

### Step 1: Add diagnostic log at data source

Added `[part-type-diag]` logging at `task.service.ts` L1213 to capture actual `part.type` values from OpenCode SSE:

```
type distribution (250 entries):
  "tool": 134, "reasoning": 40, "text": 38, "step-start": 20, "step-finish": 18
```

Key finding: `type="reasoning"` IS correctly separated. The leaked text is `type="text"` — the model writes planning as regular text output.

### Step 2: Compare with reference implementation

DeepSeek's web UI shows each turn's text independently. They don't accumulate all turns into one blob. This revealed the real problem: multiple text parts across turns get concatenated.

### Step 3: Wrong fix — messageId filtering

First attempt: track `lastAssistantMsgId` and filter deltas by message ID.

```typescript
// WRONG — OpenCode can produce multiple text parts within the same message
if (lastAssistantMsgId !== null && messageId !== lastAssistantMsgId) return
```

Failed because: OpenCode creates multiple `text` parts within a single assistant message (text → tool → text → tool → text), all sharing the same messageId.

Plus: when `lastAssistantMsgId` is null (before first `part.updated`), the guard `lastAssistantMsgId !== null && ...` evaluates to `false`, allowing ALL deltas through.

### Step 4: Correct fix — text part ID filtering

Track `lastTextPartId` at the part level, not message level:

```typescript
// In part.updated handler:
if (part.type === "text") lastTextPartId = part.id

// In delta handler:
if (lastTextPartId !== null && partId !== lastTextPartId) return
```

This correctly isolates only the latest text part, regardless of which message it belongs to.

## Key Lesson

**Always verify data structure with diagnostic logging before writing filtering logic.** The assumption that "one message = one text part" was wrong. A single log line showed the actual structure in seconds, while the wrong fix cost two build-test cycles.
