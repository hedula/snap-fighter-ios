---
name: tdd
description: Use test-driven implementation for behavior changes, bug fixes, state machines, data transformations, permissions, workflows, and other logic where regression protection matters. Use when the user asks for TDD or when implementation risk warrants tests first.
---

# TDD

Use tests to define behavior before implementation.

1. Identify the public behavior or boundary to test.
2. Write one failing test for the next small behavior.
3. Implement the smallest change that makes it pass.
4. Refactor only after the test passes.
5. Repeat for the next behavior.
6. Report the exact verification result.

Do not write tautological tests, test private implementation details, or mock away the behavior being verified.
