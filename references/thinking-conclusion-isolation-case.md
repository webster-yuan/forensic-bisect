# 案例：思考过程混入结论 — 从"时序竞争"到"多个消息拼接"

## 现象

wandox-work 任务详情页的结论区出现模型的规划/思考文字，如：

> "已登录。现在并行拉取所需信息。找到最相关的样板。现在拉取样板详情..."

这些文字来自模型在**调用工具之前**的 plan 输出，最终和真正的结论拼在了一起。

## Layer 0：现象确认

- 错误原文：结论区出现多轮模型 text，拼在一起
- 复现：创建剧本任务，模型先输出规划文字，然后调用工具，最后输出结论 → 结论区 = 规划 + 结论
- 环节：OpenCode SSE → task.service.ts → IPC → TaskNewPage.tsx

## Layer 1：第一个二分 — 是时序竞争吗？

architect 文档假设的根因：`part.delta` 先于 `part.updated` 到达，导致 `reasoningPartIds` 未记录 → reasoning delta 漏入 content。

**验证：** 加日志打 `part.type`。

结果：`reasoning: 40 条, text: 38 条` — OpenCode 正确分离了 reasoning 和 text。规划文字（"已登录。现在并行拉取..."）确实是 `type="text"`，不是 reasoning。

**结论：** 时序竞争假设被排除。问题在更上层。

## Layer 2：第二个二分 — 是模型行为还是代码逻辑？

用户关键观察：**DeepSeek 页面端没这个问题。**

DeepSeek 页面端把每轮输出独立展示。我们的问题是：流式阶段把所有轮次的 text delta 全拼进同一个 `content`。

**验证：** 检查 `onTaskMessagePartDelta` 回调。

结果：只解构了 `partId, field, delta`，**没拿 `messageId`** → 无法区分哪个 delta 属于哪轮 → 全拼。

## 修复

```typescript
// Fix 1: 追踪最新 assistant message ID
let lastAssistantMsgId: string | null = null
// 在 part.updated 中更新
if (part.messageID) lastAssistantMsgId = part.messageID

// Fix 2: delta 按 messageId 过滤
const unsubE = window.api.onTaskMessagePartDelta(({ taskId, messageId, partId, field, delta }) => {
  // 只接受最新消息的 text delta
  if (lastAssistantMsgId !== null && messageId !== lastAssistantMsgId) return
  // ...
})

// Fix 3 (主进程): 完成时只取最后一个 text part
const responseText = lastAssistant?.parts?.filter(p => p.type === "text").at(-1)?.text || ""
```

## 教训

1. **不要停在第一个假设。** 时序竞争看起来合理，但一条日志就排除了。
2. **对比同类产品。** "DeepSeek 页面端为什么没这个问题" → 关键突破口。
3. **观察用户行为。** 用户看了一遍就说出问题本质："不是时序问题，是没有用最后一次 text 回复"。比 AI 读半小时代码更准。
