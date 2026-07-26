---
name: to-spec
description: Convert an accepted discussion, grilling result, issue, or plan into a concise implementation spec. Use when the user asks for a spec, PRD, implementation contract, or a discussion-to-spec conversion.
---

# To Spec

Create a compact implementation contract.

1. Read `AGENTS.md`, `.memory/`, `.development_document/index.md`, and relevant decisions.
2. Use accepted terms and decisions. Mark unresolved items explicitly.
3. Do not invent requirements that were not discussed or evident in the project.
4. Define behavior at public boundaries, not private implementation details.
5. Include acceptance criteria and relevant verification.
6. Save durable specs under `.development_document/3_plan/` unless the project defines a better location.

Recommended sections: Problem, Outcome, Scope, Non-goals, Requirements, Decisions, Acceptance Criteria, Verification, Open Questions.
