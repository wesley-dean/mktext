# ADR-007: Define Diagnostics and Return-Status Semantics

Date: 2026-08-14

## Status

Proposed

## Intent and Documentation Posture

This ADR defines how a sourced `mktext` library communicates success, negative
queries, caller errors, and rendering failures.

## Context

`mktext` is a Bash function rather than a standalone process.  It must therefore
return control to the caller and must never terminate the caller's shell as an
ordinary error-handling mechanism.

The `exists` operation also needs a useful boolean status.  If every nonzero
status meant an error, callers would need textual output or another side channel
to ask whether a key is absent.

Rendered data and `get` values use standard output, so diagnostics must use a
different stream to avoid corrupting caller data.

## Decision Drivers

- Preserve standard output for data.
- Make membership tests natural in Bash conditionals.
- Distinguish a normal negative lookup from invalid API usage.
- Keep the status model small enough to remember and document.
- Never `exit` from a sourced library for ordinary errors.

## Decision

`mktext` SHALL write diagnostics to standard error.

The public return-status contract SHALL be:

```text
0  operation succeeded, or a predicate is true
1  requested key is absent for get/exists
2  invalid operation name, arity, or other API usage
3  invalid context reference or invalid key
4  rendering input/output failure
```

Specific operation rules are:

- `set` returns 0 after storing the value;
- `get` returns 0 and writes the exact value when present, or returns 1 and
  writes nothing when absent;
- `exists` returns 0 when present and 1 when absent, with no standard output;
- `unset` is idempotent and returns 0 for a valid context/key whether or not the
  key previously existed;
- `render` returns 0 when the complete input stream is rendered according to the
  defined grammar, including when unknown macros are preserved;
- invalid operations, argument counts, contexts, or keys produce concise
  diagnostics and the corresponding status above.

The library SHALL use `return`, not `exit`, for its public error paths.

Routine successful operations SHALL NOT emit progress logging.

## Considered Alternatives

### Use only 0 and 1

A binary status model is familiar, but it cannot distinguish a normal absent
key from malformed API usage or an invalid context.

### Assign a unique code to every error

Highly granular statuses would allow detailed automation, but the compatibility
cost would exceed the value for this small library.

### Print missing-key diagnostics from `get`

A missing key is often a normal query result.  Treating it as a noisy error would
make callers suppress diagnostics for expected control flow.

### Terminate the shell on misuse

A library should not take ownership of the caller's process lifetime.  This was
rejected as unsafe and surprising.

## Consequences

Shell callers can write natural predicates such as:

```bash
if mktext exists context TITLE; then
  ...
fi
```

Callers that care about the difference between absence and misuse can inspect
statuses greater than 1.

These numeric meanings are part of the public API and require compatibility
consideration if changed.

## Open Questions and Follow-Ups

The implementation must define what constitutes an I/O failure in terms Bash
can observe reliably.  Tests should cover broken-output cases when practical.

## Related Decisions

- Related to: ADR-003
- Related to: ADR-005
- Related to: ADR-006
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
