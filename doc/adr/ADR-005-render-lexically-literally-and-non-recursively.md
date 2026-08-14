# ADR-005: Render Lexically, Literally, and Non-Recursively

Date: 2026-08-14

## Status

Accepted

## Intent and Documentation Posture

This ADR defines the core rendering and security semantics of `mktext`.
Templates are data, even when their contents resemble shell syntax.

## Context

Template text may be user-authored, repository-provided, downloaded, or
otherwise untrusted.  A renderer implemented with `eval`, `source`, shell
expansion, or command substitution would turn template content into executable
code and make quoting correctness extremely difficult to reason about.

Context values can also contain shell metacharacters, braces, dollar signs,
backticks, command substitutions, newlines, and other text that must survive
unchanged.

The project also needs an explicit rule for unknown and malformed macros.  The
handoff's strongest direction is to preserve unknown macros, and the project's
small-language philosophy favors recognizing only syntax it understands rather
than treating every brace pair as an error.

## Decision Drivers

- Treat templates as hostile or untrusted data.
- Guarantee literal insertion of context values.
- Prevent execution or shell interpretation during rendering.
- Keep one rendering pass deterministic and understandable.
- Allow templates to contain unrelated brace syntax without escaping rules.

## Decision

Rendering SHALL be lexical substitution only.

`mktext` SHALL NOT `eval`, `source`, execute, or shell-expand template text or
context values.

For each recognized macro whose normalized key exists in the context, `mktext`
SHALL replace that macro with the exact stored value.

Inserted values SHALL NOT be rescanned for additional macros during the same
render.  Rendering is therefore nonrecursive.

For a recognized macro whose key does not exist, `mktext` SHALL preserve the
original macro text byte-for-byte.

Brace-containing text that does not satisfy ADR-004's macro grammar SHALL be
copied unchanged and SHALL NOT be treated as a rendering error.

Examples:

```text
Template:  Hello, {NAME}.
NAME:      Alice
Output:    Hello, Alice.
```

```text
Template:  {A}
A:         {B}
B:         expanded
Output:    {B}
```

```text
Template:  keep {UNKNOWN} and ${SHELL} and {bad key}
Output:    keep {UNKNOWN} and ${SHELL} and {bad key}
```

There SHALL be no strict unknown-macro mode in v1.

## Considered Alternatives

### Use `eval` or shell expansion

This would make substitution implementation compact and would provide many
features automatically.  It was rejected because it turns data into code and
creates command-execution, quoting, and injection risks.

### Recursively expand inserted values

Recursive rendering can be useful for composing templates.  It was rejected
because output would depend on hidden transitive relationships between context
values, cycles would require policy, and one render would no longer mean one
substitution pass.

### Fail on unknown macros

Strict validation can detect missing context.  It was not selected for v1
because templates may intentionally contain macros for another stage or may be
rendered incrementally.  Literal preservation is deterministic and lossless.

### Delete or blank unknown macros

This was rejected because it destroys information and makes missing context
harder to diagnose.

## Consequences

Templates and values can safely contain shell metacharacters without special
escaping for `mktext`.

Typos in macro names are preserved rather than automatically diagnosed as
errors.  Callers that require completeness may compare output, pre-validate
known macros, or add a future explicitly designed strict layer outside v1.

The renderer remains intentionally less expressive than general template
engines.

## Open Questions and Follow-Ups

A strict validation mode may be considered later only if concrete callers need
it.  Such a feature should not change the default preservation semantics.

## Related Decisions

- Related to: ADR-001
- Related to: ADR-004
- Related to: ADR-006
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
