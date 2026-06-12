# 思考文字泄漏到结论区 — 诊断与修复模式

## 适用场景

任何流式 AI 文本输出场景：模型输出"规划文字"（"让我先检查..."）跨轮次累积到最终结论区。常见于 Electron + SSE 流式 UI 中。

## 诊断三步法

### 1. 先确认上游数据（二分：前端问题 vs 模型/服务端问题）

在 SSE 事件处理处加一行诊断日志，确认 `part.type` 的实际值：

```typescript
// 加在 message.part.updated 处理处
log.info(`[diag] type="${part.type}" id="${part.id.slice(0,12)}"`)
```

**关键判断：**
- 如果全都是 `type="text"` → 模型/服务端没有区分思考 vs 结论，前端无法过滤
- 如果有 `type="reasoning"` 和 `type="text"` 混合 → 服务端正确分类了，问题在前端累积逻辑

### 2. 确认是累积问题还是覆盖问题

对比竞品（如 DeepSeek Web UI）的处理方式：它们每轮模型输出独立显示，不拼在一起。由此推断是前端**累积**了所有轮次的 text delta。

### 3. 修复时先确认数据结构

**常见陷阱：** 假设 `messageId` 能区分轮次。实际 OpenCode 同一轮可能产生多个 text part（text → tool → text → tool → text），它们共用同一个 `messageId`。

正确做法：按 **text part ID** 过滤，只保留最新 text part 的 delta。

## 修复代码

### 渲染进程

```typescript
let lastTextPartId: string | null = null
// part.updated: if (part.type === "text") lastTextPartId = part.id
// part.delta: if (lastTextPartId !== null && partId !== lastTextPartId) return
```

### 主进程

```typescript
const responseText = lastAssistant?.parts
  ?.filter((p) => p.type === "text").at(-1)?.text || ""
```

## 注意事项

- Page 和 Hook 都要修：TaskNewPage 和 useTaskExecution 共享数据通道
- Text part ID ≠ messageId：同一消息可有多个 text part
- 完成时 message-delta 应覆盖（而非保护）流式 content
