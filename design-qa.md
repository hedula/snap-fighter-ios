# Snap Fighter Battle UI Design QA

- source visual truth path: `/Users/hedula/Workspace/snap_fighter_demo/Snap Fighter/.development_document/5_study/2026-07-15_snap-fighter-ui-qa/source-design.png`
- implementation screenshot path: `/Users/hedula/Workspace/snap_fighter_demo/Snap Fighter/.development_document/5_study/2026-07-15_snap-fighter-ui-qa/implementation-390x844.png`
- viewport: iPhone 16e, 390 × 844 pt (1170 × 2532 px at 3×)
- state: quick battle, player turn, round 1, starter main and reserve visible

**Full-view comparison evidence**

- `.development_document/5_study/2026-07-15_snap-fighter-ui-qa/full-comparison-final.png`
- The implementation preserves the selected composition: arcane arena, asymmetric physical-photo cards, enemy nameplate, reserve bookmark, parchment event line, and four-card command hand.
- The source mock is slightly taller than the requested viewport; the implementation resolves the design into the exact 390 × 844 target without clipping or scrolling.

**Focused region comparison evidence**

- `.development_document/5_study/2026-07-15_snap-fighter-ui-qa/command-focus-comparison-final.png`
- The command hand preserves order, fan, color identity, icon family, highlighted skill card, readable titles, and thumb-zone placement.

**Required fidelity surfaces**

- Fonts and typography: system serif display treatment matches the Japanese fantasy tone; Traditional Chinese headings, HP values, event copy, and action labels remain readable at phone scale. No actionable wrapping or truncation remains.
- Spacing and layout rhythm: header, battlefield, event line, and command hand retain the source hierarchy. Exact 390 × 844 capture shows no hidden primary action or horizontal overflow.
- Colors and visual tokens: midnight blue/plum arena, parchment, antique gold, cyan lightning, ember red, and semantic action colors match the selected direction with sufficient contrast.
- Image quality and asset fidelity: four dedicated raster assets are used for the arena and starter card art. Runtime captured photos override fallback art inside the same physical-card frame. No placeholder or code-drawn monster art remains.
- Copy and content: player turn, round, names, levels, HP, event narration, reserve, cooldown, and four commands are present and driven by live battle state.
- Icons and accessibility: SF Symbols provide consistent game-control icons; command cards and reserve are semantic buttons with labels and hints. Tap targets fill the visible cards.

**Comparison history**

- Pass 1 finding [P1]: the external player nameplate overlapped the player card and duplicated its HP information.
  - Evidence: `.development_document/5_study/2026-07-15_snap-fighter-ui-qa/implementation-pass1.png`.
  - Fix: removed the redundant player nameplate and preserved player identity and HP inside the physical card.
- Pass 2 result: overlap removed; card, event, reserve, and command regions are visually separated.
  - Evidence: `.development_document/5_study/2026-07-15_snap-fighter-ui-qa/implementation-pass2.png`.
- Final viewport pass: repeated capture on iPhone 16e at the exact 390 × 844 target; no P0/P1/P2 mismatch remains.
  - Evidence: `.development_document/5_study/2026-07-15_snap-fighter-ui-qa/implementation-390x844.png`.

**Primary interactions tested**

- Entered quick battle and opened the live battle screen.
- Selected the skill card; verified enemy HP update, enemy-action state, disabled command hand, cooldown label, and round increment to round 2.
- Evidence: `.development_document/5_study/2026-07-15_snap-fighter-ui-qa/interaction-round2.png`.
- Full Xcode unit and UI test suite completed successfully.

**Findings**

- No actionable P0/P1/P2 findings remain.

**Follow-up Polish**

- [P3] The source mock uses denser filigree and a feather ornament on the narration strip. The implementation intentionally keeps these details lighter so dynamic photos and Traditional Chinese copy stay legible at 390 pt width.

## Adventure Lobby And Deck Extension

- source visual truth paths:
  - `.development_document/5_study/2026-07-15_snap-fighter-home-deck-qa/selected-battle-direction.png`
  - `.development_document/5_study/2026-07-15_snap-fighter-home-deck-qa/home-baseline.png`
- implementation screenshot paths:
  - `.development_document/5_study/2026-07-15_snap-fighter-home-deck-qa/home-rpg-final.png`
  - `.development_document/5_study/2026-07-15_snap-fighter-home-deck-qa/deck-rpg-final.png`
- viewport: iPhone 16e, 390 × 844 pt (1170 × 2532 px at 3×)
- states: adventure lobby with a ready two-card deck; battle formation with main, reserve, and one unavailable collection card

**Full-view comparison evidence**

- `.development_document/5_study/2026-07-15_snap-fighter-home-deck-qa/full-comparison.png`
- The lobby and formation screen carry forward the selected battle language: midnight arena, antique gold framing, parchment controls, physical-photo cards, strong Chinese display hierarchy, and restrained red for the AI challenge.
- The original lobby information architecture remains intact, but quick battle is now the dominant story entry while capture and deck management are compact secondary missions.

**Focused region comparison evidence**

- `.development_document/5_study/2026-07-15_snap-fighter-home-deck-qa/card-focused-comparison.png`
- The reusable collection card matches the selected physical-card direction through the parchment name rail, double gold border, large photo crop, element badge, level, combat stats, and dark navy footer.

**Required fidelity surfaces**

- Fonts and typography: heavy rounded system display faces provide a Japanese mobile-RPG rhythm while Traditional Chinese copy remains readable. No truncation remains in the navigation bar, mission panels, or card headers.
- Spacing and layout rhythm: both states fit the 390 pt width without horizontal overflow. The lobby keeps one primary story panel and two equal secondary missions; formation uses two stable card columns.
- Colors and visual tokens: the same midnight, parchment, antique gold, element colors, and challenge red now span battle, lobby, deck, and reusable cards.
- Image quality and asset fidelity: existing generated arena and monster artwork are reused without placeholders. Captured user photos still take precedence over fallback artwork in every reusable card.
- Copy and content: quick battle, camera capture, photo import, deck editing, AI challenge readiness, main/reserve roles, collection count, levels, elements, and stats are all live UI state.
- Accessibility and interactions: lobby actions are semantic buttons; selected cards expose their state, full decks disable unavailable choices, long press exposes removal, and the deck sheet retains a clear completion action.

**Comparison history**

- Pass 1 finding [P1]: the lobby brand overlapped the iOS status bar.
  - Evidence: `/tmp/snap-fighter-design/home-rpg-pass1.png`.
  - Fix: added an explicit top safe-area offset to the scroll content.
- Pass 1 finding [P2]: the deck navigation leading status was truncated to `2/...`.
  - Evidence: `/tmp/snap-fighter-design/deck-rpg-pass1.png`.
  - Fix: removed the redundant leading toolbar count; the complete readiness state remains inside the formation panel.
- Final pass: both findings are absent at 390 × 844 and no new P0/P1/P2 mismatch remains.

**Primary interactions tested**

- Quick battle opens the ready-to-battle state.
- The card-count control opens battle formation.
- Formation renders two selected cards, disables a third card at the two-card limit, and exposes removal through the card context menu.
- Xcode build and focused UI/unit tests completed successfully.

**Findings**

- No actionable P0/P1/P2 findings remain.

**Follow-up Polish**

- [P3] Future captured-photo samples can be used to tune subject-safe cropping across unusually wide or tall household objects.

## Summon And Battle Result Rituals

- source visual truth paths:
  - `.development_document/5_study/2026-07-15_snap-fighter-ritual-qa/source-home-language.png`
  - `.development_document/5_study/2026-07-15_snap-fighter-ritual-qa/source-card-language.png`
- implementation screenshot paths:
  - `.development_document/5_study/2026-07-15_snap-fighter-ritual-qa/summon-result-final.png`
  - `.development_document/5_study/2026-07-15_snap-fighter-ritual-qa/battle-result-final.png`
- viewport: iPhone 16e, 390 × 844 pt (1170 × 2532 px at 3×)
- states: one-card summon complete with original artwork selected; battle complete with an uncollected winning card

**Full-view comparison evidence**

- `.development_document/5_study/2026-07-15_snap-fighter-ritual-qa/full-comparison.png`
- Both rituals preserve the selected hierarchy and tokens: midnight arena, gold ceremonial headings, dominant physical card, parchment primary action, and dark secondary action.
- The summon state leads from card reveal to artwork choice and second summon; the result state leads from winner reveal to record/EXP, collection, and return.

**Focused region comparison evidence**

- `.development_document/5_study/2026-07-15_snap-fighter-ritual-qa/action-focused-comparison.png`
- Artwork selection and result actions retain the lobby's button hierarchy, gold selected state, SF Symbol family, corner treatment, contrast, and practical tap sizing.

**Required fidelity surfaces**

- Fonts and typography: bold rounded Traditional Chinese display text, tracked English eyebrow labels, compact metadata, and action labels match the established RPG hierarchy without remaining truncation.
- Spacing and layout rhythm: both screens use the same 20 pt horizontal frame and centered card stage. The primary next action remains visible at the 390 × 844 capture while secondary content scrolls naturally.
- Colors and visual tokens: midnight, parchment, antique gold, element red, mist text, and raised navy surfaces map directly to the lobby, deck, and battle tokens.
- Image quality and asset fidelity: the actual card artwork remains the dominant image. Runtime photos continue to override fallback artwork; no placeholder or code-drawn product imagery is used.
- Copy and content: summon completion, artwork persistence, remaining-card guidance, winner identity, victory record/EXP, collection state, and return path are explicit and driven by app state.
- Icons and accessibility: all controls use SF Symbols and semantic buttons; artwork choices announce selected state, collection announces success, and primary tap targets exceed practical mobile sizing.

**Comparison history**

- Pass 1 finding [P2]: the horizontal artwork-choice buttons truncated `原始照片` and `主體卡圖`.
  - Evidence: `/tmp/snap-fighter-design/capture-result-pass1.png`.
  - Fix: changed each option to a vertical image-and-label card with a dedicated selection row and text scaling guard.
- Final pass: both artwork labels render in full; the action hierarchy and card stage remain stable.
  - Evidence: `.development_document/5_study/2026-07-15_snap-fighter-ritual-qa/summon-result-final.png`.

**Primary interactions tested**

- Switched from original artwork to the subject-card version and verified the selected accessibility state.
- Verified the second-summon action remains available.
- Collected the winning card and verified the action changed to the collected state.
- Returned from battle result to the adventure lobby.
- All 36 unit tests and the focused ritual UI test completed successfully.

**Findings**

- No actionable P0/P1/P2 findings remain.

**Follow-up Polish**

- [P3] A future motion pass could add restrained card-reveal and EXP-count animations with Reduce Motion fallbacks.

## Key-out Ritual And Battle Assembly

- source visual truth: `.development_document/5_study/2026-07-15_snap-fighter-ritual-qa/summon-result-final.png`
- implementation screenshots:
  - `.development_document/5_study/2026-07-15_snap-fighter-keyout-qa/keyout-process.png`
  - `.development_document/5_study/2026-07-15_snap-fighter-keyout-qa/keyout-preview.png`
  - `.development_document/5_study/2026-07-15_snap-fighter-keyout-qa/battle-assembly.png`
- viewport: iPhone 16e, 390 × 844 pt (1170 × 2532 px at 3×)

**Comparison evidence**

- Full flow: `.development_document/5_study/2026-07-15_snap-fighter-keyout-qa/full-comparison.png`.
- Focused key-out states: `.development_document/5_study/2026-07-15_snap-fighter-keyout-qa/keyout-focused-comparison.png`.
- The new processing ritual preserves the established midnight, gold, physical-photo, tracked-eyebrow, and bold Traditional Chinese hierarchy from summon success through battle assembly.

**Required fidelity surfaces**

- Typography and spacing: the four processing phases, progress value, two battle cards, matchup panel, and fixed battle CTA remain readable without horizontal overflow or clipped copy at 390 pt.
- Colors and imagery: source photography stays dominant while gold scanning and mask status communicate processing without placeholder art. Transparent Vision output is presented on the existing navy stage when available.
- States and resilience: subject detection, mask generation, cutout success, no-stable-mask fallback, and card generation are explicit. Reduced Motion disables the repeating scan movement.
- Accessibility: progress stages expose labels, outcome pills expose stable identifiers, and the battle CTA remains a semantic full-width button above the home indicator.

**Comparison history**

- Pass 1 finding [P1]: battle CTA was positioned below the visible safe area.
  - Fix: replaced the inset placement with a bottom overlay inside the established arcane screen and preserved scroll clearance.
- Pass 1 finding [P2]: the no-mask state continued showing the active scanner without explaining the fallback.
  - Fix: stopped the scan in the final phase and added an explicit original-photo fallback status.
- Final pass: no remaining actionable P0/P1/P2 findings.

**Verification**

- Build succeeds on the iPhone 16e simulator destination.
- 37 unit tests pass, including progressive key-out publication and AI cutout/fallback behavior.
- Focused UI flow passes from key-out processing to battle assembly and into the live battle screen.

## Key-out Stall Recovery

- evidence: `.development_document/5_study/2026-07-15_snap-fighter-recovery-qa/recovery-comparison.png`
- viewport: iPhone 16e, 390 × 844 pt
- finding [P1]: the 86% card-generation state previously had no exit or retry action and could look permanently frozen.
- fix: after 10 seconds, the same RPG surface reveals a concise delayed-state explanation plus `取消召喚` and `重新嘗試` actions; both fit above the bottom safe area without obscuring progress.
- resilience: network analysis now times out after 30 seconds with a localized error, while cancelled or superseded attempts cannot publish late results.
- accessibility: both recovery actions are semantic 44 pt buttons with explicit text and SF Symbols.
- verification: 38 unit tests and the focused key-out recovery → lobby → battle assembly UI flow pass.
- result: no remaining actionable P0/P1/P2 findings.

## Manual Subject Lift Fallback

- source visual truth path: `.development_document/5_study/2026-07-15_snap-fighter-keyout-qa/keyout-preview.png`
- implementation screenshot paths:
  - `.development_document/5_study/2026-07-15_snap-fighter-manual-cutout-qa/manual-button.png`
  - `.development_document/5_study/2026-07-15_snap-fighter-manual-cutout-qa/manual-picker-fixed-2.png`
- viewport: iPhone 16e, 390 × 844 pt
- states: automatic key-out returned no mask; manual subject picker returned no subject at the sampled point

**Full-view comparison evidence**

- `.development_document/5_study/2026-07-15_snap-fighter-manual-cutout-qa/full-comparison.png`
- The fallback remains subordinate to the 86% generation state, then opens a dedicated subject-selection surface using the same midnight, gold, photographed-object, rounded-display, and raised-panel language.

**Focused region comparison evidence**

- A separate focused crop was not needed because the full-resolution combined input keeps the button label, status copy, icons, borders, and photographed subject readable at native simulator resolution.

**Required fidelity surfaces**

- Fonts and typography: the fallback preserves the bold rounded Traditional Chinese hierarchy and compact secondary copy without truncation.
- Spacing and layout rhythm: the 52 pt fallback control sits between progress and phase markers without obscuring either; the picker keeps its photo, status, and exit action in one viewport.
- Colors and visual tokens: midnight, antique gold, parchment, mist, and raised navy map directly to the key-out ritual.
- Image quality and asset fidelity: the original high-resolution capture is passed into VisionKit without placeholder imagery; aspect-fit preserves the full source for tap selection.
- Copy and content: `手動去背`, `點一下照片中的主體`, the no-subject guidance, and `稍後處理` clearly describe the recovery path.
- Icons and accessibility: SF Symbols remain consistent; the fallback has an explicit identifier, label, and hint, and both actions meet practical mobile tap sizing.

**Comparison history**

- Pass 1 finding [P1]: the picker ScrollView could initialize at its bottom, leaving only `稍後處理` visible.
  - Evidence: `.development_document/5_study/2026-07-15_snap-fighter-manual-cutout-qa/manual-picker.png`.
  - Fix: replaced the scrolling container with a geometry-constrained single-viewport layout.
- Pass 2 finding [P1]: the UIKit image view's intrinsic width pushed the picker content outside the phone viewport.
  - Evidence: `.development_document/5_study/2026-07-15_snap-fighter-manual-cutout-qa/manual-picker-fixed.png`.
  - Fix: constrained both the representable and its parent stack to the available width.
- Final pass: photo, status, and exit action remain centered and fully visible; no actionable P0/P1/P2 issue remains.
  - Evidence: `.development_document/5_study/2026-07-15_snap-fighter-manual-cutout-qa/manual-picker-fixed-2.png`.

**Primary interactions tested**

- Opened the manual picker from a deterministic no-mask state.
- Dismissed with `稍後處理`, verified the manual fallback remained available, then exercised stalled-analysis cancellation and the existing battle-entry flow.
- Verified that a manual transparent image survives a later automatic-analysis response.

**Findings**

- No actionable P0/P1/P2 findings remain.

**Follow-up Polish**

- [P3] A future device-only pass can tune the VisionKit selection highlight against unusually bright photos; simulator support varies by image and runtime.

## Manual Picker Phone Fit

- source visual truth path: user-provided iPhone 16e app screenshot, reproduced at `.development_document/5_study/2026-07-15_snap-fighter-manual-fit-qa/manual-fit-final.png`
- implementation screenshot path: `.development_document/5_study/2026-07-15_snap-fighter-manual-fit-qa/manual-fit-compact.png`
- viewport: iPhone 16e, 390 × 844 pt
- state: manual subject picker with a no-subject result

**Full-view comparison evidence**

- `.development_document/5_study/2026-07-15_snap-fighter-manual-fit-qa/fit-comparison.png`
- The revised picker reduces the photo stage from a dominant fixed-height panel to an adaptive 240–330 pt region. Title, source photo, feedback, and exit action now read as one complete phone-sized task.

**Focused region comparison evidence**

- A focused crop was not needed because the combined native-resolution input keeps all text, borders, photo edges, and actions legible.

**Required fidelity surfaces**

- Fonts and typography: the established rounded Traditional Chinese hierarchy is unchanged and no visible app-specific copy is clipped.
- Spacing and layout rhythm: the photo height is derived from available sheet height; compact devices also reduce title size, gaps, and top padding.
- Colors and visual tokens: midnight, antique gold, parchment, mist, and raised navy remain unchanged.
- Image quality and asset fidelity: the source UIImage remains unmodified and uses aspect-fit with clipping limited to the rounded container boundary.
- Copy and content: selection guidance, no-subject recovery, and deferred action stay visible together.
- Accessibility and responsiveness: the main action remains on-screen without scrolling; focused UI automation passes at the iPhone 16e destination.

**Comparison history**

- Pass 1 finding [P2]: the fixed 430 pt photo region looked oversized and left insufficient visual separation between the image task and feedback.
  - Evidence: `.development_document/5_study/2026-07-15_snap-fighter-manual-fit-qa/manual-fit-final.png`.
  - Fix: reserved 360 pt for header, feedback, action, and safe spacing; capped regular image height at 330 pt and compact image height at 270 pt.
- Final pass: all required controls fit in the first viewport with more balanced image-to-control proportions and no P0/P1/P2 finding remains.
  - Evidence: `.development_document/5_study/2026-07-15_snap-fighter-manual-fit-qa/manual-fit-compact.png`.

**Primary interactions tested**

- Opened the deterministic manual-picker state.
- Verified the no-subject feedback and deferred action remain visible.
- Re-ran the focused key-out recovery and battle-entry UI flow successfully.

**Findings**

- No actionable P0/P1/P2 findings remain.

final result: passed
