# Case Study: wandox-work 授权 405 排查

## 场景

wandox-work Electron 应用，`npm run dev` 后点击授权 → 浏览器弹出授权页 → 点击确认授权 → `Request failed with status code 405`。代码未改动，前几个小时正常。

## Layer 0 — 现象确认

- 错误原文：`Request failed with status code 405`
- 稳定复现：每次授权都触发
- 环节：浏览器中打开的 `admin.wandox.com` 授权页面
- 客户端代码无变更

## Layer 1 — 系统边界二分

### 边界 1：MCP 服务端 vs 授权页面

```
问题空间: [wandox-work 客户端] ─── [MCP 服务端] ─── [admin.wandox.com 授权页]
```

切法：直连 MCP 服务端，绕过客户端和授权页。

```bash
# 1) GET session
curl -s -D - "https://ai-api.wandox.com/mcp/admin/mcp" \
  -H "Accept: text/event-stream"
# → 400 + mcp-session-id: e14fbfaf... ✅ session 获取正常

# 2) POST initialize
curl -s "https://ai-api.wandox.com/mcp/admin/mcp" \
  -H "Content-Type: application/json" \
  -H "mcp-session-id: e14fbfaf..." \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{...},"id":1}'
# → 200, serverInfo: {name: "wandox-platform-admin", version: "1.27.1"} ✅

# 3) tools/call auth_login
curl -s "https://ai-api.wandox.com/mcp/admin/mcp" \
  -H "Content-Type: application/json" \
  -H "mcp-session-id: e14fbfaf..." \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_login","arguments":{"domain":"yiduo"}},"id":2}'
# → 200, verification_uri: "https://admin.wandox.com/device-auth?device_code=..." ✅
```

判定：MCP 全链路正常 → **问题在 `admin.wandox.com`**

### 边界 2：nginx vs 应用（同一域名内进一步二分）

```
问题空间: [admin.wandox.com nginx] ─── [admin.wandox.com 应用] ─── [ai-api.wandox.com API]
```

切法：用 curl 分别测同一个接口的 GET 和 POST，区分 nginx 行为和应用行为。

测试矩阵：

| 请求 | admin.wandox.com | ai-api.wandox.com |
|------|:--:|:--:|
| GET `/api/v1/auth/login` | 200（返回 SPA HTML） | 405（login 需要 POST，正常） |
| POST `/api/v1/auth/login` | **405** ← nginx | 422（参数校验，正常） |
| GET `/api/v1/device-auth/confirm` | 200（返回 SPA HTML） | — |
| POST `/api/v1/device-auth/confirm` | **405** ← nginx | — |
| POST `/api/v1/auth/device/confirm` | **405** ← nginx | 401（"未提供认证信息"）|

判定：`admin.wandox.com` 的 nginx 拒绝所有 `POST /api/v1/*`，`GET /api/v1/*` 正常（作为 SPA fallback）。

## 结论

`admin.wandox.com` 的 nginx 配置问题：之前 `POST /api/v1/*` 有反向代理到 `ai-api.wandox.com`，该代理被移除或修改后，POST 直接返回 405。授权页面的 JS 用相对路径发 POST → nginx 拦截 → 405。

## 关键数据点

- 总耗时：约 5 分钟
- 代码阅读：0 行
- curl 次数：约 8 次
- 使用工具：Python urllib + curl
- 最终定位：nginx 配置文件

## 反模式对比

如果走代码优先路径：
1. `search_files("405")` → 代码里没有 405 字面量 → 无结果
2. 读 `auth.service.ts` → 客户端代码正确调用 `ai-api.wandox.com` → 看不到问题
3. 读 `wandox-mcp-client.ts` → MCP 客户端正常 → 困惑
4. 可能开始猜测并改代码 → 浪费时间

如果走进阶代码路径：
1. `search_files("authorize|auth_login")` → 找到认证流程
2. 追踪 `requestAuthLogin → makeMcpRequest → fetch` → 看起来都正常
3. 可能怀疑 MCP endpoint URL 配置 → 开始改配置 → 仍然不行

两种代码路径都无法定位到 `admin.wandox.com` nginx。只有系统边界二分能一步到位。
