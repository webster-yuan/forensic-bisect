---
name: forensic-bisect
description: >-
  现象驱动的二分排查法。Use when debugging errors, diagnosing failures,
  tracing request chains, or isolating system boundaries. 从系统边界逐层切入，
  curl/MCP/API 先定位问题所在方，代码是最后手段。与 systematic-debugging 互补。
---

# forensic-bisect — 现象驱动的二分排查法

## 激活时机

当你看到以下关键词时自动加载此技能：
- 错误/报错/失败/异常 (error/exception/failure)
- 排查/调试/诊断 (debug/diagnose/troubleshoot)
- 请求链/调用链/边界 (request chain/boundary/isolate)
- curl/MCP/API 测试

---

## ⛔ STOP — 硬阻断

**在读任何文件、调用任何代码搜索工具之前，你必须先完成以下四项：**

- [ ] 错误原文已确认（一字不差地引用）
- [ ] 复现路径已写出（1-2-3 步骤，用户能照着复现）
- [ ] 系统架构边界已画出（≥3 层：前端/网关/后端/DB/第三方）
- [ ] 第一个二分切点已选定（用 curl / log / ping / tasklist / 进程检查，**不是用代码**）

**如果以上四项有任何一项未完成，你就调用了 read_file / search_files / execute_code（以分析代码为目的）——你跳过了 Layer 1。立即停止，回到现象。**

> 「先分析再动手」不是建议。是纪律。

---

## ⏭️ 什么时候跳过 forensic-bisect

**不是所有报错都值得走四层框架。** 以下场景直接修复，跳过二分：

| 场景 | 为什么跳过 | 做法 |
|------|-----------|------|
| 语法/拼写/类型错误（编译器已指出文件和行号） | 二分无意义，根因已定位 | 直接改，验证编译通过 |
| 用户明确说了根因（「XX 配置写错了」） | 信任用户判断 | 验证配置 → 修复 → 验证 |
| 改一行就能验证的修复 | 改完验证比二分排查更快 | 改 → 验证，不对再回滚 |
| 已知的依赖/版本问题 | 是公告级问题，不是代码 bug | 升级/降级版本 |
| 一次性的脚本/临时操作 | 不值得投入排查时间 | 最小修改，快速验证 |

**判断标准**：如果从现象到根因的路径 ≤ 2 步（比如编译器告诉你文件+行号），不进 forensic-bisect。

---

## 核心理念

**成熟的开发者从现象出发，用系统边界二分逐层定位，代码是最后的武器。**

大多数 AI Agent 排查问题的默认行为是：读错误 → 搜代码 → 读文件 → 改代码（代码优先）。
forensic-bisect 翻转这个流程：**现象 → 系统边界二分 → 逐层深入 → 确定组件 → 最后才看代码。**

---

## 四层排查框架

### Layer 0：现象确认

1. 错误原文（一字不差）
2. 复现路径（1-2-3 步骤）
3. 发生在哪个环节？
4. 最早出现的信号？

### Layer 1：系统边界二分

一条 curl / MCP 调用 / ping 排除一半可能。

| 问题类型 | 二分切法 |
|---------|---------|
| 前端请求报错 | curl 直接调后端 API |
| 后端报错 | curl 绕过网关直连服务 |
| DB 问题 | 直接 DB 客户端连接 |
| 第三方服务 | curl 直接调第三方 API |
| 认证问题 | 拿 token 直接 curl 受保护接口 |
| 多服务调用链 | 逐段 curl，找第一个断点 |
| AI 模型响应慢 | 对比不同模型同任务延迟，排除 prompt 大小因素 → `references/deepseek-latency-comparison.md` |
| AI Agent 输出异常 | 先加诊断日志确认上游 API 返回的原始数据结构（part type、messageId），再对比竞品 UI 的处理方式 → `references/thinking-conclusion-lastTextPartId.md` |
| 桌面应用无法启动（静默失败） | 查安装目录确认 exe 存在 → 查日志（空目录也是信号）→ 找 mutex/锁文件/僵尸进程 → 杀进程+清残留 → `references/vscode-stuck-update.md` |
| Electron 控制台中文乱码 | 二分：日志文件 vs 终端显示 → 日志正常则排除解码逻辑，确认是 stdout 编码问题 → `references/electron-gbk-encoding.md` |
| VS Code 启动失败/反复弹更新框 | 二分：VS Code 进程 vs 安装器进程 → 日志 + 进程列表 → 确认 InnoSetup Mutex 僵尸 → `references/vscode-auto-update-zombie.md` |
| AI Agent 质量下降但上下文远未满（如 20% 就开始退化） | 二分：API 缓存兼容性 vs 上下文注入源膨胀 vs Hooks 碎片化。先查 always-trigger skills + hooks 数量 + AGENTS.md 大小，再确认模型 API 兼容层的 cache_control 支持 → `references/agent-cache-hit-rate.md` |
| 前端渲染异常（白屏/组件不显示） | 二分：纯 HTML vs 框架渲染 → DevTools Elements 确认 DOM 是否存在 → 数据问题还是渲染问题 |
| 状态管理 bug（数据没更新/没反应） | 二分：console.log state → 确认是状态没更新还是组件没 re-render |
| CSS/样式问题 | 二分：DevTools 直接改 CSS → 确认是选择器无效还是变量/主题覆盖 |
| 打包/构建失败 | 二分：二分文件集（先注释一半文件）→ 定位引入问题的文件 |
| 性能/卡顿 | 二分：Profiler 找长任务 → 确认是哪个组件/函数 → 再二分内部逻辑 |

### Layer 1.5：多根因检测

**二分法假设单一故障点。当 Layer 1 结果矛盾时，这个假设可能不成立。**

触发条件（满足任一 → 进入多根因模式）：

| 信号 | 含义 | 例 |
|------|------|-----|
| 同一个边界测试，结果不稳定（有时通有时不通） | 时序/竞态问题 → ≥2 个根因 | "事件在主进程发出了，但渲染层有时收到有时收不到" |
| 二分后两边都显示"正常"但现象还在 | 根因在二分切点之外 → 重新选切点 | "前端改了对的，后端也跑通了，但还是报错" |
| 修了一个地方，现象部分缓解但未消失 | ≥2 个独立根因叠加 | "修了 pool 死锁后概率降低，但未根治" |

**进入多根因模式后的策略**：

1. **放弃"一刀切一半"**——每个可疑边界独立测试，不再追求单次排除 50%
2. **用日志栅栏（fence logging）替代二分**——在每个可能丢失事件/状态的节点插入 DEBUG 日志，跑一轮收集全链路日志
3. **逐层加 log → 逐层排除 → 定位每个独立根因**——本质上仍是"逐层 instrumentation"，只是不再假设只有一层有问题

> 多根因案例见 `references/multi-root-cause.md`

---

### Layer 2：逐层深入

在确定的层内继续二分：网关 → 服务 → 接口 → 函数。

### Layer 3：代码作为最后手段

仅当：
- 已定位到具体函数但无法从外部确定行为
- 算法逻辑错误
- 竞态/时序问题
- 所有测试结果矛盾

---

## 反模式

> 按实际发生频率降序排列。排第一的杀伤力最大。

| 反模式 | 正确做法 |
|--------|---------|
| **「我猜问题大概是 XX」——还没做 Layer 1 就开始假设根因** | 猜测不等于排查。先用 curl/log/ping 确认，再说话 |
| **看到报错就 search_files / read_file** | 先确认现象，在 Layer 0 写出错误原文。代码是 Layer 2+ 的事 |
| **连续改了 ≥2 个不同文件，问题还没解决** | **你跳过了二分步骤。** 停止。回到 Layer 1。在每个边界加诊断日志，不要改第二行代码直到你确认了确切根因 |
| **一次改多处再测试** | 每改一个边界测一次。改 A 测 → 改 B 测 → 不要把 A+B 混在一起验证 |
| "大概看了代码，问题可能在这" | "还没看代码，先 curl/加 log 确认" |
| **一看到报错就调用 code-explorer 或子代理搜索代码库** | ✅ 先用 curl/log/ping 定位组件。code-explorer 是 Layer 2 的工具 |
| 测试成本高时不加诊断日志直接改 | 先加一行 log 验证假设，再改代码 |
| 根据数据结构假设写过滤逻辑 | 先加诊断日志确认实际数据字段 |
| 修完后自己编测试验证，不让用户跑 | 用户验证成本远高于你加一行 log |
| 修了 Page 没修 Hook，另一半路径仍漏 | 共享数据通道 → 两边都要加诊断日志 |
| **二分已确认是服务端问题时，继续改客户端代码** | 定位到服务端 → **停止改代码**，写文档说明改什么，交给用户去对齐 |

---

## 实战案例

### 案例 1：405 授权错误（nginx 拦截 POST）

```
现象: 浏览器授权页点击确认 → Request failed with status code 405

Layer 1 — 二分:
  刀 1: curl MCP auth_login → 200 ✅ → MCP 正常
  刀 2: curl POST admin.wandox.com/api/v1/* → 405（nginx）
        curl POST ai-api.wandox.com/api/v1/* → 422 ✅
  结论: admin.wandox.com nginx 拦截 POST /api/v1/*

全程 3 个 curl，0 行代码。
```

### 案例 2：MCP 认证 "no token received"（服务器架构变更）

```
现象: 授权确认后 "Auth confirmed but no token received"

Layer 1 — 二分:
  刀 1: curl MCP auth_login → 200 ✅ → 服务器可达
  刀 2: 查 response header → 无 mcp-session-id（服务器 session-less）
  刀 3: curl tools/call → 无需 session 也能工作
  结论: 服务器 v1.27.1 改为 session-less，客户端代码仍要求 token

全程 3 个 curl，定位到代码层的 resolveAuthToken 函数。
```

### 案例 3：VS Code 无法启动（InnoSetup 更新僵尸进程）

```
现象: 双击 VS Code 无任何反应，无窗口无报错

Layer 1 — 二分:
  刀 1: 确认 Code.exe 存在且大小正常 → 排除文件损坏
  刀 2: 查日志 %APPDATA%/Code/logs/ → main.log: "checkInnoSetupMutex: vscode-updating is held"
  刀 3: tasklist 找 CodeSetup 进程 → 两个僵尸进程（PID 10760, 48036）
  结论: InnoSetup 更新卡死，mutex 未释放导致 VS Code 拒绝启动

修复: taskkill 杀僵尸进程 + 清理半成品文件（new_Code.exe, ffa3c3f656/）
全程 0 行代码修改。
```

> 详细案例见 `references/vscode-stuck-update.md`

### 案例 4：思考文字泄漏到结论区（text 累积问题）

```
现象: 剧本任务详情页，模型规划文字混入最终结论

Layer 1 — 二分:
  刀 1: 加诊断日志 → type="reasoning" 40 条, type="text" 38 条
        → 泄漏的是 text，不是 reasoning
  刀 2: 对比 DeepSeek Web UI → 每轮 text 独立展示
        → 根因：前端累积所有轮次 text delta
  修复: delta handler 按 text part ID 过滤，只保留最新 text part
```

> 详细案例见 `references/auth-debug-case-studies.md`

---

## 与 systematic-debugging 的关系

- **forensic-bisect**：找问题在哪（系统层面，二分法定位组件）
- **systematic-debugging**：修问题是什么（代码层面，根因修复）

先用 forensic-bisect 定位组件，确认后在代码内部则切换到 systematic-debugging。

---

## 启动检查清单

- [ ] 错误原文已拿到
- [ ] 复现路径已明确
- [ ] 系统架构边界已画出（≥3 层）
- [ ] 第一个二分切点已选定
- [ ] 还没读任何代码文件
- [ ] ⏱️ Layer 0-1 在 3 分钟内完成。超时 = 你可能在分析而不是排查

## 无法复现时怎么办

如果用户报告的现象**无法稳定复现**：

1. **不要猜。不要改任何代码。** 未复现的修复 = 赌博。
2. 在可疑点加**哨兵日志**（`console.warn` / `logger.warn`，不是临时 DEBUG log）：`[SENTINEL] event=X, state=Y`。哨兵日志应该是持久化的，不是用完就删的。
3. 告诉用户：「我在 X、Y、Z 三处加了哨兵日志。下次出现时把日志发我。」
4. 关闭当前排查。等待下次触发——没有证据的修复比不修复更危险。
5. 哨兵日志触发后，从 Layer 1 重新开始——这次有数据了。
