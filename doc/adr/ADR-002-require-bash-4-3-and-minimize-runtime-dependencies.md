# ADR-002: Require Bash 4.3+ and Minimize Runtime Dependencies

Date: 2026-08-14

## Status

Proposed

## Intent and Documentation Posture

This ADR establishes the runtime platform for `mktext` and the project's
attitude toward dependencies.

## Context

The intended API uses Bash associative arrays to hold named values and Bash
namerefs to access a caller-supplied context by variable name.

Associative arrays are available in Bash 4.  Namerefs are available in Bash
4.3.  Requiring a newer Bash version would provide additional features, but the
core design does not currently need them.

The library is intended to be sourced by other Bash programs.  Requiring
external commands for ordinary substitution would add process overhead,
platform variation, and additional failure modes to a very small operation.

Bash strings also have an important limitation: they cannot represent NUL
bytes.  `mktext` is therefore a text library rather than an arbitrary binary
rewriter.

## Decision Drivers

- Support associative-array contexts and namerefs directly.
- Avoid raising the minimum Bash version without a demonstrated requirement.
- Keep rendering self-contained and deterministic.
- Minimize the trusted and operational dependency surface.
- State the Bash/NUL boundary explicitly rather than implying binary safety.

## Decision

`mktext` SHALL require Bash 4.3 or newer.

The canonical library artifact SHALL be sourceable Bash code.

Normal `mktext` operations SHALL use Bash builtins and language features and
SHALL NOT require external runtime commands.

External development tools such as Bats, ShellCheck, shfmt, Make, and Doxygen
may be used for testing, validation, formatting, and documentation.  They are
not runtime dependencies of consumers that source `mktext.bash`.

Input containing NUL bytes is unsupported because Bash variables cannot
represent NUL bytes faithfully.  The library shall not claim binary-safe
behavior.

## Considered Alternatives

### Require Bash 5+

Bootstrap uses Bash 5+ as a deliberate platform decision.  `mktext` does not
currently need Bash 5-specific behavior, so adopting that requirement would
exclude otherwise capable systems without architectural benefit.

### Support POSIX sh

A POSIX shell implementation would increase nominal portability.  It was
rejected because the named-context design depends naturally on associative
arrays and namerefs; emulating those capabilities would increase code and
complexity substantially.

### Depend on sed, awk, Perl, or Python for rendering

External text-processing tools could simplify some parsing strategies.  This
was rejected because `mktext` is small enough to implement safely in Bash and
because process spawning would become part of every render operation.

## Consequences

Systems whose default shell is older than Bash 4.3 must install and explicitly
use a supported Bash version.

The implementation remains easy to vendor and source.

The library can be tested as a Bash component without constructing a separate
runtime environment.

## Open Questions and Follow-Ups

A future language feature that genuinely requires a newer Bash release should
be evaluated as a compatibility change rather than adopted incidentally.

## Related Decisions

- Related to: ADR-003
- Related to: ADR-008
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
