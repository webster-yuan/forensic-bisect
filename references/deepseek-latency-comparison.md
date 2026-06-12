# DeepSeek 模型延迟对比诊断

## 问题

OpenCode 对接 deepseek-v4-pro 时感觉"很慢"（14s+ 才出第一个字）。

## 诊断方法

不要猜测，直接测 API：

```bash
# 1. 同一任务，streaming vs non-streaming
curl -X POST https://api.deepseek.com/anthropic/v1/messages \
  -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" \
  -d '{"model":"deepseek-v4-pro","max_tokens":500,"stream":true,
       "messages":[{"role":"user","content":"排查 405 错误"}]}'

# 2. 对比不同模型同一任务
# deepseek-v4-pro (reasoning): 首次可见文字 14s, total 14.2s
# deepseek-chat (non-reasoning): 首次可见文字 0.5s, total 4.9s
```

## 根因

deepseek-v4-pro 是推理模型，每个请求先"想" 12-15 秒（thinking phase），然后才输出。streaming 模式下 493 个 thinking delta 后才出第一个 text delta。客户端无法加速这个过程。

## 结论表

| | v4-pro | deepseek-chat |
|------|:--:|:--:|
| 首次可见文字 | 14.0s | 0.5s |
| 思考阶段 | 493 delta (12.8s) | 0 |
| 适合场景 | 重度 debug、多步骤分析 | 日常任务 |

## 建议

日常任务用 deepseek-chat，复杂推理任务再切 v4-pro。不是客户端问题，是模型特性。
