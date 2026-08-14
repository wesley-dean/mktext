# ADR-003: Expose One Stable Function and Associative-Array Contexts

Date: 2026-08-14

## Status

Proposed

## Intent and Documentation Posture

This ADR defines the public Bash API and context data model for `mktext`.

The API is intentionally small because every public operation becomes a
compatibility commitment.

## Context

A template renderer needs a mapping from names such as `TITLE` or `NUMBER4` to
literal values.  Bash associative arrays already provide that mapping without a
custom serialization format.

The project also benefits from exposing one public function rather than a set of
global helper functions that may collide with names in the caller's shell.

The design handoff identified `set`, `get`, `exists`, and `render` as expected
operations and left `unset` unresolved.  Context removal is a fundamental map
operation and can be provided without expanding rendering semantics, so the v1
API includes it.

## Decision Drivers

- Keep the public namespace small.
- Use native Bash data structures rather than inventing a context format.
- Permit callers to maintain more than one independent context.
- Validate context references before using namerefs.
- Provide a complete minimal map API without exposing private helpers.

## Decision

The public library SHALL expose one function named `mktext`.

The function SHALL dispatch the following operations:

```text
mktext set CONTEXT KEY VALUE
mktext get CONTEXT KEY
mktext exists CONTEXT KEY
mktext unset CONTEXT KEY
mktext render CONTEXT
```

`CONTEXT` SHALL be the name of a Bash associative-array variable declared by the
caller, for example:

```bash
declare -A context=()
```

Before creating a nameref, `mktext` SHALL validate that the supplied context
name is a legal Bash identifier and that the referenced variable exists as an
associative array.

Operation semantics are:

- `set` stores `VALUE` under the normalized key and emits no output;
- `get` writes the exact stored value to standard output with no added newline;
- `exists` emits no output and communicates membership through return status;
- `unset` removes the normalized key if present and is idempotent;
- `render` consumes template text from standard input and writes rendered text
  to standard output.

Values are arbitrary Bash strings, including the empty string and embedded
newlines.  NUL bytes remain unsupported as described by ADR-002.

No implicit global context or default context SHALL exist.

Private helper functions may be added as implementation details.  They are not
public interfaces unless a later ADR explicitly says otherwise.

## Considered Alternatives

### Expose multiple public functions

Functions such as `mktext_set` and `mktext_render` would be straightforward,
but they would expand the caller's global function namespace and increase the
public compatibility surface.

### Use global variables for context

A library-owned global map would simplify invocation, but it would prevent
independent contexts and introduce hidden mutable state.

### Pass key/value pairs on every render call

This avoids a persistent context but makes quoting, empty values, repeated
renders, and larger contexts cumbersome.

### Omit `unset`

Callers could use Bash's `unset` directly.  This was rejected because it would
make one fundamental context mutation bypass the validated public API while the
other context operations remained encapsulated.

## Consequences

The API is easy to vendor and document.

Callers retain ownership of context lifetime and may inspect the associative
array directly when debugging.

Changing operation names, argument order, output behavior, or context semantics
is a public compatibility change.

## Open Questions and Follow-Ups

None for v1.  Additional operations should require a concrete use case and
should not be added merely for symmetry with richer data-store APIs.

## Related Decisions

- Related to: ADR-002
- Related to: ADR-004
- Related to: ADR-007
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
