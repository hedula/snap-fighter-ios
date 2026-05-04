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

## Deploy
1. `cd worker`
2. `npx wrangler login`
3. `npx wrangler secret put HF_TOKEN`
4. (optional) `npx wrangler secret put HF_MODEL`
5. `npx wrangler deploy`
6. Copy deployment URL and set `Snap Fighter/Config.swift` `workerAnalyzeEndpoint`
