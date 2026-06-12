# VS Code 启动失败 + 反复弹出更新框（Windows InnoSetup Mutex 模式）

## 现象

- VS Code 双击无反应
- 或不定时弹出安装/更新对话框
- 日志显示：`checkInnoSetupMutex: vscode-updating is held, waiting up to 30s...`
- 最终报错：`Error: Code is currently being updated. Please wait for the update to complete before launching.`

## Layer 1 — 系统边界二分

这个问题的二分点是：**VS Code 进程 vs 安装器进程**。

| 切法 | 命令 | 预期 |
|------|------|------|
| 刀 1: 检查 VS Code 日志 | 读 `%APPDATA%/Code/logs/<latest>/main.log` | 看到 `checkInnoSetupMutex` 报错 |
| 刀 2: 检查僵尸安装进程 | `Get-Process *CodeSetup*` | 看到 CodeSetup-stable-*.exe 僵尸 |
| 刀 3: 检查更新残留 | 看 VS Code 安装目录 | 看到 `new_Code.exe`、`ffa3c3f656/` 等残留 |

如果刀 2 找到僵尸进程 → 确认是安装器卡死，不是 VS Code 本身的问题。

## 根因

VS Code Windows 版使用 InnoSetup 安装器。更新流程：

```
VS Code 检测新版本 → 下载 → 启动 CodeSetup-stable-*.exe
  → CodeSetup 创建 Windows Mutex "vscode-updating"
    → 替换文件 → 释放 Mutex → VS Code 重启
```

若 CodeSetup 卡死（权限不足、被安全软件拦截、网络中断），Mutex 永不释放。后续每次 VS Code 启动都检测到 Mutex 仍被持有 → 拒绝启动 → 弹出安装框。

## 修复（两步）

### 1. 治标：杀僵尸 + 清理残留

```powershell
# 杀所有 CodeSetup 僵尸进程
Get-Process *CodeSetup* | Stop-Process -Force

# 清理更新残留（在 VS Code 安装目录下）
Remove-Item new_Code.exe, new_Code.VisualElementsManifest.xml, is-*.tmp -Force
Remove-Item <新版本目录> -Recurse -Force  # 如 ffa3c3f656/
```

### 2. 治本：关闭自动更新

在 `%APPDATA%/Code/User/settings.json` 添加：
```json
"update.mode": "none"
```

## 诊断命令速查

```powershell
# 查看僵尸安装进程
Get-Process | Where-Object {$_.ProcessName -like '*CodeSetup*'}

# 查看 VS Code 最新日志
Get-ChildItem "$env:APPDATA/Code/logs" | Sort-Object Name -Desc | Select-Object -First 1 | ForEach { Get-Content "$($_.FullName)/main.log" -Tail 20 }

# 查看更新残留
Get-ChildItem "$env:LOCALAPPDATA/Programs/Microsoft VS Code" | Where-Object { $_.Name -notmatch '^[0-9a-f]+$' -and $_.Name -ne 'bin' -and $_.Name -ne 'Code.exe' }
```

## 为什么是 forensic-bisect 案例

全程 0 行代码阅读。3 个检查（日志 → 进程 → 文件）定位问题，不碰 VS Code 源码。这是典型的「系统边界二分优先」案例——问题出在安装器层，不在代码层。
