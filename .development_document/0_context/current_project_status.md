---
ID: 00.01.01
Slug: current-project-status
Title: Snap Fighter Current Project Status
Ref: [00.00.01, 06.01.01, 06.02.01]
Date: 20260721
---

# Snap Fighter Current Project Status

This file is the canonical current-status summary for Snap Fighter. Use `.development_document/progress.md` only as a legacy chronological log.

## Product Position

- User-facing product name: `攝靈者卡牌`
- Technical repository/project name: `Snap Fighter`
- Product type: iOS AI photo-to-card battle game and workshop sample project
- Primary workshop promise: attendees use Xcode and Codex to build an AI-enabled iOS game without needing to master Swift first

## Current App Shape

- SwiftUI iOS app with one main Xcode project: `Snap Fighter.xcodeproj`
- App source lives in `Snap Fighter/`
- Unit tests live in `Snap FighterTests/`
- UI tests live in `Snap FighterUITests/`
- Monster analysis can route through `AI_PROVIDER=auto`, `apple-local`, `worker`, or `mock`
- Worker-backed analysis lives in `worker/`
- Static promotional site lives in `promo-site/`

## Implemented Product Capabilities

- Photo or library image capture for monster generation
- AI-generated monster cards with image analysis, element, stats, and skills
- On-device foreground cutout path for card artwork when available
- Local deck collection, winner collection, main/reserve roles, and active battle deck selection
- Quick battle with starter cards for first-play flow
- Turn-based card battle with attack, skill, defend, reserve swap, cooldown, and reserve-entry effects
- JRPG-style card battle presentation, summon/result rituals, and deck/lobby visual language
- Debug overlay for AI provider diagnostics and launch-argument provider overrides

## Recent Stable State

- Latest major implementation notes are in `6_changelog/2026-07-20_ai_provider_router_and_apple_local_start.md`
- Latest UI/product overhaul notes are in the July 15 changelog entries
- The old `progress.md` log contains useful history from 2026-05-04 through 2026-07-15, but it should not be the primary source for current truth

## Known Validation Pattern

- For app source changes, first verify with the narrowest relevant Xcode build or test.
- Targeted unit-test validation should use the real target token: `-only-testing:'Snap FighterTests'`.
- If simulator runtimes are unavailable, a generic iOS build can still validate Swift compilation, but it is not proof of launchability.
- For Worker changes, use a Wrangler dry run and then endpoint checks when secrets and network access are available.

## Current Documentation Convention

- Use semantic filenames and YAML metadata as defined in `.development_document/FILES_STRUCTURE.md`.
- Add completed implementation records to `6_changelog/`.
- Keep reusable current facts in `0_context/`.
- Keep research and validation writeups in `5_study/`.
- Do not add new ongoing work to `progress.md`; it is retained only as a legacy chronological log.
