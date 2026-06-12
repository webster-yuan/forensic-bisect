# Diagnostic Log Pattern: One-Line Proof Before Multi-File Fix

## When to Use

When a bug spans multiple components (main process + renderer + shared hook) and each test cycle is expensive (200s Electron rebuild), add a **single diagnostic log line** before writing any fix code.

## Pattern

```typescript
// 1. Add ONE log line at the data source
case "message.part.updated": {
  const part = props.part
  // DIAGNOSTIC — remove after confirming
  log.info(`[part-type-diag] type="${part.type}"`)
  // ... existing code
}

// 2. Run one task, check logs
// 3. If log confirms hypothesis → proceed with fix
// 4. Remove diagnostic line in the fix commit
```

## Why This vs. "Just Fix It"

- **Expensive test cycles**: Electron rebuild + task execution = 200s per iteration. A bad fix costs 200s. A log line costs 0 (it confirms or refutes your hypothesis without changing behavior).
- **Multi-component bugs**: When a bug manifests in the renderer but originates in the main process or MCP server, changing renderer code blindly is just guessing.
- **Wrong assumptions**: The `messageId`-based filter assumed each assistant turn creates a new message. The log revealed multiple text parts share the same messageId. The fix changed from `lastAssistantMsgId` to `lastTextPartId`.

## Real Example: Thinking-Conclusion Isolation

Hypothesis: "reasoning text leaks because OpenCode doesn't send type='reasoning' parts."

Diagnostic: Added `log.info('[part-type-diag] type="${part.type}"')` at `task.service.ts` L1217.

Result:
```
type="reasoning": 40 entries
type="text":       38 entries
type="tool":      134 entries
```

The log disproved the hypothesis. OpenCode DOES send reasoning parts. The real issue was text accumulation across turns (multiple text parts in the same assistant message).

Without the diagnostic, we would have wasted 2-3 fix-attempt cycles (400-600s) chasing the wrong root cause.
