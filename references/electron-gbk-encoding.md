# Electron + Chinese Windows — GBK encoding pitfalls

## The Symptom

Electron main process logs show garbled Chinese in the dev terminal:

```
name: "澶寸▼鍗曡秴鏈熸湭鍒拌揣鎻愰啋"
```

But the same text in `%APPDATA%/wandox-work/logs/main.log` shows correctly.

## The Diagnosis

| Layer | Check | Result |
|-------|-------|--------|
| Terminal locale | `echo $LANG` in Git Bash | Already UTF-8 ✅ |
| Log file encoding | Open log file in VS Code | Chinese correct ✅ |
| Node.js stdout | `process.stdout` encoding | Missing — defaults to system ANSI |

On Chinese Windows, the system ANSI code page is GBK (CP936). Node.js's
`process.stdout` inherits this, so `console.log` output is GBK-encoded.
The terminal displays GBK bytes as UTF-8 → garbled characters.

Electron-log bypasses this by writing files with explicit UTF-8 encoding.

## The Fix

### Fix 1: Node.js stdout encoding (code-level, permanent)

In the main process entry point (`main/index.ts`), BEFORE any imports:

```typescript
// Force UTF-8 stdout on Windows — prevents GBK garbled console output
if (process.platform === "win32") {
  const isUtf8 = process.env.LANG?.includes("UTF") || process.env.LC_ALL?.includes("UTF")
  if (isUtf8) {
    // @ts-ignore setDefaultEncoding exists on Node.js WriteStream
    process.stdout.setDefaultEncoding?.("utf-8")
    // @ts-ignore
    process.stderr.setDefaultEncoding?.("utf-8")
  }
}
```

### Fix 2: Terminal locale (environment-level)

In VS Code / Windsurf `settings.json`:

```json
"terminal.integrated.env.windows": {
    "LANG": "zh_CN.UTF-8",
    "LC_ALL": "zh_CN.UTF-8"
}
```

In `~/.bashrc`:

```bash
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
```

Also create `~/.bash_profile` that sources `~/.bashrc` to satisfy Git Bash conventions.

### Fix 3: MCP response encoding (server-side, only if needed)

The wandox-mcp-client already has `decodeResponseBody()` which tries GBK as
fallback after UTF-8. This works correctly — the log file proves it. Don't
change this code unless there's evidence the decoding itself is broken.

## Anti-patterns

| Don't | Why |
|-------|-----|
| Swap UTF-8/GBK decode order in the MCP client | Log file already has correct Chinese — the code works |
| Add `chcp 65001` to npm scripts | Won't affect Node.js child process stdout |
| Change terminal font | Font issues look different (squares/boxes), not garbled CJK |
