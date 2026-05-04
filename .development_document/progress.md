# Development Progress

## Phase: Build/Test Camera Error Fix (2026-05-04)
- 問題: 在 Simulator 進行 build/test 時出現 AVFoundation runtime error (`-11800`, underlying `-12782`)。
- 原因: 測試環境仍嘗試啟動相機 capture session，模擬器環境可能回報 runtime failure。
- 修正: `CameraView` 在 `targetEnvironment(simulator)` 下強制使用 `PHPickerViewController`，避免啟動 `UIImagePickerController(.camera)`。
- 影響: 實機維持拍照流程；模擬器改為相簿選圖，降低測試噪音與失敗風險。
