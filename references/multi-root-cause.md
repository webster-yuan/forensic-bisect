# 多根因排查案例

## 场景

当边界二分出现矛盾结果时（例如"事件在主进程发出了，但渲染层**有时**收到有时收不到"），二分法假设的单一故障点不成立。

## 典型信号

| 信号 | 含义 |
|------|------|
| 同一个边界测试，结果不稳定（有时通有时不通） | 时序/竞态 → ≥2 个根因 |
| 二分后两边都"正常"但现象仍然存在 | 根因在二分切点之外 |
| 修了一个地方后现象部分缓解但未消失 | ≥2 个独立根因叠加 |

## 实战：Electron IPC 事件丢失排查

### 现象

用户报告 task 状态更新有时不刷新，刷新概率约 30%。

### Layer 1 二分（发现矛盾）

```
刀 1: 主进程 addEventListener → 事件发出 ✅（日志确认 emit 成功）
刀 2: 渲染进程 handler → 有时执行有时不执行 ❓（不稳定）

矛盾：如果 Layer 1 只切到这里，结论是"问题在渲染层"，
但修了渲染层的 handler 后现象只缓解了 50%。
```

### 进入多根因模式

放弃二分，用三层日志栅栏：

```
Layer A: 主进程 emit 点   → DEBUG: "emitting task-update, taskId=X"
Layer B: preload bridge   → DEBUG: "bridge forwarding task-update, taskId=X"
Layer C: 组件 handler     → DEBUG: "component received task-update, taskId=X"
```

跑一轮收集日志后：

```
taskId=1: Layer A ✅ → Layer B ✅ → Layer C ✅  (正常)
taskId=2: Layer A ✅ → Layer B ❌ → Layer C ❌  (bridge 丢事件)
taskId=3: Layer A ✅ → Layer B ✅ → Layer C ❌  (组件 unmounted)
taskId=4: Layer A ❌                              (pool 死锁)
```

### 定位到三个独立根因

1. **Pool 死锁**：taskId=4 未 emit → `TaskPool.acquire()` 在等待时未处理超时
2. **Preload bridge 丢事件**：taskId=2 → `contextBridge.exposeInMainWorld` 注册时机晚于事件到达
3. **组件 unmount 丢事件**：taskId=3 → 组件在 `useEffect` cleanup 中移除了 listener，但事件在 cleanup 和 remount 之间到达

### 教训

如果坚持二分法「一刀切一半」，会在渲染层来回反复 3 轮才覆盖所有根因。
日志栅栏一次跑出全链路数据，直接定位所有断裂点。

## 操作清单

进入多根因模式后：

- [ ] 列出所有可疑边界（≥3 个）
- [ ] 在每个边界插入 DEBUG 日志，格式统一：`[LAYER-X] event=Y, id=Z, status=PASS/FAIL`
- [ ] 运行一次完整流程，收集全链路日志
- [ ] 在日志中标注 PASS/FAIL，画链路断裂图
- [ ] 每个断裂点单独分析根因
- [ ] 不要修完一个就以为修好了——跑全链路日志确认所有断裂点都修复
