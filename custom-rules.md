# Custom Rules

貼進編輯器的 custom instructions。這裡只寫**與 `AGENTS.md` 不同**的個人偏好；
專案通則、驗證指令、文件規範一律以 `AGENTS.md` 為準，不要在這裡重複。

開始工作前，先讀 `./AGENTS.md` 並依其 Read First 順序取得脈絡。

## Communication

- 回應語言：繁體中文（技術名詞、檔名、指令保留英文原文）
- 詳細程度：先給結論，再列變更與驗證結果；不要逐步敘述過程
- 不確定時直接說不確定，不要用推測填補

## Development

- 主要技術棧：SwiftUI（iOS）、TypeScript（Cloudflare Worker）、靜態 HTML（promo-site）
- 命名偏好：Swift 用專案既有慣例；文件用 `lower_snake_case.md`
- 每次變更後，執行 `AGENTS.md` Validation 段落中對應範圍的最窄指令

## Boundaries

- 不要：重新命名 Xcode project、app target、bundle identifier、原始碼資料夾
- 不要：把 `Snap Fighter` 當成使用者可見的產品名（產品名是 `攝靈者卡牌`）
- 不要：把 Codex 換成 Copilot（workshop 文案固定為「Xcode 和 Codex」）
- 不要：改動 `.development_document/6_changelog/` 既有條目
- 先問再做：刪除檔案、大範圍重構、變更 `.gitignore`、動到 `worker/` 的 secret 設定

## Additional rules

- `.development_document/source/` 是素材區，體積很大，不要遞迴讀取
- `.development_document/source/workspace/` 是要發給學員的**空白結構範本**，空白是刻意的，不要幫它填內容
- `progress.md` 是已淘汰的舊日誌，不要在裡面新增紀錄
