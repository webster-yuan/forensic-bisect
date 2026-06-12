# SSE Part Type 诊断方法

当怀疑 OpenCode 的 SSE `part.updated` 事件中 `part.type` 分类不正确时（如 reasoning 被标记为 text），在主进程加一行日志确认。

---

## 诊断日志

在 `task.service.ts` 的 SSE 事件处理中（`case "message.part.updated"` 分支），紧接 `if (!part) break` 之后插入：

```typescript
// DIAGNOSTIC: confirm part.type (reasoning vs text classification)
log.info(`[part-type-diag] type="${part.type}" id="${String(part.id).slice(0, 12)}" taskId=${taskId}`)
```

---

## 分析

运行一个任务，在 `%APPDATA%/wandox-work/logs/main.log` 中搜 `part-type-diag`：

```bash
grep "part-type-diag" main.log | sed 's/.*type="\([^"]*\)".*/\1/' | sort | uniq -c
```

期望输出：
```
 134 tool
  40 reasoning    ← 有则说明分类正常
  38 text
  20 step-start
  18 step-finish
```

如果 `reasoning` 为 0 → OpenCode 未正确分离 DeepSeek 的 `reasoning_content`。  
如果 `reasoning` 和 `text` 都有但仍泄漏 → 问题在别处（可能是模型自身把规划写成了 text）。

---

## 何时用

- 前端已正确过滤 `type="reasoning"`，但思考文字仍出现在结论中
- 怀疑模型把 thinking 输出为 `content` 而非 `reasoning_content`
