# ADR-013: Configure Render Delimiters Per Invocation

Date: 2026-08-15

## Status

Accepted

## Intent and Documentation Posture

This ADR extends `mktext render` so one caller-owned context can render templates
that use different literal marker syntaxes, including legacy templates whose
keys appear without surrounding delimiters.

The extension preserves the existing rendering security model and keeps delimiter
configuration out of the caller's associative-array data.

## Context

The original v1 grammar uses `{` and `}` around template keys.  That syntax is
appropriate for native `mktext` templates, but some existing consumers have
legitimate templates with other marker conventions.  In particular, legacy
`adr-tools` templates use bare uppercase keys such as `TITLE`, while other common
template formats use pairs such as `{{` and `}}`.

Rewriting those templates before rendering would add another transformation step
and make compatibility depend on an external preprocessor.  Storing delimiter
configuration as special entries in the caller's context would create a different
problem: the accepted architecture defines that associative array as
caller-owned substitution data, and readonly contexts are valid for rendering.
An initialization lifecycle or hidden metadata would therefore weaken an
established boundary.

Empty delimiters also require a deliberate lexical rule.  Naive fixed-string
replacement of every known key would allow `TITLE` to match inside `SUBTITLE`.
Sorting known keys from longest to shortest reduces some overlap cases but does
not solve the case where only the shorter key exists.  Regular-expression word
boundaries introduce their own grammar mismatch because `-` is a valid `mktext`
key character but is not normally a regex word character.

Issue #5 established the concrete compatibility requirement and the maintainer
approved the per-render option model and complete-token bare-key semantics.

## Decision Drivers

- Preserve `{` and `}` as the backward-compatible defaults.
- Reuse `mktext` across legitimate template syntaxes without preprocessing.
- Keep delimiter configuration attached to one render operation rather than to
  caller-owned context state.
- Preserve readonly contexts and avoid initialization or hidden metadata.
- Keep delimiters literal so callers do not need regular-expression escaping.
- Preserve the existing key grammar, including hyphens and underscores.
- Prevent substring replacement such as `TITLE` inside `SUBTITLE`.
- Keep inserted values literal and nonrecursive.
- Keep the public extension small and deterministic.

## Decision

The public render form SHALL be:

```text
mktext render CONTEXT [--start-delimiter STRING] [--end-delimiter STRING]
```

The default delimiter values SHALL remain:

```text
start = "{"
end   = "}"
```

The delimiter options apply only to the current render invocation.  `mktext`
SHALL NOT store delimiter values, initialization flags, or other rendering
configuration inside the caller's context.

The options SHALL appear after `CONTEXT`, MAY appear in either order, and SHALL
each appear at most once.

Delimiter strings SHALL be literal text.  They SHALL NOT be interpreted as
regular expressions or shell syntax.  Non-empty delimiters MAY contain multiple
characters.  Delimiters containing newline characters SHALL be rejected because
rendering remains line-local.

The start and end delimiters SHALL either both be non-empty or both be empty.
One-sided empty delimiter behavior is intentionally undefined in this decision
and SHALL be rejected as invalid API usage.

### Non-empty delimiter mode

When both delimiters are non-empty, a macro SHALL have this form:

```text
START OPTIONAL-BLANKS KEY OPTIONAL-BLANKS END
```

`KEY` retains the accepted grammar:

```text
[A-Za-z][A-Za-z0-9_-]*
```

Delimited keys SHALL retain the established uppercase normalization before
context lookup.  Unknown macros SHALL remain unchanged.

When the selected delimiters are the default `{` and `}`, the historical
exclusions for `${TITLE}` and `{{TITLE}}` SHALL remain unchanged.  A caller that
explicitly selects `{{` and `}}` MAY therefore render `{{TITLE}}` without
changing the default grammar.

### Empty delimiter mode

When both delimiters are empty, `render` SHALL use bare-key tokenization rather
than substring replacement.

The scanner SHALL identify maximal runs composed of characters from:

```text
[A-Za-z0-9_-]
```

A complete run SHALL be eligible for replacement only when the complete run
satisfies the normal key grammar:

```text
[A-Za-z][A-Za-z0-9_-]*
```

Bare-key lookup SHALL be exact and case-sensitive.  The token SHALL NOT be
uppercased or otherwise normalized before lookup.

Consequently, with `TITLE=Example` in a normally populated context:

```text
TITLE      -> Example
SUBTITLE   -> SUBTITLE
title      -> title
Title      -> Title
1TITLE     -> 1TITLE
_TITLE     -> _TITLE
-TITLE     -> -TITLE
```

`FOO-BAR` and `FOO_BAR` remain distinct complete tokens and require no escaping.

A maximal run that is not a valid key, or a valid bare key that is absent from
the context, SHALL be preserved exactly.  The scanner SHALL NOT search inside
that run for a shorter known key.

### Shared rendering semantics

Both modes SHALL preserve the accepted rendering guarantees:

- template and delimiter text are data, not executable code;
- replacement values are inserted literally;
- inserted values are not rescanned;
- unknown or malformed template text is preserved;
- rendering remains line-local and streaming;
- final-newline behavior remains unchanged;
- readonly contexts remain valid for rendering.

Invalid render options, missing option values, duplicate delimiter options,
one-sided empty delimiters, or newline-containing delimiters SHALL return the
public invalid-usage status 2 with a diagnostic and usage information on standard
error.

## Considered Alternatives

### Store delimiters and initialization state in the context

Special keys such as `_starting_delimiter`, `_ending_delimiter`, and an
initialization marker would make rendering configuration persistent.  This was
rejected because the context is caller-owned substitution data, readonly
contexts are valid render inputs, and no initialization mutation is necessary to
express defaults.

### Expose delimiter regular expressions

Regex delimiters could express word boundaries and other patterns, but they
would require callers to understand and escape regex syntax, introduce malformed
regex failure behavior, and make valid key characters such as `-` interact with
a separate boundary grammar.  Literal delimiters are easier to reason about and
meet the demonstrated use cases.

### Replace known keys from longest to shortest

Processing longer context keys first avoids some overlapping substitutions, but
it does not prevent `TITLE` from matching inside `SUBTITLE` when `SUBTITLE` is
not itself present in the context.  It also encourages repeated mutation of an
intermediate string, which requires additional safeguards to preserve
nonrecursive rendering.

### Preprocess legacy templates

A caller could rewrite legacy templates into `{KEY}` syntax before calling
`mktext`.  This was rejected because it creates a second transformation layer
for behavior `mktext` can express deterministically within its rendering
boundary.

### Add a separate legacy renderer to adrctl

A second renderer would keep `mktext` unchanged but duplicate substitution
semantics and security responsibilities.  Configurable rendering lets `adrctl`
use one established dependency for both modern and legacy templates.

### Support one-sided empty delimiters now

Forms such as `$NAME` can be useful, but their lexical boundary behavior has not
been specified or required by the demonstrated use case.  Defining them now
would enlarge the public contract without evidence.  A future ADR may add that
behavior deliberately.

## Consequences

Existing `mktext render CONTEXT` callers retain their current behavior.

A caller can render `{{KEY}}` or another literal-delimiter grammar without
modifying the context or preprocessing the template.

Legacy templates containing complete uppercase bare keys can be rendered through
the same `mktext` implementation.

Bare mode is intentionally case-sensitive, which protects ordinary lower- and
mixed-case prose from accidental replacement when public contexts contain
canonical uppercase keys.

The render dispatcher and behavior suite gain option/configuration cases, but no
new public function, persistent configuration object, runtime dependency, or
expression language is introduced.

Delimiter configuration becomes part of the public compatibility surface.

## Open Questions and Follow-Ups

One-sided empty delimiters remain intentionally unspecified.  A future concrete
use case may propose their lexical semantics separately.

## Related Decisions

- Refines: ADR-003
- Refines: ADR-004
- Refines: ADR-005
- Related to: ADR-006
- Related to: ADR-007
- Related to: ADR-009
- Related issue: `wesley-dean/mktext#5`
