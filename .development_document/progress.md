# Development Progress

## Phase: Build/Test Camera Error Fix (2026-05-04)
- 問題: 在 Simulator 進行 build/test 時出現 AVFoundation runtime error (`-11800`, underlying `-12782`)。
- 原因: 測試環境仍嘗試啟動相機 capture session，模擬器環境可能回報 runtime failure。
- 修正: `CameraView` 在 `targetEnvironment(simulator)` 下強制使用 `PHPickerViewController`，避免啟動 `UIImagePickerController(.camera)`。
- 影響: 實機維持拍照流程；模擬器改為相簿選圖，降低測試噪音與失敗風險。

## Phase: API Response Parsing Hardening (2026-05-04)
- 問題: 畫面顯示「API 回傳格式錯誤」，但實際錯誤被吞掉，無法判斷是 key/model/quota 或 response 格式差異。
- 修正:
  - 非 200 時解析 `error.message` 並顯示 `API 錯誤：...`。
  - `message.content` 同時支援字串與陣列（`[{type:"text",text:"..."}]`）。
- 效果: 能正確揭露 API 端錯誤，並提升相容性避免誤判格式錯誤。

## Phase: Card Shows Captured Image (2026-05-04)
- 需求: 將拍照/上傳圖片放入角色卡片。
- 修正:
  - `Monster` 新增 `capturedImage` 欄位，生成角色時保留來源圖片。
  - `AIService` 在解析成功後把原始圖片帶入 `Monster`。
  - `CardView` 新增卡面圖區，顯示來源圖片於卡片上半部。
- 效果: 抓到角色後、對戰前卡片、結果卡片都能看到原圖。

## Phase: Move AI Calls to Cloudflare Worker (2026-05-04)
- 目標: 改實作 Cloudflare Worker `/analyze`，iOS 改呼叫 Worker，移除 App 端明文 API Key，維持原本 `MonsterResponse`。
- 修正:
  - 新增 `worker/` 專案（`wrangler.toml`, `src/index.ts`, `README.md`），使用 Workers AI vision model 產生怪物 JSON。
  - iOS `AIService` 改為上傳 `imageBase64` 到 `Config.workerAnalyzeEndpoint`。
  - `Config.swift` 移除 OpenAI key 與 endpoint，只保留 Worker endpoint。
  - 維持回傳 schema：`name/element/hp/atk/def/skill`。
- 結果: App 不再直接暴露第三方 AI key，後續可在 Worker 層調整模型與成本。

## Phase: Workers AI License-Gate Fix (2026-05-04)
- 問題: Workers AI 回傳 `5016`，要求先提交 `agree` 以接受 llama-3.2-11b-vision-instruct 授權條款。
- 修正: Worker 對模型的 user content 先加入 `"agree"` 文字。
- 效果: 避免授權確認錯誤，恢復模型推論流程。
