# Case Study: 405 Method Not Allowed — 3-Minute Root Cause

## Phenomenon

wandox-work Electron app → click "授权" → browser opens auth page → click "确认授权" → `Request failed with status code 405`

## Layer 0: Confirm

- **Error**: `Request failed with status code 405`
- **Stable**: yes, every auth attempt
- **Where**: browser page at `admin.wandox.com` after confirming authorization

## Layer 1: System Boundary Bisect

### Cut 1: MCP server vs. Auth page

```bash
# Test: can MCP auth_login work?
curl "https://ai-api.wandox.com/mcp/admin/mcp" \
  -H "Content-Type: application/json" \
  -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_login","arguments":{"domain":"yiduo"}},"id":2}'
# → 200 OK, returns verification_uri ✅
# → MCP server works. Problem is on admin.wandox.com.
```

### Cut 2: admin.wandox.com nginx vs. Application

```bash
# Test: POST to admin.wandox.com API
curl -X POST "https://admin.wandox.com/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'
# → 405 Not Allowed (nginx/1.19.6) ❌

# Test: same request to ai-api.wandox.com
curl -X POST "https://ai-api.wandox.com/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'
# → 422 Unprocessable Entity (validation) ✅
# → Application works. nginx is blocking POST.
```

## Layer 2: Drill Down

### Test matrix

| Request | admin.wandox.com | ai-api.wandox.com |
|---------|:--:|:--:|
| GET  /api/v1/auth/login | 200 (SPA HTML) | 405 (GET not allowed) |
| POST /api/v1/auth/login | **405** (nginx) | 422 (validation) |
| POST /api/v1/device-auth/confirm | **405** (nginx) | 401 (no auth) |

### Pattern

```
admin.wandox.com:
  GET  /api/v1/* → 200 (SPA fallback to index.html)
  POST /api/v1/* → 405 (nginx blocks POST)
```

Admin SPA uses relative URLs (`/api/v1/...`), which resolve to `admin.wandox.com`. Nginx rejects POST requests to `/api/v1/*` since the reverse proxy was removed.

## Conclusion

**Root cause**: `admin.wandox.com` nginx configuration changed — reverse proxy for `POST /api/v1/*` → `ai-api.wandox.com` was removed.

**Fix**: Restore nginx reverse proxy or update admin SPA to use absolute `ai-api.wandox.com` URLs.

**Lines of code read**: 0. **Time**: 3 minutes.

## Key Takeaways

1. The bisect cuts eliminated ~500 files of wandox-work source code from consideration
2. Each curl answered a binary question: "is it THIS half or THAT half?"
3. The test matrix made the pattern obvious: GET works, POST doesn't = nginx config
4. Server-side issues look like client bugs — bisecting is the only way to tell
