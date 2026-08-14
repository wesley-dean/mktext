# ADR-010: Adopt Documentation-Driven, Test-Second Development

Date: 2026-08-14

## Status

Accepted

## Intent and Documentation Posture

This ADR establishes the preferred development sequence for `mktext`.

Documentation describes intended behavior before implementation; implementation
realizes that behavior; automated tests then provide executable evidence that
the implementation continues to match the documented contract.

## Context

`mktext` has a deliberately constrained scope, which makes ambiguity more
important rather than less important.  A tiny undocumented behavior can become
a surprisingly large compatibility commitment once callers depend upon it.

Architecture Decision Records and a behavioral specification are therefore
useful design artifacts before implementation begins.

Traditional test-driven development places executable tests first.  That model
is compatible with this project when useful, but the project intentionally puts
human-readable intent ahead of either code or tests.

## Decision Drivers

- Preserve reasoning before implementation details obscure it.
- Keep documentation, code, and tests synchronized.
- Make AI-assisted contributions easier to review against explicit intent.
- Require regression evidence when behavior changes.
- Avoid tests becoming an undocumented substitute for architecture.

## Decision

The normal development sequence SHALL be:

1. document the intended behavior or architectural change;
2. implement the smallest correct change;
3. add or update automated tests for the observable behavior;
4. run relevant formatting, static analysis, documentation, and tests;
5. review the resulting diff for scope and consistency.

A behavioral change is normally incomplete when its documentation or tests are
missing.

Bug fixes SHOULD include a regression test that would have failed before the
fix.

This ADR does not prohibit writing tests before implementation when doing so
helps clarify behavior.  It establishes documentation as the primary statement
of intent.

## Considered Alternatives

### Traditional test-driven development as a mandatory sequence

Tests-first development is effective in many contexts, but executable tests do
not reliably preserve rationale, non-goals, rejected alternatives, or broader
architectural constraints.

### Documentation without automated tests

Human-readable intent alone does not provide repeatable evidence that the Bash
implementation still behaves as documented.

### Implementation first, documentation later

This was rejected because later documentation tends to describe what happened
to be implemented rather than the design that should govern implementation.

## Consequences

Architecture and specification work are first-class development tasks.

Changes may appear slower at the first line of code but should require less
reconstruction and correction later.

Reviewers have an explicit contract against which to evaluate implementation and
tests.

## Open Questions and Follow-Ups

None for v1.

## Related Decisions

- Related to: ADR-009
- Related to: ADR-011
- Related to: ADR-012
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
