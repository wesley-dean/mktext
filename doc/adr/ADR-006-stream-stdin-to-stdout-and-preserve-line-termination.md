# ADR-006: Stream STDIN to STDOUT and Preserve Line Termination

Date: 2026-08-14

## Status

Proposed

## Intent and Documentation Posture

This ADR defines rendering I/O and buffering behavior.

## Context

The design handoff calls for `mktext render` to operate as a Unix-style filter:
template text arrives on standard input and rendered text leaves on standard
output.

A whole-template Bash variable would simplify some substitution strategies, but
command substitution strips trailing newlines and whole-template buffering makes
memory consumption scale with total template size.  The library can avoid both
problems by processing one physical line at a time.

Line-oriented streaming also makes the grammar boundary explicit: macros are
line-local and cannot span newline delimiters.

## Decision Drivers

- Compose naturally with pipes and redirections.
- Preserve whether the input ended with a newline.
- Avoid whole-template buffering.
- Keep memory use related to the current line rather than total input size.
- Make cross-line macro behavior explicit.

## Decision

`mktext render CONTEXT` SHALL read template text from standard input and write
rendered text to standard output.

The render operation SHALL NOT accept a template filename as part of the v1 API.
Callers may use ordinary shell redirection.

Rendering SHALL process input one physical newline-delimited line at a time.
The implementation SHALL distinguish a line terminated by a newline from a
final unterminated line and SHALL reproduce that distinction in its output,
except for newline characters deliberately introduced by replacement values.

A macro SHALL NOT span an input newline.  A `{` on one line and a matching `}`
on a later line are ordinary literal text.

Carriage-return characters are ordinary input characters.  Consequently, CRLF
input can be preserved naturally as a carriage return in the line data followed
by the newline delimiter.

The implementation SHALL avoid reading the complete template into one Bash
variable.

## Considered Alternatives

### Buffer the whole template

Whole-template replacement can be concise, but Bash command-substitution and
variable-handling details make exact trailing-newline preservation easy to get
wrong.  Memory also scales with total template size.

### Accept filenames directly

A filename parameter could save callers a redirection operator.  It was
rejected because STDIN already composes with files, pipes, process substitution,
here-documents, and generated input without adding path-handling semantics to
the library.

### Permit macros to span lines

Cross-line macros would require a larger buffering window and make accidental
open braces influence distant text.  The use case does not justify that
complexity.

## Consequences

Large templates can be rendered without whole-file buffering.

Exact line termination becomes part of the public behavior and must be covered
by regression tests.

Very long individual lines still require memory proportional to that line and
its replacement values.

## Open Questions and Follow-Ups

None for v1.

## Related Decisions

- Related to: ADR-004
- Related to: ADR-005
- Related to: ADR-007
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
