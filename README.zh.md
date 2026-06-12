# forensic-bisect — 现象驱动的二分排查法

> 一个 Claude Code / Hermes skill，将"读错误 → 搜代码 → 读文件 → 改代码"翻转为"看现象 → 系统边界二分 → 逐层深入 → 代码最后看"。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## v0.1.0 新特性

| 特性 | 作用 |
|------|------|
| ⛔ **STOP 硬阻断** | 四项检查清单，完成前禁止调用任何读代码工具 |
| **Layer 1.5** 多根因检测 | 二分失败时自动切换日志栅栏策略（3 个触发信号） |
| **跳过指引** | 5 种不需要走四层框架的场景 |
| **前端/客户端二分** | Layer 1 表新增 6 种前端专项二分切法 |
| **反模式重排序** | 按实际频率降序——"猜根因"排第一 |
| ⏱️ **时间预算** | Layer 0-1 必须在 3 分钟内完成 |
| **无法复现指引** | 哨兵日志策略，不等不猜不改代码 |

---

## 问题

AI 编程 Agent 的默认行为：看到报错 → 搜代码 → 读文件 → 改代码。**这不是成熟开发者的思维。**

## 方案

带硬护栏的结构化排查方法：

```
⛔ STOP: 四项检查 —— 完成前禁止读代码
    ↓
Layer 0: 现象确认
    ↓
Layer 1: 系统边界二分（curl/log/ping，不是代码）
    ↓
Layer 1.5: 多根因检测（二分矛盾时 → 日志栅栏）
    ↓
Layer 2: 逐层深入
    ↓
Layer 3: 代码最后手段
```

---

## 什么时候跳过 forensic-bisect

| 场景 | 为什么跳过 | 做法 |
|------|-----------|------|
| 编译器已指出文件和行号 | 二分多余 | 直接改，验证编译 |
| 用户说"XX 配置错了" | 信任用户 | 验证 → 改 → 验证 |
| 一行改动就能验证 | 改完验证更快 | 改 → 验证，不对就回滚 |
| 已知依赖/版本问题 | 不是代码 bug | 升级/降级 |

**判断标准**：从现象到根因 ≤ 2 步，不进 forensic-bisect。

---

## 核心反模式（按频率降序）

| # | 反模式 | 正确做法 |
|---|--------|---------|
| 1 | 「我猜问题大概是...」——还没做 Layer 1 就假设 | 猜测 ≠ 排查。curl/log/ping 先 |
| 2 | 看到报错就 search_files/read_file | 先 Layer 0 写出错误原文 |
| 3 | 改了 ≥2 个文件还没解决 | 你跳过了二分。停止，回到 Layer 1 |
| 4 | 一次改多处 | 改 A → 测。改 B → 测。不混在一起 |
| 5 | 不加诊断日志直接改代码 | 一行 log 验证假设，再改 |

---

## 实战案例：405（3 分钟，0 行代码）

```bash
# Layer 1: MCP 服务端 vs 授权页面
curl MCP auth_login → 200 ✅ → MCP 正常，问题在 admin

# Layer 1: nginx vs 应用
curl POST admin.wandox.com/api/v1/* → 405
curl POST ai-api.wandox.com/api/v1/* → 422 ✅
→ nginx 拦截了 POST /api/v1/*

# 结论: nginx 配置问题
```

## 实战案例：Electron IPC 三根因（多根因模式）

```bash
# 现象：task 状态更新有时不刷新（30% 复现率）

# Layer 1 二分 → 矛盾结果：
#   主进程发出了 ✅，渲染层有时收到有时收不到 ❓

# 进入 Layer 1.5 → 三层日志栅栏：
#   [MAIN] emit id=1 ✅ → [BRIDGE] forward ✅ → [COMPONENT] received ✅
#   [MAIN] emit id=2 ✅ → [BRIDGE] forward ❌         (bridge 丢事件)
#   [MAIN] emit id=3 ✅ → [BRIDGE] forward ✅ → [COMPONENT] received ❌ (unmount)
#   [MAIN] emit id=4 ❌                                (pool 死锁)

# → 一次日志跑出 3 个独立根因
```

---

## 安装

```bash
git clone https://github.com/webster-yuan/forensic-bisect.git
cd forensic-bisect
bash install.sh        # macOS / Linux / WSL
# 或
.\install.ps1          # Windows PowerShell
```

安装到 `~/.claude/skills/forensic-bisect/`（Claude Code）或 `~/.hermes/skills/forensic-bisect/`（Hermes）。

## 与 systematic-debugging 的关系

- **forensic-bisect**：找问题在哪（系统层面，二分法定位）
- **systematic-debugging**：修问题是什么（代码层面，根因修复）

---

## License

MIT
