# DeepSeek Anthropic 端点格式兼容性

- 最后确认：2026-06-01
- 涉及端点：`https://api.deepseek.com/anthropic`

---

## 背景

Claude Code v2.1.152 → v2.1.156 改变了 Anthropic API 的 system prompt 格式：

| 版本 | system 位置 | DeepSeek 兼容？ |
|------|-----------|:--:|
| v2.1.152 | 顶层 `"system"` 字段 | ✅ |
| v2.1.156 | `messages[]` 内 `role: "system"` | ❌ (当时) |

---

## 当前状态（2026-06-01）

**DeepSeek v4-pro 现已兼容两种格式。** 实测使用新版 `role: "system"` 在 `messages[]` 中发送，返回 200。

```bash
# 验证方法
curl -X POST "https://api.deepseek.com/anthropic/v1/messages" \
  -H "x-api-key: $DEEPSEEK_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-v4-pro",
    "max_tokens": 50,
    "messages": [
      {"role": "system", "content": "You are helpful."},
      {"role": "user", "content": "Reply: OK"}
    ]
  }'
# → 200 OK
```

---

## 历史修复

当时（2026-05）的 workaround 是锁定 Claude Code 到 v2.1.152：

```bash
npm install -g @anthropic-ai/claude-code@2.1.152 --save-exact
```

现已不需要 —— DeepSeek 端点已更新。
