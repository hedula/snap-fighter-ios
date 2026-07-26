---
name: quality-gate
description: Apply completion gates before declaring a project, feature, ticket, or implementation segment done. Use when the user asks whether work is done, asks for quality gates, wants Uncle Bob style constraints, or when a coding task reaches completion.
---

# Quality Gate

Do not declare work done until its gate passes or the blocker is explicit.

1. Identify the work type and risk level.
2. Read the accepted spec, ticket, or user request.
3. Select the smallest gate that covers the changed behavior.
4. Run available checks or state why they are unavailable.
5. Compare results against acceptance criteria.
6. Report passed gates, failed gates, skipped gates, and residual risk.

Default gates:

- Docs-only: link check or structure check when available.
- Prototype: build or runnable smoke check.
- Normal feature: unit or integration test, typecheck or lint, build.
- Critical workflow: acceptance test, regression test, coverage signal, runtime smoke.
- Security, auth, payment, data loss, or destructive behavior: require human review in addition to automated checks.

Do not use coverage or mutation scores as proof of correctness by themselves. Treat them as supporting constraints.
