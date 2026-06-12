# Auth Debugging Case Studies

Two real-world auth debugging sessions using Layer 1 binary-search.

---

## Case 1: 405 Method Not Allowed on Authorization (2026-05-29)

**Phenomenon:** wandox-work Electron app → click authorize → browser auth page opens → click confirm → "Request failed with status code 405"

**Layer 0 — Confirm:**
- Error: `Request failed with status code 405`
- Stable repro: every auth attempt
- Component: browser page on `admin.wandox.com`

**Layer 1 — Bisect #1: MCP server vs auth page**

```
curl POST ai-api.wandox.com/mcp/admin/mcp (auth_login)
  → 200, returns verification_uri ✅
→ MCP server works, problem is on admin.wandox.com
```

Eliminated 50% of the problem space with one curl.

**Layer 1 — Bisect #2: nginx vs application**

```
curl POST admin.wandox.com/api/v1/auth/login → 405 (nginx/1.19.6)
curl GET  admin.wandox.com/api/v1/auth/login → 200 (SPA HTML)
curl POST ai-api.wandox.com/api/v1/auth/login → 422 (param validation, correct)

→ nginx on admin.wandox.com blocks POST /api/v1/*
→ GET returns SPA fallback, POST returns 405 from nginx
```

**Conclusion:** `admin.wandox.com` nginx config stops proxying `POST /api/v1/*` to `ai-api.wandox.com`. Server-side issue.

**Key technique:** The bisect is simple — one endpoint, two domains, GET vs POST. Three curls total, zero lines of code read.

**Document:** Full report at `docs/troubleshooting/2026-05-29-auth-405-report.md`

---

## Case 2: "Auth confirmed but no token received" (2026-06-02)

**Phenomenon:** wandox-work Electron app → authorize → browser confirm → "Auth confirmed but no token received, please retry"

**Layer 0 — Confirm:**
- Error: `Auth confirmed but no token received, please retry`
- Source: `wandox-mcp-client.ts` `resolveAuthToken()` — token extraction failed
- Stable repro

**Layer 1 — Bisect #1: Is the MCP server reachable?**

```
curl GET ai-api.wandox.com/mcp/admin/mcp
  → 200 (text/event-stream)
  → NO mcp-session-id header (changed from previous behavior)
```

Server is reachable but no longer returns session IDs.

**Layer 1 — Bisect #2: Does MCP work without session?**

```
POST initialize → 200, valid response
POST auth_login → 200, returns device_code
POST auth_status → 200, returns "已登录"
POST tools/call list_playbooks → 200 (requires domain arg, but auth works)
```

All MCP calls work WITHOUT session and WITHOUT token. Server v1.27.1 is session-less.

**Layer 2 — Drill down: Where does the error come from?**

Code flow in `resolveAuthToken()`:
1. `auth_status` returns `{ content: "已登录" }` — plain text, no `auth_token` field
2. `extractToken()` returns `undefined` (no `auth_token` key)
3. Fallback: `sessionId` is `null` (server doesn't return sessions)
4. Falls through to `throw ERR_AUTH_NO_TOKEN`

**Root cause:** Server v1.27.1 changed from session-based to session-less MCP. The client's `resolveAuthToken()` requires either an explicit token or a session ID — both are now absent.

**Fix:** Add third fallback — if `auth_status` succeeded but no token and no session, mark as authenticated anyway (server doesn't need tokens):

```typescript
// Fallback: status-only auth (server v1.27.1+ doesn't use sessions or tokens)
cacheToken("authenticated", domain, DEFAULT_TOKEN_EXPIRES)
return "authenticated"
```

**Key technique:** The bisect is testing whether the MCP server still requires sessions. One curl to `auth_login` without session header → works → server is session-less → code path mismatch identified.
