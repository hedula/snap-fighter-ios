---
ID: 00.00.01
Slug: files-structure
Title: Snap Fighter 開發文件資料夾結構
Ref: [00.00.00]
Date: 20260721
---

# Snap Fighter 開發文件資料夾結構

本文件定義 `.development_document/` 的目錄用途、檔案命名規則與 metadata 規範。檔名優先承載語意，Metadata ID 負責穩定引用與機器檢查。不要只用數字 ID 當檔名。

```txt
Snap Fighter/
└── .development_document/
    ├── 0_context/                       # 穩定背景、產品現況、規格與技術上下文
    │   ├── current_project_status.md
    │   ├── snap_fighter_battle_hud_spec.md
    │   └── testflight_playtest_release_guide.md
    │
    ├── 3_plan/                          # 可執行計畫與重製路線
    │   └── 2026-07-10_snap_fighter_rebuild_plan.md
    │
    ├── 5_study/                         # 研究、驗證、排查與 producer review
    │   └── 2026-07-10_producer_validation.md
    │
    ├── 6_changelog/                     # 已完成變更，只增不改
    │   └── 2026-07-20_ai_provider_router_and_apple_local_start.md
    │
    ├── source/                          # 宣傳素材、截圖、影片與外部輸入素材
    ├── FILES_STRUCTURE.md               # 本文件
    └── progress.md                      # legacy 開發流水帳，只作歷史參考
```

## 檔案命名規則

### 通用 Markdown 文件

- 使用小寫英文、數字與底線：`lower_snake_case.md`
- 檔名必須能直接看出主題，例如 `snap_fighter_battle_hud_spec.md`
- 避免只用 `03.01.01.md`、`plan.md`、`note.md` 這類缺少語意的名稱
- 主題以 3 到 8 個英文詞為原則，必要時可保留專案慣用詞，例如 `snap_fighter`、`worker`、`testflight`

### 日期型計畫、研究與 Changelog

需要按時間排序的文件使用完整日期加語意化主題：

```txt
YYYY-MM-DD_<short_topic>.md
```

範例：

```txt
3_plan/2026-07-10_snap_fighter_rebuild_plan.md
5_study/2026-07-10_producer_validation.md
6_changelog/2026-07-20_ai_provider_router_and_apple_local_start.md
```

- 日期代表建立、驗證或完成該紀錄的日期
- `6_changelog/` 採扁平結構，無子資料夾
- Changelog 只增不改；後續修正請新增條目，不回頭改舊紀錄

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

`progress.md` 是舊的 chronological log，不再作為新增開發紀錄的主要位置。

### Source 素材

`source/` 可保留原始素材名稱。若素材會被文件引用，優先使用可讀名稱，例如：

```txt
source/snap-fighter-banner.png
source/snap-fighter-icon.png
```

## Metadata 規範

每份正式 Markdown 文件開頭建議使用 YAML frontmatter：

```yaml
---
ID: 03.01.01
Slug: snap-fighter-rebuild-plan
Title: Snap Fighter 重製規劃書
Ref: [00.01.01, 05.01.01]
Date: 20260710
---
```

### Metadata 欄位

- `ID`：穩定引用鍵，使用下方 `XX.XX.XX` 編碼；給工具、索引、Ref 使用
- `Slug`：語意化短名稱，使用小寫英文與連字號；給搜尋、摘要、LLM 判讀使用
- `Title`：人類可讀標題，可使用英文或繁體中文
- `Ref`：相關文件 ID 陣列
- `Date`：最後更新日，格式為 `YYYYMMDD`

### ID 編碼規則

```txt
XX . XX . XX
│    │    └── 文件序號（該群組內第幾份，從 01 開始）
│    └────── 子群組編號（模組 / 主題，從 01 開始；00 表示群組本身）
└─────────── 目錄編號（見下表）
```

| 目錄 | 編號 |
| --- | --- |
| `0_context` | `00` |
| `1_decisions` | `01`（保留） |
| `2_manual` | `02`（保留） |
| `3_plan` | `03` |
| `4_task` | `04`（保留） |
| `5_study` | `05` |
| `6_changelog` | `06` |
| `source` | `07` |

### Ref 規則

- 純 ID，不帶路徑（目錄可從第一段編號反推）
- 引用整份文件用完整 ID：`03.01.01`
- 引用目錄層級用 `00` 佔位：`03.00.00` = 整個 `3_plan`

### Date 規則

- 格式：`YYYYMMDD`
- 代表「最後更新日」，每次修改時更新
