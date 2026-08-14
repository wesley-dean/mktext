# ADR-012: Treat Documentation and Architectural Context as Product Artifacts

Date: 2026-08-14

## Status

Accepted

## Intent and Documentation Posture

This ADR defines how project knowledge is preserved for users, maintainers, and
AI-assisted contributors.

## Context

Source code explains how the current implementation works.  Tests explain
observable expectations.  Neither reliably records why the project's narrow
boundaries, grammar, security posture, or compatibility commitments exist.

A small project is particularly vulnerable to undocumented assumptions because
future contributors may conclude that missing features are accidental and
"improve" the library into a larger template engine.

The repository therefore needs a deliberate division of documentation roles.

## Decision Drivers

- Preserve architectural rationale independently from implementation.
- Make the intended project boundary discoverable before code changes begin.
- Reduce reliance on memory or commit archaeology.
- Give humans and AI agents a shared operational map.
- Keep documentation changes synchronized with public behavior.

## Decision

Documentation SHALL be treated as part of the `mktext` product surface.

The documentation roles SHALL be:

- `README.md`: human-facing project overview and normal usage;
- `AGENTS.md`: operational guidance for AI-assisted contributors;
- `doc/adr/`: historical architectural decisions and their rationale;
- `doc/mktext-spec.md`: normative behavioral specification for the public API;
- source comments: implementation-local intent, constraints, and maintenance
  guidance.

Significant architectural decisions SHALL be recorded in ADRs.

Existing accepted ADRs SHOULD remain historical records.  Later decisions
SHOULD supersede or refine them rather than silently rewriting history, except
for factual corrections or maintenance that does not alter the recorded
decision.

Public behavior changes SHALL update the relevant user documentation and
specification in the same change when practical.

Design and implementation choices SHOULD optimize for the next contributor,
including the original maintainer returning after substantial time away.

## Considered Alternatives

### Rely on source code and tests

This would keep the documentation set smaller but would require future
contributors to reconstruct rationale from implementation artifacts.

### Rely on Git and pull-request history

Historical discussions are useful evidence, but they are not a curated or
stable architecture reference and can be difficult to discover.

### Keep only ADRs

ADRs preserve decisions well, but users and contributors need synthesized
current guidance rather than reconstructing the present contract from a chain of
historical records.

## Consequences

Documentation becomes part of release readiness and code review.

The repository contains some intentional redundancy because current reference
documentation and historical decision records serve different purposes.

Contributors should read the relevant ADRs and specification before making
behavioral changes.

## Open Questions and Follow-Ups

None for v1.

## Related Decisions

- Related to: ADR-010
- Related to: ADR-011
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
