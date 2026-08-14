# ADR-001: Define mktext Scope and the Caller Boundary

Date: 2026-08-14

## Status

Proposed

## Intent and Documentation Posture

This ADR defines what `mktext` is responsible for and, equally importantly,
what it deliberately leaves to its callers.

The project is intentionally narrow.  A small, explicit boundary is a product
feature because it keeps behavior deterministic, reviewable, and reusable.

## Context

`mktext` exists to solve one problem: substitute named values into text.

A caller may need to obtain a date, inspect Git state, generate a UUID, pad a
number, slugify a title, normalize case, or derive another value before
rendering a template.  Those operations are useful, but they are not text
substitution.  If `mktext` performs them, the library begins to acquire policy,
external-state dependencies, and a growing expression language.

The design handoff therefore establishes a strong separation:

```text
Acquisition    -> caller
Transformation -> caller
Rendering      -> mktext
```

This boundary also separates `mktext` from the future ADR tooling that helped
motivate it.  `mktext` may be used by ADR tooling, but it shall not know what an
ADR is.

## Decision Drivers

- Keep the library deterministic for a supplied template and context.
- Keep runtime dependencies and hidden state to a minimum.
- Avoid growing a template programming language.
- Allow callers to compose their own acquisition and transformation logic.
- Keep `mktext` reusable outside the use case that originally motivated it.

## Decision

`mktext` SHALL perform named, literal text substitution and almost nothing
else.

Callers SHALL be responsible for acquiring and transforming values before
placing them into a rendering context.

The core library SHALL NOT provide built-in operations for:

- date or time acquisition;
- Git, environment, filesystem, network, or process-state acquisition;
- random values or UUID generation;
- slugification;
- case conversion;
- numeric padding;
- filters or pipelines;
- conditionals, loops, expressions, or arithmetic;
- includes or template inheritance;
- ADR-specific semantics;
- plugin discovery or execution.

A caller may implement any of these behaviors before invoking `mktext`.

New features that cross the acquisition, transformation, or rendering boundary
require architectural justification and normally require a new ADR.

## Considered Alternatives

### Provide common transformations

Built-in helpers for slugification, uppercasing, padding, and date formatting
would reduce code in some callers.  This was rejected because every
transformation adds syntax, policy, tests, and compatibility obligations to a
library whose value comes from having a small semantic surface.

### Provide an extensible filter or plugin system

A plugin model could preserve a small built-in feature set while allowing
extension.  This was rejected because plugin discovery, execution, failure
handling, and compatibility would become responsibilities of `mktext` even when
no plugin was used.

### Embed shell expressions in templates

Allowing templates to execute Bash would be expressive.  This was rejected
because it destroys the separation between data and code and conflicts with the
security model defined by the rendering ADRs.

## Consequences

`mktext` remains small and deterministic.

Callers may contain more preparation code, but that code remains explicit and
owned by the component that understands the relevant policy.

Some feature requests will be declined even when they are individually useful.
That restraint is intentional.

## Open Questions and Follow-Ups

None for the initial architecture.  A future proposal may revisit the boundary
only when a concrete use case demonstrates that substitution itself cannot be
expressed cleanly without the new behavior.

## Related Decisions

- Related to: ADR-003
- Related to: ADR-005
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
