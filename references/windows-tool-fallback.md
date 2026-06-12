# Windows: 终端工具的代理干扰与 fallback 模式

## 现象

在 Windows 环境下，当系统代理（如 Clash Verge）开启时，Hermes 的 terminal 和 write_file 工具会失败：

```
terminal 输出：wsl: 无法将 localhost 解析为地址
             /bin/bash: line 2: cd: C:\Users\Eccang: No such file or directory

write_file 输出：同样的 WSL 解析错误 + 路径失败
```

## 根因

Clash Verge 的「系统代理模式」注入 `HTTP_PROXY` / `HTTPS_PROXY` 环境变量，干扰了：

1. **Git Bash (MSYS)** — path translation 依赖这些环境变量为空
2. **WSL 网络解析** — proxy 变量导致 WSL 无法正确解析 localhost

注意：`execute_code` 工具不受影响，因为它直接在 Python 进程内运行，不走 MSYS/WSL 层。

## Fallback 决策树

```
执行命令/写文件
  ├── terminal() 成功 → 继续
  ├── terminal() 输出含 "wsl: 无法将 localhost" → 切换到 execute_code()
  ├── write_file() 失败 → 切换到 execute_code() 内用 Python open() 写文件
  └── read_file() 失败 → 切换到 execute_code() 内用 Python open() 读文件
```

## execute_code fallback 模板

### 替代 terminal

```python
# 原: terminal("git status")
# Fallback:
from hermes_tools import terminal
result = terminal(command='git status', workdir='D:/code/myproject')
# 或者直接用 subprocess:
import subprocess
result = subprocess.run(['git', 'status'], cwd='D:/code/myproject', 
                        capture_output=True, encoding='utf-8', errors='ignore')
```

### 替代 write_file

```python
# 原: write_file(path, content)
# Fallback:
import os
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
```

### 替代 read_file

```python
# 原: read_file(path)
# Fallback:
with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()
```

## 优先级

1. 先用 `execute_code` 内 `from hermes_tools import terminal` — 如果可用
2. 直接 `open()` / `subprocess.run()` — 纯粹的 Python fallback
3. 不推荐用户手动关代理（太打断流程）

## 根治方案

关闭 Clash Verge 系统代理模式，改用 TUN 模式或手动模式。但排查过程中不要因此中断——先用 fallback 完成诊断，事后再提醒用户。
