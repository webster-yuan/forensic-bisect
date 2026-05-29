# forensic-bisect — 现象驱动的二分排查法

> 一个 Claude Code / Hermes skill，将"读错误 → 搜代码 → 读文件 → 改代码"翻转为"看现象 → 系统边界二分 → 逐层深入 → 代码最后看"。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 问题

AI 编程 Agent（OpenCode、Claude Code 等）排查问题的默认行为是：看到报错 → 搜代码 → 读文件 → 改代码。**这不是成熟开发者的思维。**

成熟开发者从**现象**出发，用**系统边界二分法**排除，**代码是最后的手段**。

## 方案

forensic-bisect 提供结构化的四层排查方法：

```
Layer 0: 现象确认
  → 错误原文、复现路径、发生在哪个环节？

Layer 1: 系统边界二分
  → 一条 curl/MCP 调用把问题空间切成两半

Layer 2: 逐层深入
  → 网关 → 服务 → 接口 → 函数

Layer 3: 代码作为最后手段
  → 只有所有系统层面测试都耗尽了才看代码
```

## 实战案例：405 问题排查

**现象**：点击确认授权 → "Request failed with status code 405"

**传统 AI 做法**：搜代码中的 "405" → 读 auth 文件 → 猜测修复

**forensic-bisect 做法**（3 分钟，0 行代码）：
```bash
# Layer 1: MCP 服务端 vs 授权页面
curl MCP auth_login → 200 ✅ → MCP 正常，问题在 admin.wandox.com

# Layer 1: nginx vs 应用
curl POST admin.wandox.com/api/v1/auth/login → 405
curl POST ai-api.wandox.com/api/v1/auth/login → 422 ✅
→ nginx 拦截了 POST /api/v1/*

# 结论: nginx 配置问题
```

## 安装

```bash
git clone https://github.com/YOUR_USERNAME/forensic-bisect.git
cd forensic-bisect
bash install.sh        # macOS / Linux / WSL
# 或
.\install.ps1          # Windows PowerShell
```

安装到 `~/.claude/skills/forensic-bisect/`（Claude Code）或 `~/.hermes/skills/forensic-bisect/`（Hermes）。

## 与 systematic-debugging 的关系

- **forensic-bisect**：找问题在哪（系统层面，二分法定位）
- **systematic-debugging**：修问题是什么（代码层面，根因修复）

先用 forensic-bisect 定位组件，确认后在代码内部则切换到 systematic-debugging。

---

## License

MIT
