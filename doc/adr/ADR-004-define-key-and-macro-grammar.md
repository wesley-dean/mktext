# ADR-004: Define Key and Macro Grammar

Date: 2026-08-14

## Status

Accepted

## Intent and Documentation Posture

This ADR defines the lexical grammar used for context keys and template macros.
The grammar is deliberately small and ASCII-oriented so that matching and
normalization remain predictable across environments.

## Context

The expected template syntax is visually small:

```text
{TITLE}
{NUMBER4}
```

The design handoff also permits insignificant whitespace inside the braces and
calls for canonical uppercase keys.  It left the exact key grammar and hyphen
behavior unresolved.

Normalization rules must avoid surprising collisions.  Converting hyphens to
underscores, for example, would make two visibly different names address the
same value.

## Decision Drivers

- Make the grammar easy to recognize without a parser generator.
- Make case handling consistent between API keys and template macros.
- Permit useful conventional identifier characters.
- Avoid normalization rules that collapse distinct names.
- Keep macro recognition line-local for streaming rendering.

## Decision

API key arguments SHALL match this grammar before normalization:

```text
[A-Za-z][A-Za-z0-9_-]*
```

API keys SHALL NOT contain surrounding whitespace.

Valid API keys SHALL be normalized to uppercase using Bash's ASCII-compatible
case conversion before storage or lookup.

A template macro SHALL have this lexical form on one physical input line:

```text
{ OPTIONAL-BLANKS KEY OPTIONAL-BLANKS }
```

where:

- `OPTIONAL-BLANKS` means zero or more ASCII spaces or horizontal tabs;
- `KEY` follows the same identifier grammar as an API key;
- the normalized lookup key is uppercase.

Examples that address the same key include:

```text
{TITLE}
{ title }
{\tTitle\t}
```

where the last example represents literal horizontal-tab characters around the
key.

Hyphen (`-`) and underscore (`_`) SHALL remain distinct characters.  `FOO-BAR`
and `FOO_BAR` are different keys.

Characters outside the defined grammar, including internal whitespace, dots,
colons, pipes, expressions, or nested braces, do not form recognized macros.

## Considered Alternatives

### Uppercase-only input

Requiring callers and templates to use uppercase exactly would reduce
normalization work, but it would make harmless case variation a source of
errors.  Canonical uppercase storage provides stable identity without that
friction.

### Convert hyphens to underscores

This would make shell-style and human-style names interchangeable.  It was
rejected because normalization would create collisions and make the visible
macro name an unreliable representation of the stored key.

### Permit arbitrary characters between braces

A broad grammar would maximize flexibility, but it would complicate escaping,
future syntax, diagnostics, and security reasoning.

### Use Jinja-style double braces

`{{NAME}}` is familiar to many users, but `mktext` does not need to imitate a
larger template language.  Single braces keep the syntax compact and preserve
the existing design direction.

## Consequences

Macro parsing remains small and deterministic.

Names are case-insensitive for lookup but have one canonical stored form.

Some otherwise reasonable names, such as `release.version`, must be adapted by
the caller to a valid key such as `RELEASE_VERSION`.

## Open Questions and Follow-Ups

None for v1.  Expanding the grammar is a public compatibility decision because
previously literal text may become recognized syntax.

## Related Decisions

- Related to: ADR-003
- Related to: ADR-005
- Related to: ADR-006
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
