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

## Deploy
1. `cd worker`
2. `npx wrangler login`
3. `npx wrangler deploy`
4. Copy deployment URL and set `Snap Fighter/Config.swift` `workerAnalyzeEndpoint`
