# thinking-conclusion isolation — lastTextPartId pattern

## Problem

OpenCode sends text deltas from ALL assistant turns to the renderer. The
renderer accumulates them all into one `content` string, so planning text from
earlier turns ("Let me check the login status...") appears in the conclusion
area alongside the final answer.

## Root Cause

OpenCode structures responses across multiple turns within one message:

```
Turn 1: text part → "Let me check login status..."
         tool parts → (tool calls)
Turn 2: text part → "Draft created successfully. Summary: ..."
```

Both text parts share the same `messageId`, so filtering by `messageId` fails.
They also both have `type: "text"` (not `type: "reasoning"`), so reasoning
filtering also fails.

DeepSeek v4-pro intentionally writes its plan as visible text between tool calls
— this is model behavior, not a bug.

## Solution: `lastTextPartId` tracking

Filter delta events by **text part ID**, not message ID. Only the most recently
updated text part's deltas are written to content.

```typescript
// In the useEffect closure
let lastTextPartId: string | null = null

// In part.updated handler:
if (part.type === "text") lastTextPartId = part.id

// In part.delta handler:
if (lastTextPartId !== null && partId !== lastTextPartId) return
// Only write delta for the latest text part
```

## Why `lastTextPartId` beats `lastAssistantMsgId`

| Approach | Result |
|----------|--------|
| `lastAssistantMsgId` | Same message → all text parts pass → leak persists |
| `lastTextPartId` | Only latest text part passes → planning text skipped |

## Files affected (wandox-work)

- `TaskNewPage.tsx` — inline subscriptions
- `useTaskExecution.ts` — shared hook used by GeneratingPage for playbook tasks
- `task.service.ts` — also changed `join("")` → `at(-1)?.text` at session.idle

Both files must be fixed. Page and Hook share the same data channel.

## Diagnostic pattern

Before fixing, add a one-line log to confirm the hypothesis:

```typescript
// In part.updated handler:
log.info(`[part-type-diag] type="${part.type}" id="${part.id.slice(0,12)}"`)

// Run one task, check log for type distribution
// "reasoning": 40, "text": 38 → confirms text parts are the problem
```
