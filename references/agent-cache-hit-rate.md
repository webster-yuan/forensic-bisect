# Agent 响应质量下降但上下文远未满：缓存命中率诊断

## 现象

Agent 在上下文使用率 20% 左右时就开始出现质量下降（输出变慢、细节丢失、需重复指令），但模型声称支持 1M context，理论上 200K 不应该出问题。

## Layer 1 二分

```
刀 1: 确认模型 API 兼容层是否完全支持缓存协议
      → DeepSeek 的 Anthropic 兼容层不完全支持 cache_control
      → Claude Code 以为有缓存，实际每次全量计算

刀 2: 检查上下文膨胀源
      → AGENTS.md 大小、CLAUDE.md 大小、trigger:always 的 skills
      → 实际基础开销可能远大于 Claude Code 显示的比例

刀 3: 检查 Hooks 是否在破坏缓存链
      → 每个 hook 输出注入上下文 → 缓存前缀被打破 → 命中率崩溃
```

## 诊断脚本

在项目根目录执行以下检查：

```python
# 1. 检查 always-trigger skills
import os, json
skills_dir = os.path.expanduser("~/.claude/skills")
for item in os.listdir(skills_dir):
    skill_path = os.path.join(skills_dir, item, 'SKILL.md')
    if os.path.exists(skill_path):
        with open(skill_path, 'r') as f:
            content = f.read()
        if 'trigger: always' in content[:500].lower():
            print(f"ALWAYS: {item} ({os.path.getsize(skill_path):,}B)")

# 2. 检查上下文注入源大小
for f in ['CLAUDE.md', 'AGENTS.md']:
    path = os.path.expanduser(f"~/.claude/{f}")
    if os.path.exists(path):
        print(f"{f}: {os.path.getsize(path):,}B")

# 3. 检查 hooks 数量
settings_path = os.path.expanduser("~/.claude/settings.json")
if os.path.exists(settings_path):
    with open(settings_path, 'r') as f:
        settings = json.load(f)
    hooks = settings.get('hooks', {})
    total = sum(len(v) if isinstance(v, list) else 1 for v in hooks.values())
    print(f"Hooks total: {total}")
    for event, handlers in hooks.items():
        count = len(handlers) if isinstance(handlers, list) else 1
        print(f"  {event}: {count}")
```

## 根因：Harness 悖论

```
Harness 机制（hooks/skills/agents 定义）
  → 增加系统 prompt 大小 → 基础开销 35K+
  → hooks 输出注入上下文 → 每轮打破缓存前缀
  → 实际计算量 = 显示用量的 2-3x
  → 即使显示 20%，实际模型在算 40-50%
  → 踩到 Transformer 长上下文衰减区间
  → Agent 变慢变蠢
```

**护栏和缓存天然冲突**。护栏越完善，缓存越碎片化。

## 修复优先级

| 顺序 | 操作 | 缓存效果 |
|------|------|---------|
| 1 | 删 settings.json hooks 段（全部） | 恢复缓存链连续性 |
| 2 | AGENTS.md 压到只保留高频 agent | 减 ~5K 基础开销 |
| 3 | CLAUDE.md <2KB（crewkit 纪律） | 减 ~2K 基础开销 |
| 4 | trigger:always 的 skill 改为 on-demand | 减 ~6K 基础开销 |
| 5 | 手动 /compact 在 15% 时触发，不等 20% | 避免踩到衰减区间 |

## 参考

- crewkit README: "Best combo: crewkit + Superpowers (zero conflict)" — Superpowers 无 hooks/无自动注入，不破坏缓存
- crewkit README: "Known Limitations: Role Weight Conflict" — ECC hooks 拦截 Worker 操作的同源问题
