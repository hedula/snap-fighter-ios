# Snap Fighter Worker API

## Endpoints
- `GET /health`
- `POST /analyze`

Request body:
```json
{ "imageBase64": "..." }
```

Response body (MonsterResponse):
```json
{
  "name": "焰冠葉燈騎士",
  "element": "火",
  "hp": 70,
  "atk": 55,
  "def": 35,
  "skill": "燈焰旋風斬"
}
```

`name` keeps a clue from the recognized subject while wrapping it in a JRPG-style title, such as `雷核鍵盤使`, `潮瓶守衛`, or `影牙背包獸`. Generic names like `神秘生物` are normalized into a more game-like fallback before being returned.

## Runtime Config
- Cloudflare Workers AI binding `AI` (required): configured in `wrangler.toml`.
- Default model: `@cf/meta/llama-3.2-11b-vision-instruct`.
- Before first use, you must agree to Meta's license once for this account.
- `RATE_LIMIT_PER_MINUTE` (optional): default `20`.
- `ALLOWED_ORIGINS` (optional): comma-separated allowed browser origins, e.g. `https://example.com,https://app.example.com`. Native app requests without an `Origin` header remain allowed.

## Response Diagnostics
- Successful `POST /analyze` responses include `X-AI-Provider: workers-ai`.
- Successful `POST /analyze` responses include `X-AI-Model: @cf/meta/llama-3.2-11b-vision-instruct`.
- Worker logs include success records under `[workers_ai_analyze_success]`.
- If Workers AI returns malformed or truncated JSON on the first attempt, the worker automatically retries once with a stricter JSON-only prompt.

## Deploy
1. `cd worker`
2. `npx wrangler login`
3. Agree to the Meta license once:
   `curl https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/ai/run/@cf/meta/llama-3.2-11b-vision-instruct -X POST -H "Authorization: Bearer $CLOUDFLARE_AUTH_TOKEN" -d '{ "prompt": "agree" }'`
4. (optional) `npx wrangler secret put RATE_LIMIT_PER_MINUTE`
5. (optional) `npx wrangler secret put ALLOWED_ORIGINS`
6. `npx wrangler deploy`
7. Copy deployment URL and set Xcode build setting `INFOPLIST_KEY_WORKER_ANALYZE_ENDPOINT`

## Quick Verify
```bash
curl -i https://<your-worker>/health
curl -i -X POST https://<your-worker>/analyze -H 'Content-Type: application/json' -d '{"imageBase64":"<BASE64>"}'
```
