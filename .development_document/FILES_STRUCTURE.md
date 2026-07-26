---
ID: 00.00.01
Slug: files-structure
Title: 開發文件資料夾結構
Ref: [00.00.02]
Date: 20260726
---

# Snap Fighter 開發文件資料夾結構

本文件定義 `.development_document/` 的目錄用途、檔案命名規則與 metadata 規範。檔名優先承載語意，Metadata ID 負責穩定引用與機器檢查。不要只用數字 ID 當檔名。

導航入口是 `index.md`，本文件只講規則。

## 實際目錄結構

以下為目前實際存在的結構：

```txt
Snap Fighter/
├── AGENTS.md                            # AI 工作規則（專案層）
├── custom-rules.md                      # 個人偏好，只寫與 AGENTS.md 不同的部分
├── .skills/                             # 可重用工作流程 skill
├── .memory/                             # 短期工作記憶
└── .development_document/
    │
    ├── index.md                         # 文件導航入口（先讀這份）
    ├── FILES_STRUCTURE.md               # 本文件：目錄與命名規則
    ├── progress.md                      # 已淘汰的舊時序日誌，只增不改
    │
    ├── 0_context/                       # 地基：靜態背景與規格，幾乎不變
    │   ├── current_project_status.md    # 專案現況唯一權威來源
    │   ├── snap_fighter_battle_hud_spec.md
    │   ├── testflight_playtest_release_guide.md
    │   ├── hf_router_model_compatibility.json
    │   └── workers_ai_migration.json
    │
    ├── 1_decisions/                     # 規範：架構決策（ADR），變動時才更新
    │   ├── _template.md
    │   ├── 2026-07-01_worker_as_single_ai_backend.md
    │   └── 2026-07-20_client_side_ai_provider_router.md
    │
    ├── 2_workflows/                     # 流程：可重複執行的程序與驗收門檻
    │   └── definition-of-done.md
    │
    ├── 3_plan/                          # 策略：路線圖與下一階段方向
    │   ├── 2026-07-10_snap_fighter_rebuild_plan.md
    │   ├── huggingface_inference_migration_plan.md
    │   ├── snap_fighter_phase1_battle_decision_tasklist.md
    │   └── snap_fighter_product_improvement_plan.md
    │
    ├── 4_task/                          # 執行：任務拆解、交接、檢查清單
    │   └── _template.md
    │
    ├── 5_study/                         # 研究：技術筆記、驗證報告、UI QA 截圖
    │   ├── 2026-07-10_producer_validation.md
    │   ├── 2026-07-26_dev_document_template_gap_review.md
    │   └── 2026-07-15_snap-fighter-*-qa/    # 每次 QA 一個資料夾，內含截圖
    │
    ├── 6_changelog/                     # 紀錄：已完成變更歷史，扁平結構，只增不改
    │   ├── _template.md
    │   └── YYYY-MM-DD_<topic>.md
    │
    ├── temp/                            # 暫存草稿，不可視為已接受的事實
    │
    └── source/                          # 宣傳素材、截圖、影片與外部輸入素材
```

## 建議補齊（目前尚未建立）

以下檔案在本專案還沒有，但在文件成熟時值得補上。不要把它們當成已存在的檔案引用：

- `0_context/tech-stack.md` — 技術棧與版本
- `0_context/architecture.md` — 系統架構全景（App / Worker / promo-site 三者關係）
- `0_context/coding-standards.md` — SwiftUI 與 Worker 的編碼規範
- `3_plan/roadmap.md` — 長期路線圖
- `4_task/todo.md`、`in-progress.md` — 若改採常駐任務板時使用
- `5_study/troubleshooting.md` — 排查記錄彙整

## 檔案命名規則

### 通用 Markdown 文件

- 使用小寫英文、數字與底線：`lower_snake_case.md`
- 檔名必須能直接看出主題，例如 `snap_fighter_battle_hud_spec.md`
- 避免只用 `03.01.01.md`、`plan.md`、`note.md` 這類缺少語意的名稱
- 主題以 3 到 8 個英文詞為原則，必要時可保留專案慣用詞，例如 `snap_fighter`、`worker`、`testflight`
- 模板檔一律命名為 `_template.md`，底線前綴確保排序在最前面

### 日期型文件（決策、計畫、研究、Changelog）

需要按時間排序的文件使用完整日期加語意化主題：

```txt
YYYY-MM-DD_<short_topic>.md
```

範例：

```txt
1_decisions/2026-07-20_client_side_ai_provider_router.md
3_plan/2026-07-10_snap_fighter_rebuild_plan.md
5_study/2026-07-10_producer_validation.md
6_changelog/2026-07-20_ai_provider_router_and_apple_local_start.md
```

- 日期代表建立、驗證或完成該紀錄的日期
- 全專案只使用 `YYYY-MM-DD_` 一種日期格式，不使用 `YYMMDD-`
- `6_changelog/` 採扁平結構，無子資料夾
- Changelog 只增不改；後續修正請新增條目，不回頭改舊紀錄

### 研究截圖資料夾

`5_study/` 允許以資料夾形式收納同一次研究或 QA 的圖片：

```txt
5_study/YYYY-MM-DD_<topic>-qa/
├── source-design.png
├── implementation-pass1.png
└── full-comparison.png
```

資料夾名稱使用連字號，圖片檔名描述其角色（`source-`、`implementation-`、`*-comparison`）。

### Context 文件

穩定規格與背景文件可不加日期，使用主題名稱：

```txt
0_context/<topic>.md
```

若是某次具體日期的產品、測試或技術狀態快照，也可以使用日期型檔名。

目前專案現況摘要固定放在：

```txt
0_context/current_project_status.md
```

`progress.md` 是舊的 chronological log，不再作為新增開發紀錄的位置。

### Source 素材

`source/` 可保留原始素材名稱。若素材會被文件引用，優先使用可讀名稱，例如：

```txt
source/snap-fighter-banner.png
source/snap-fighter-icon.png
```

## Metadata 規範

### 適用範圍（分級）

| 目錄 | frontmatter |
| --- | --- |
| `.development_document/` 根層文件 | **必填** |
| `0_context/` | **必填** |
| `1_decisions/` | **必填**（另加 `Status` 欄位） |
| `2_workflows/` | **必填** |
| `3_plan/` | **必填** |
| `4_task/` | 選填 |
| `5_study/` | 選填 |
| `6_changelog/` | 選填 |

必填目錄的新文件一律加上 frontmatter；既有 changelog 不回頭補。

### 欄位格式

```yaml
---
ID: 03.01.01
Slug: snap-fighter-rebuild-plan
Title: Snap Fighter 重製規劃書
Ref: [00.01.01, 05.01.01]
Date: 20260710
---
```

- `ID`：穩定引用鍵，使用下方 `XX.XX.XX` 編碼；給工具、索引、Ref 使用
- `Slug`：語意化短名稱，使用小寫英文與連字號；給搜尋、摘要、LLM 判讀使用
- `Title`：人類可讀標題，可使用英文或繁體中文
- `Ref`：相關文件 ID 陣列
- `Date`：最後更新日，格式為 `YYYYMMDD`
- `Status`（僅 `1_decisions/`）：`proposed` | `accepted` | `superseded`

### ID 編碼規則

```
XX . XX . XX
│    │    └── 文件序號（該群組內第幾份，從 01 開始）
│    └────── 子群組編號（模組 / 主題，從 01 開始；00 表示目錄本身或根層文件）
└─────────── 目錄編號（見下表）
```

| 目錄 | 編號 |
| --- | --- |
| 根層文件（`index.md`、`FILES_STRUCTURE.md`、`progress.md`） | `00.00` |
| `0_context` | `00`（子群組從 `01` 起） |
| `1_decisions` | `01` |
| `2_workflows` | `02` |
| `3_plan` | `03` |
| `4_task` | `04` |
| `5_study` | `05` |
| `6_changelog` | `06` |
| `source` | `07` |
| `temp` | `08`（暫存，通常不編號） |

### Ref 規則

- 純 ID，不帶路徑（目錄可從第一段編號反推）
- 引用整份文件用完整 ID：`03.01.01`
- 引用目錄層級用 `00` 佔位：`03.00.00` = 整個 `3_plan`

### Date 規則

- 格式：`YYYYMMDD`
- 代表「最後更新日」，每次修改時更新
