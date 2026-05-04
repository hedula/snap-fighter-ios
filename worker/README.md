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
  "name": "葉尖火精",
  "element": "火",
  "hp": 70,
  "atk": 55,
  "def": 35,
  "skill": "火葉旋風：用旋轉的葉片釋放火焰攻擊敵人"
}
```

## Runtime Config
- `HF_TOKEN` (required): Hugging Face token with Inference Providers permission.
- `HF_MODEL` (optional): default `openai/gpt-oss-120b:fastest`.
- `RATE_LIMIT_PER_MINUTE` (optional): default `20`.
- `ALLOWED_ORIGINS` (optional): comma-separated allowed origins, e.g. `https://example.com,https://app.example.com`.

## Deploy
1. `cd worker`
2. `npx wrangler login`
3. `npx wrangler secret put HF_TOKEN`
4. (optional) `npx wrangler secret put HF_MODEL`
5. (optional) `npx wrangler secret put RATE_LIMIT_PER_MINUTE`
6. (optional) `npx wrangler secret put ALLOWED_ORIGINS`
7. `npx wrangler deploy`
8. Copy deployment URL and set Xcode build setting `INFOPLIST_KEY_WORKER_ANALYZE_ENDPOINT`

## Quick Verify
```bash
curl -i https://<your-worker>/health
curl -i -X POST https://<your-worker>/analyze -H 'Content-Type: application/json' -d '{"imageBase64":"<BASE64>"}'
```
