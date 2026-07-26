# Current Focus

## Objective

修正 simulator 拍照分析時，Worker endpoint 被 Cloudflare Access 擋下後，app alert 顯示整段 HTML 登入頁的問題。

## Completed

- 已確認 `https://snap-fighter-ai.hedula.workers.dev/analyze` 目前回 `302 text/html`，且 header 為 Cloudflare Access。
- 已讓 `AI_PROVIDER=auto` 在 Worker 回 Cloudflare Access payload 時 fallback 到本機 mock。
- 已讓 Worker/JSON decode 路徑辨識 Cloudflare Access HTML，並用短錯誤摘要取代原始 HTML。
- 已補單元測試覆蓋 Cloudflare Access HTML 偵測與 HTML decode failure 摘要。

## Blockers

- `xcodebuild test -only-testing:'Snap FighterTests'` 未執行成功，因為 shared scheme 的 `TestAction` 未配置 test bundle：`Scheme Snap Fighter is not currently configured for the test action.`

## Next Action

- 若要讓 CLI targeted tests 可跑，需另行配置 `Snap Fighter.xcscheme` 的 test action。

## Evidence

- `curl -I -sS https://snap-fighter-ai.hedula.workers.dev/analyze` -> `HTTP/2 302`, `content-type: text/html; charset=UTF-8`, `www-authenticate: Cloudflare-Access ...`
- `xcodebuild -project 'Snap Fighter.xcodeproj' -scheme 'Snap Fighter' -destination 'generic/platform=iOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build` -> `BUILD SUCCEEDED`
- `xcodebuild -project 'Snap Fighter.xcodeproj' -scheme 'Snap Fighter' -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.5' -derivedDataPath .derivedData test -only-testing:'Snap FighterTests'` -> failed before tests: scheme not configured for test action
