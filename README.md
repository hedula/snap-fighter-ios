# 攝靈者卡牌 iOS

攝靈者卡牌是一個 iOS Workshop 範例專案。玩家可以拍照或選取照片，交給 AI 分析後生成怪獸卡牌，再進入對戰。

Repository:
`https://github.com/hedula/snap-fighter-ios.git`

## 教材下載

建議學員使用以下任一方式取得專案：

```bash
git clone https://github.com/hedula/snap-fighter-ios.git
cd snap-fighter-ios
```

如果不使用 Git，也可以直接在 GitHub 頁面點選 `Code` -> `Download ZIP` 下載。

## 環境需求

- macOS
- Xcode 26 以上
- iOS 17.0 以上模擬器或實機
- Swift 5

已驗證的專案設定：

- iOS Deployment Target: `17.0`
- Swift Version: `5.0`
- App target: `Snap Fighter`

## 如何開啟專案

1. 使用 Xcode 開啟 [Snap Fighter.xcodeproj](/Users/hedula/Workspace/snap_fighter_demo/Snap%20Fighter/Snap%20Fighter.xcodeproj)
2. 選擇 `Snap Fighter` target
3. 選擇 iPhone 模擬器或實機
4. 按下 Run

## Workshop 建議操作流程

這個 repo 目前可直接作為教材入口使用，因為 app 已內建預設分析端點：

- 預設 API endpoint: `https://snap-fighter-ai.hedula.workers.dev/analyze`
- app 啟動後可先使用「快速開戰」直接試玩
- 也可使用「拍照抓怪」或「使用照片」進行 AI 分析

如果課堂時間有限，建議先讓學員完成：

1. 開啟專案並成功執行 app
2. 使用「快速開戰」熟悉流程
3. 再進入拍照抓怪與卡牌對戰

## AI 分析與 Worker 設定

app 會從 Info.plist build setting `WORKER_ANALYZE_ENDPOINT` 讀取 API 位址；目前專案已設定預設值。

如果你要改成自己的 Worker：

1. 先部署 [worker](/Users/hedula/Workspace/snap_fighter_demo/Snap%20Fighter/worker)
2. 將部署後的 `/analyze` URL 設定到 Xcode build setting `INFOPLIST_KEY_WORKER_ANALYZE_ENDPOINT`

Worker 詳細部署方式請見 [worker/README.md](/Users/hedula/Workspace/snap_fighter_demo/Snap%20Fighter/worker/README.md)

## 專案結構

- [Snap Fighter](/Users/hedula/Workspace/snap_fighter_demo/Snap%20Fighter/Snap%20Fighter): iOS app
- [worker](/Users/hedula/Workspace/snap_fighter_demo/Snap%20Fighter/worker): Cloudflare Worker API
- [Snap FighterTests](/Users/hedula/Workspace/snap_fighter_demo/Snap%20Fighter/Snap%20FighterTests): 單元測試
- [Snap FighterUITests](/Users/hedula/Workspace/snap_fighter_demo/Snap%20Fighter/Snap%20FighterUITests): UI 測試

## 備註

這個 repo 目前只有一份主專案，尚未另外拆分為 `starter` 與 `completed` 兩個版本。若主辦單位明確要求「範例專案」與「完成版專案」分開提供，建議後續再補兩份分支或資料夾版本。
