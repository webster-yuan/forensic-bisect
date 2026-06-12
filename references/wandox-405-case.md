# 实战案例：wandox-work 授权 405 排查

- 日期：2026-05-29
- 方法：forensic-bisect Layer 0-1，全程 0 行代码

---

## 现象

`npm run dev` → 点击授权 → 浏览器授权页弹出 → 点击确认授权 → `Request failed with status code 405`

---

## Layer 0：现象确认

- 错误原文：`Request failed with status code 405`
- 稳定复现：每次授权都触发
- 环节：外部浏览器中打开的 `admin.wandox.com` 页面

---

## Layer 1：系统边界二分

### 第 1 刀：MCP 服务端 vs 授权页面

```bash
# 直连 MCP auth_login 测试
curl MCP initialize → 200 ✅
curl MCP auth_login → 200 ✅ → 返回 verification_uri

结论：MCP 服务正常，问题在 admin.wandox.com
```

### 第 2 刀：nginx vs 应用

```bash
# 对比两个域名
curl POST https://admin.wandox.com/api/v1/auth/login → 405 (nginx)
curl POST https://ai-api.wandox.com/api/v1/auth/login → 422 (参数校验，正常)

结论：admin.wandox.com 的 nginx 拦截了 POST /api/v1/*
```

---

## 结论

`admin.wandox.com` 的 nginx 配置变更，不再将 `POST /api/v1/*` 反向代理到 `ai-api.wandox.com`。全程未读一行 wandox-work 代码。
