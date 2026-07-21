---
ID: 06.01.01
Slug: development-document-structure-cleanup
Title: Development Document Structure Cleanup
Ref: [00.00.01, 00.01.01]
Date: 20260721
---

# Development Document Structure Cleanup

Date: 2026-07-21

## Summary

- Added `.development_document/FILES_STRUCTURE.md` to define Snap Fighter documentation folders, semantic filenames, and metadata fields.
- Added `.development_document/0_context/current_project_status.md` as the canonical current-status summary.
- Reclassified `.development_document/progress.md` as a legacy chronological development log instead of the primary current-truth source.
- Added root `AGENTS.md` for repository-specific agent instructions.
- Added root `AGENT.md` as a compatibility pointer to `AGENTS.md`.

## Files

- `.development_document/FILES_STRUCTURE.md`
- `.development_document/0_context/current_project_status.md`
- `.development_document/progress.md`
- `.development_document/6_changelog/2026-07-21_development_document_structure_cleanup.md`
- `AGENTS.md`
- `AGENT.md`

## Verification

- Confirmed `.development_document/progress.md` was created during development and is currently ignored by Git through `.gitignore`.
- Confirmed `.development_document/FILES_STRUCTURE.md` includes the required frontmatter fields: `ID`, `Slug`, `Title`, `Ref`, and `Date`.
- Confirmed the new structure follows the repository's actual `.development_document/` folders: `0_context`, `3_plan`, `5_study`, `6_changelog`, and `source`.
