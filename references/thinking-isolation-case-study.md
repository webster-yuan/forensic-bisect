# 案例：Thinking/Conclusion Isolation 排查

> 关联: `docs/architect/thinking-conclusion-isolation.md`

## 现象

wandox-work TaskNewPage 偶现模型思考过程（reasoning text）混入结论显示区。

## 排查路径（forensic-bisect 多层 drill-down）

### Layer 1 — 第 1 刀：前端代码 vs 上游数据

```
问题: coder 按设计文档实现了 thinking-conclusion-isolation 修复
      → 缓冲 + 类型过滤 + 防覆盖，全部正确落地
      → 但仍然泄漏

判断: 前端修复本身没问题
      → 问题在上游数据源
```

### Layer 1 — 第 2 刀：OpenCode SSE 事件 vs 模型输出

```
查 OpenCode 的 PartType 定义 → 有 "reasoning" 类型
查 task.service.ts SSE 日志 → 所有 part.updated 的 type 都是 "text"
      → OpenCode 从未生成 type="reasoning" 的 part

判断: 问题不在前端过滤逻辑，在 OpenCode 如何解析模型输出
```

### Layer 1 — 第 3 刀：OpenCode 适配器 vs API 端点

```
OpenCode 用 @ai-sdk/openai-compatible 适配器对接 DeepSeek
当前端点: api.deepseek.com/anthropic (Anthropic 兼容格式)
DeepSeek 原生: api.deepseek.com/v1 (OpenAI 兼容格式)

Anthropic 格式无 reasoning_content 概念
  → DeepSeek 把 reasoning_content 合并入 content
  → OpenCode 收到的是合并后的 text
  → 全部标记为 type="text"

判断: 根因在 API 端点选择
      前端修复无效 (not its fault)
      OpenCode 逻辑正确 (not its fault)
      模型输出格式正确 (not its fault)
      问题在「Anthropic 兼容端点」这个转换层丢掉了 reasoning_content
```

## 结论

三层 drill-down，每次排除一个系统边界：

```
TaskNewPage 代码 ✅ → OpenCode part 类型 ❌(全text)
  → DeepSeek Anthropic 端点 ❌(无 reasoning_content)
    → 根因确认
```

全程未改一行代码，靠日志观察 + 类型定义阅读 + API 端点特性分析定位。

## 教训

- **"同一组件内调试"可能是死路**：前端代码修了三遍还漏，因为问题根本不在前端
- **跨组件排查时，先确认数据在每一层的样子**：这比读代码更有效
- **API 兼容端点是有损的**：Anthropic 格式 ≠ OpenAI 格式，转换会丢字段
