# VS Code 无法启动：InnoSetup 更新僵尸进程

## 现象

双击 VS Code 图标完全无反应，无窗口、无报错弹窗。

## 诊断路径

### Layer 0：确认可执行文件存在

```
%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe
```

存在且大小正常（~200MB），排除文件损坏。

### Layer 1：查日志二分

日志目录：`%APPDATA%\Code\logs\`

最新日志子目录为空（0 个文件），说明 VS Code 启动即崩，连写日志的机会都没有。

找到稍早的日志 `main.log`：

```
checkInnoSetupMutex: vscode-updating is held, waiting up to 30s for setup to finish...
checkInnoSetupMutex: vscode-updating still held after 31455ms, giving up
Error: Code is currently being updated. Please wait for the update to complete before launching.
```

**根因确认**：VS Code 自动更新时 InnoSetup 安装器启动后卡死，僵尸进程一直持有 `vscode-updating` Windows mutex，导致每次启动 VS Code 都以为"更新还在进行中"而拒绝启动。

### Layer 2：定位僵尸进程

PowerShell 查找 CodeSetup 进程：

```powershell
Get-Process | Where-Object {$_.ProcessName -like '*CodeSetup*'} | Select-Object Id, ProcessName
```

返回两个僵尸进程：
```
Id   ProcessName
10760 CodeSetup-stable-ffa3c3f656c8df32d894e5f4d3673284d424205e
48036 CodeSetup-stable-ffa3c3f656c8df32d894e5f4d3673284d424205e.tmp
```

### Layer 3：目录残留确认

VS Code 安装目录下的半成品更新文件：
```
ffa3c3f656/          ← 新版本目录（不完整）
new_Code.exe         ← 待替换的新二进制
is-N0KB8.tmp         ← InnoSetup 临时文件
new_Code.VisualElementsManifest.xml
```

## 修复

```powershell
# 1. 杀僵尸进程（释放 mutex）
taskkill /F /PID 10760
taskkill /F /PID 48036

# 2. 清理半成品更新文件（在 VS Code 安装目录下）
del new_Code.exe
del new_Code.VisualElementsManifest.xml
del is-N0KB8.tmp
rmdir /s /q ffa3c3f656
```

## 关键知识点

- InnoSetup 安装器使用 Windows Named Mutex (`vscode-updating`) 防止并发更新
- 如果安装器进程崩溃/卡死但未释放 mutex，VS Code 会无限期拒绝启动
- 僵尸进程可能表现为 `.tmp` 后缀（安装器先复制自己为 .tmp 再执行）
- 日志目录为空本身就是信号——启动阶段即崩溃，没来得及写日志
- 不需要重装 VS Code，杀进程 + 清理残留即可
