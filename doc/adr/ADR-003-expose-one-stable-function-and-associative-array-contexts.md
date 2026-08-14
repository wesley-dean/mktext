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

A small amount of self-description is also valuable.  Callers should be able to
ask the library how it is used and which built artifact they have without
inspecting source text.  Help and version reporting therefore belong to the same
single public dispatcher rather than requiring additional global functions.

Bash dynamic scoping introduces one additional constraint.  Private local
variables can shadow caller variables with the same name.  The implementation
therefore reserves a private variable prefix so a nameref can be created only
after the caller's context is known not to collide with library internals.

Readonly associative arrays introduce a second constraint.  Bash can terminate
a shell on an attempted assignment to a readonly nameref target, so mutating
operations must reject readonly contexts before performing a write.

## Decision Drivers

- Keep the public namespace small.
- Use native Bash data structures rather than inventing a context format.
- Permit callers to maintain more than one independent context.
- Provide concise discoverability without creating a separate CLI program.
- Expose build identity without requiring source inspection.
- Validate context references before using namerefs.
- Avoid dynamic-scope collisions with private library variables.
- Fail predictably before attempting writes to readonly contexts.
- Provide a complete minimal map API without exposing private helpers.

## Decision

The public library SHALL expose one function named `mktext`.

The function SHALL dispatch the following context and rendering operations:

```text
mktext set CONTEXT KEY VALUE
mktext get CONTEXT KEY
mktext exists CONTEXT KEY
mktext unset CONTEXT KEY
mktext render CONTEXT
```

It SHALL also accept these informational forms:

```text
mktext help
mktext -h
mktext --help
mktext version
mktext --version
```

`help`, `-h`, and `--help` SHALL be equivalent.  They SHALL write concise usage
information to standard output and return status 0 when the output is written
successfully.

`version` and `--version` SHALL be equivalent.  They SHALL write the version,
source-revision timestamp, and source commit embedded in the artifact as three
stable lines and return status 0 when the output is written successfully.  The
release/build metadata model is defined by ADR-008.

`CONTEXT` SHALL be the name of a Bash associative-array variable declared by the
caller, for example:

```bash
declare -A context=()
```

Before creating a nameref, `mktext` SHALL validate that the supplied context
name is a legal Bash identifier and that the referenced variable exists as an
associative array.

Context names beginning with `__mktext_` SHALL be reserved for private library
state and rejected as public context names.

Readonly associative arrays SHALL be valid for `get`, `exists`, and `render`.
`set` and `unset` SHALL reject a readonly context before attempting a mutation.

Operation semantics are:

- `set` stores `VALUE` under the normalized key and emits no output;
- `get` writes the exact stored value to standard output with no added newline;
- `exists` emits no output and communicates membership through return status;
- `unset` removes the normalized key if present and is idempotent;
- `render` consumes template text from standard input and writes rendered text
  to standard output;
- `help`, `-h`, and `--help` emit usage information without requiring a context;
- `version` and `--version` emit artifact identity without requiring a context.

Values are arbitrary Bash strings, including the empty string and embedded
newlines.  NUL bytes remain unsupported as described by ADR-002.

No implicit global context or default context SHALL exist.

Private helper functions and variables may be added as implementation details.
They are not public interfaces unless a later ADR explicitly says otherwise.

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

### Omit help and version reporting

The implementation would remain smaller, but basic discoverability and artifact
identity would then require users to inspect documentation or source files.
These two informational surfaces are small, deterministic, and do not expand the
rendering language.

### Add a standalone CLI wrapper for help and version

A second public program would create another interface and release artifact.
Keeping informational behavior on the existing `mktext` dispatcher preserves the
single-public-function model.

### Permit contexts to use the private prefix

Any fixed private local name can collide with a dynamically scoped caller
variable.  Reserving one clearly documented prefix makes that boundary
predictable instead of relying on increasingly obscure internal names.

### Attempt mutations against readonly contexts

Bash's readonly assignment behavior can be fatal to the caller shell rather than
merely returning a normal function error.  Pre-validation is therefore safer
than delegating this case to the assignment operation.

### Omit `unset`

Callers could use Bash's `unset` directly.  This was rejected because it would
make one fundamental context mutation bypass the validated public API while the
other context operations remained encapsulated.

## Consequences

The API is easy to vendor and document.

Callers retain ownership of context lifetime and may inspect the associative
array directly when debugging.

The `__mktext_` prefix is reserved for library-private state.

Readonly contexts can safely participate in read-only workflows.

Users can discover supported forms and identify a built artifact without adding
runtime dependencies or inspecting the file manually.

Changing operation names, aliases, argument order, help/version output contracts,
context semantics, reserved namespace, or rendering behavior is a public
compatibility change.

## Open Questions and Follow-Ups

None for v1.  Additional operations or aliases should require a concrete use case
and should not be added merely for symmetry with richer APIs.

## Related Decisions

- Related to: ADR-002
- Related to: ADR-004
- Related to: ADR-007
- Related to: ADR-008
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
