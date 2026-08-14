# ADR-007: Define Diagnostics and Return-Status Semantics

Date: 2026-08-14

## Status

Proposed

## Intent and Documentation Posture

This ADR defines how a sourced `mktext` library communicates success, negative
queries, caller errors, and data input/output failures.

## Context

`mktext` is a Bash function rather than a standalone process.  It must therefore
return control to the caller and must never terminate the caller's shell as an
ordinary error-handling mechanism.

The `exists` operation also needs a useful boolean status.  If every nonzero
status meant an error, callers would need textual output or another side channel
to ask whether a key is absent.

Rendered data and `get` values use standard output, so diagnostics must use a
different stream to avoid corrupting caller data.  Writes to that data stream
can also fail independently of API validation, so the status contract needs one
small I/O-failure category that applies wherever public data is transferred.

Bash signals form a separate boundary.  A process writing to a pipe whose reader
has closed may receive `SIGPIPE` before a builtin can return a recoverable write
error to `mktext`.  Normal function return statuses cannot reliably replace a
signal-derived process or pipeline status without installing signal traps that
would interfere with the caller's shell environment.

Bash input handling has a related information boundary.  The `read` builtin
returns status 1 for ordinary EOF, and it can also return status 1 for some read
failures.  A pure-Bash streaming loop therefore cannot distinguish every
input-side failure from EOF using the return status alone.  In those cases Bash
may emit its native diagnostic, but `mktext` cannot truthfully promise a distinct
status without adding platform-specific inspection or extra runtime machinery.

## Decision Drivers

- Preserve standard output for data.
- Make membership tests natural in Bash conditionals.
- Distinguish a normal negative lookup from invalid API usage.
- Distinguish API failures from recoverable failures that Bash reports
  unambiguously while reading or writing public data.
- Preserve the caller's ownership of signal handling.
- Avoid platform-specific input probing solely to manufacture distinctions Bash
  does not expose through `read`.
- Keep the status model small enough to remember and document.
- Never `exit` from a sourced library for ordinary errors.

## Decision

`mktext` SHALL write diagnostics to standard error.

The public return-status contract SHALL be:

```text
0  operation succeeded, or a predicate is true
1  requested key is absent for get/exists
2  invalid operation name, arity, or other API usage
3  invalid context reference, readonly mutation, or invalid key
4  distinguishable recoverable data input/output failure
```

Specific operation rules are:

- `set` returns 0 after storing the value;
- `get` returns 0 and writes the exact value when present, returns 1 and writes
  nothing when absent, or returns 4 when Bash reports a recoverable output error
  to the function before a signal terminates execution;
- `exists` returns 0 when present and 1 when absent, with no standard output;
- `unset` is idempotent and returns 0 for a valid writable context/key whether
  or not the key previously existed;
- `render` returns 0 when the input stream reaches a `read` status that Bash uses
  for EOF, including status 1, and returns 4 when Bash reports a distinguishable
  non-EOF input/output failure to the function;
- unknown macros remain valid render input and do not change the status;
- invalid operations, argument counts, contexts, readonly mutations, or keys
  produce concise diagnostics and the corresponding status above.

These values describe normal function return paths.  If the shell process or a
pipeline component is terminated by a signal before `mktext` can return, the
caller may observe the shell's signal-derived status instead.  For example,
`SIGPIPE` is commonly represented as status 141 (`128 + 13`).

When Bash `read` returns status 1, `mktext` SHALL treat it as the end of the
stream because the same status is required for ordinary EOF.  If Bash also uses
status 1 for a particular read failure, the library cannot distinguish that
failure from EOF from the builtin status alone.  `mktext` SHALL NOT add external
runtime dependencies or platform-specific file-descriptor inspection solely to
infer that distinction.

`mktext` SHALL NOT install, replace, or clear caller signal traps solely to
normalize signal-derived failures into status 4.

The library SHALL use `return`, not `exit`, for its public error paths.

Routine successful operations SHALL NOT emit progress logging.

## Considered Alternatives

### Use only 0 and 1

A binary status model is familiar, but it cannot distinguish a normal absent
key from malformed API usage or an invalid context.

### Assign a unique code to every error

Highly granular statuses would allow detailed automation, but the compatibility
cost would exceed the value for this small library.

### Give get and render separate I/O codes

The caller may care that public data could not be transferred completely, but
separate numeric categories for each operation would add compatibility surface
without changing the caller's practical recovery options.  One data-I/O
category is sufficient.

### Trap SIGPIPE and translate it to status 4

The library could temporarily manipulate `SIGPIPE` handling in an attempt to
turn closed-pipe failures into an ordinary function return.  This was rejected
because a sourced library should not silently alter the caller's signal policy,
and because ordinary shell signal semantics already communicate the condition.

### Probe standard input to distinguish every `read` status 1

The library could inspect `/dev/fd`, `/proc`, or invoke external utilities in an
attempt to tell EOF from every input failure that Bash reports as status 1.
This was rejected because such probing is platform-specific, incomplete, and
contrary to the no-external-runtime-dependencies design for a distinction Bash
does not expose reliably through the builtin interface.

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

Callers that care about the difference between absence, misuse, invalid state,
and distinguishable recoverable data-transfer failures can inspect normal
function statuses without parsing human-readable diagnostics.

Callers that care about signal termination must continue to handle shell signals
and pipeline statuses according to normal Bash semantics.

Some input-side failures are observationally indistinguishable from EOF through
Bash `read` status alone.  Bash may still print a native diagnostic for such a
failure even when `mktext` subsequently returns 0 after observing status 1.
This limitation is documented rather than hidden behind extra platform-specific
machinery.

These numeric meanings are part of the public API and require compatibility
consideration if changed.

## Open Questions and Follow-Ups

Tests should cover recoverable output failures where the host operating system
provides a deterministic mechanism such as `/dev/full`.  Signal behavior and
input-status ambiguity should be documented rather than forced through
library-owned traps or platform-specific probing.

## Related Decisions

- Related to: ADR-003
- Related to: ADR-005
- Related to: ADR-006
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
