---
name: handoff
description: Create a concise handoff for another AI session or future user continuation. Use when the user asks to hand off, pause, resume later, summarize current state for the next session, or close a work segment.
---

# Handoff

Create a short continuation record.

1. Reference existing files, specs, decisions, tasks, commits, and verification instead of repeating them.
2. State objective, current status, completed work, blockers, and next action.
3. Include exact paths and verification results.
4. Remove secrets and sensitive data.
5. Update `.memory/current_focus_summary.md` and `.memory/current_focus.md` when useful.
6. Put durable handoff notes under `.development_document/4_task/` when they should persist.

Keep the handoff compact enough for a new session to start quickly.
