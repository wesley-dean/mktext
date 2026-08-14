# mktext Behavioral Specification

## Purpose

This document is the normative behavioral specification for the public `mktext`
API.

Architecture Decision Records under `doc/adr/` explain why these behaviors were
selected.  This specification describes the current contract that implementations
and tests are expected to satisfy.

Normative terms such as SHALL, SHALL NOT, SHOULD, and MAY are used deliberately.

## Runtime Model

`mktext` is a sourceable Bash library.

The canonical runtime artifact is:

```text
mktext.bash
```

The library requires Bash 4.3 or newer.

Normal library operations shall not require external runtime commands.

The library does not support NUL bytes because Bash variables cannot represent
NUL bytes faithfully.

## Public Namespace

The library SHALL expose one public function:

```text
mktext
```

Other functions, variables, or implementation details are private unless a
future public specification explicitly defines them otherwise.

Private implementation variables and helper functions use the `__mktext_`
prefix.  Caller context variables SHALL NOT use that reserved prefix.

The public operation forms are:

```text
mktext set CONTEXT KEY VALUE
mktext get CONTEXT KEY
mktext exists CONTEXT KEY
mktext unset CONTEXT KEY
mktext render CONTEXT
```

An operation invoked with the wrong number of arguments SHALL fail with status
2 and a diagnostic on standard error.

An unknown operation SHALL fail with status 2 and a diagnostic on standard
error.

The library SHALL return to its caller.  Ordinary library errors SHALL NOT call
`exit`.

## Context Requirements

`CONTEXT` SHALL be the name of an existing Bash associative-array variable.

Example:

```bash
declare -A context=()
```

A context name SHALL first be validated as a legal Bash identifier:

```text
[A-Za-z_][A-Za-z0-9_]*
```

A context name beginning with `__mktext_` is reserved for private library state
and SHALL fail validation with status 3.

The referenced variable SHALL then be verified to exist as an associative array
before the implementation creates or uses a nameref for it.

An invalid context name, a missing variable, or a variable of the wrong type
SHALL fail with status 3 and a diagnostic on standard error.

Readonly associative arrays are valid contexts for `get`, `exists`, and
`render`.  `set` and `unset` SHALL reject readonly contexts with status 3 and a
diagnostic before attempting a Bash mutation.

The library SHALL NOT create an implicit default context.

## Key Grammar and Normalization

Keys supplied to `set`, `get`, `exists`, and `unset` SHALL match:

```text
[A-Za-z][A-Za-z0-9_-]*
```

Surrounding whitespace is not part of the API key grammar.

A valid key SHALL be normalized to uppercase before storage, lookup, or removal.

Examples:

```text
title      -> TITLE
Title      -> TITLE
number4    -> NUMBER4
foo-bar    -> FOO-BAR
foo_bar    -> FOO_BAR
```

Hyphen and underscore SHALL remain distinct.

Invalid keys SHALL fail with status 3 and a diagnostic on standard error.

## Context Operations

### set

Invocation:

```text
mktext set CONTEXT KEY VALUE
```

`set` SHALL store `VALUE` exactly as supplied under the normalized key.

The empty string is a valid value.

Embedded newline characters are valid value content.

A readonly context SHALL be rejected with status 3 before mutation.

On success, `set` SHALL:

- return status 0;
- write nothing to standard output;
- write nothing to standard error.

### get

Invocation:

```text
mktext get CONTEXT KEY
```

When the normalized key exists, `get` SHALL:

- write the exact stored value to standard output;
- add no newline or other delimiter;
- return status 0;
- write nothing to standard error.

When the normalized key does not exist, `get` SHALL:

- write nothing to standard output;
- return status 1;
- treat absence as a normal negative result and emit no diagnostic.

Readonly contexts are valid for `get`.

### exists

Invocation:

```text
mktext exists CONTEXT KEY
```

When the normalized key exists, `exists` SHALL return 0.

When the normalized key does not exist, `exists` SHALL return 1.

`exists` SHALL write nothing to standard output or standard error for valid
queries.

An empty string value still counts as an existing key.

Readonly contexts are valid for `exists`.

### unset

Invocation:

```text
mktext unset CONTEXT KEY
```

`unset` SHALL remove the normalized key when it exists.

`unset` SHALL be idempotent.  A valid request for an already-absent key SHALL
still return 0.

A readonly context SHALL be rejected with status 3 before mutation.

On success, `unset` SHALL write nothing to standard output or standard error.

## Macro Grammar

A recognized template macro exists entirely on one physical input line and has
this form:

```text
{ OPTIONAL-BLANKS KEY OPTIONAL-BLANKS }
```

where:

```text
OPTIONAL-BLANKS := zero or more ASCII spaces or horizontal tabs
KEY             := [A-Za-z][A-Za-z0-9_-]*
```

Examples of recognized macros include:

```text
{TITLE}
{ title }
{\tTitle\t}
{foo-bar}
```

The normalized lookup key is uppercase.

The following are not recognized macros:

```text
{}
{ bad key }
{foo.bar}
{foo|upper}
{{TITLE}}
${TITLE}
{1TITLE}
```

Unrecognized brace text is ordinary template text.

A macro SHALL NOT span a newline delimiter.

## render

Invocation:

```text
mktext render CONTEXT
```

`render` SHALL read template text from standard input and write rendered text to
standard output.

Readonly contexts are valid for `render`.

The v1 API SHALL NOT accept a template filename argument.  Callers may use shell
redirection or pipelines.

### Recognized macro with a present key

For each recognized macro whose normalized key exists in the context, `render`
SHALL replace the complete macro text with the exact stored value.

Whitespace and case in the macro are lookup syntax only and SHALL NOT be
preserved around a successful replacement.

Example:

```text
Context:   TITLE=Example
Template:  [{ title }]
Output:    [Example]
```

### Recognized macro with an absent key

If a recognized macro's normalized key does not exist, `render` SHALL preserve
the original macro text exactly as it appeared in the template.

Example:

```text
Template:  [{ Missing }]
Output:    [{ Missing }]
```

Unknown macros are not render failures.

### Unrecognized or malformed brace text

Text that does not satisfy the macro grammar SHALL be copied unchanged.

Example:

```text
Template:  ${SHELL} {bad key} {{TITLE}}
Output:    ${SHELL} {bad key} {{TITLE}}
```

### Literal insertion

Context values SHALL be inserted literally.

The renderer SHALL NOT:

- evaluate shell syntax;
- perform parameter expansion;
- perform command substitution;
- interpret backticks;
- interpret quotes;
- interpret backslashes as shell escapes;
- `eval` template text;
- `source` template text or replacement values.

A value containing `$HOME`, `$(command)`, backticks, quotes, braces, or other
shell metacharacters SHALL appear literally in output.

### Nonrecursive rendering

Rendering SHALL perform one substitution pass.

Inserted values SHALL NOT be rescanned for additional macros.

Example:

```text
Context:
  A={B}
  B=expanded

Template:  {A}
Output:    {B}
```

### Multiple occurrences

Every recognized occurrence of a present key SHALL be replaced.

Example:

```text
Context:   X=value
Template:  {X}/{x}/{ X }
Output:    value/value/value
```

## Streaming and Line Termination

Rendering SHALL operate one physical newline-delimited input line at a time and
SHALL NOT require the entire template to be stored in one Bash variable.

The renderer SHALL preserve whether input lines were newline-terminated.

In particular:

- input ending with one newline SHALL produce output ending with one newline,
  unless replacement values deliberately add more content;
- input with no final newline SHALL produce output with no added final newline;
- empty input SHALL produce empty output;
- empty lines SHALL be preserved;
- CR characters are ordinary input data, allowing CRLF input to remain CRLF when
  no replacement changes that region.

Replacement values may themselves contain newline characters.  Those newlines
are intentional output data and do not change the fact that template scanning is
line-local.

## Standard Streams

Standard output is reserved for operation data:

- `get` values;
- rendered template output.

Diagnostics SHALL be written to standard error.

Successful `set`, `exists`, and `unset` operations SHALL not emit routine
progress text.

The library SHALL not provide general runtime logging in v1.

## Return Status Contract

The public status meanings are:

```text
0  operation succeeded, or a predicate is true
1  requested key is absent for get/exists
2  invalid operation name, arity, or other API usage
3  invalid context reference, readonly mutation, or invalid key
4  rendering input/output failure
```

No other public status meaning is defined for v1.

A future implementation may use additional internal statuses, but they SHALL be
translated to the documented public contract before returning from `mktext`.

## Determinism

Given the same template bytes representable by Bash, the same context, and the
same Bash version behavior relevant to this specification, `mktext` SHOULD
produce the same observable output and return status.

The library SHALL NOT acquire current time, random state, environment values,
Git state, network data, filesystem metadata, or other implicit external values
during ordinary substitution.

Callers may acquire those values explicitly and place them in the context before
rendering.

## Security Boundary

Templates SHALL be treated as untrusted data.

No template content or context value may cause code execution merely by being
rendered.

The renderer's security property is lexical non-execution, not sanitization for
a downstream language.

For example, if a caller renders a context value into a shell script, SQL query,
HTML page, YAML file, or another interpreted language, escaping requirements for
that downstream format remain the caller's responsibility.

`mktext` guarantees literal insertion; it does not guarantee that the resulting
text is safe for every consumer.

## Compatibility

The following are public compatibility surfaces:

- the public `mktext` function name;
- operation names and arity;
- context requirements and the reserved private prefix;
- readonly-context mutation behavior;
- key grammar and normalization;
- macro grammar;
- literal and nonrecursive rendering semantics;
- unknown/malformed preservation behavior;
- stream behavior and final-newline preservation;
- standard-output and standard-error roles;
- public return statuses;
- the sourceable `mktext.bash` artifact.

Changes to these surfaces require deliberate compatibility review and may
require a new ADR and Semantic Versioning impact.

## Non-Goals

The v1 specification does not include:

- strict unknown-macro validation;
- transformations or filters;
- expressions or arithmetic;
- conditionals or loops;
- includes or inheritance;
- template-file discovery;
- implicit context discovery;
- environment, Git, date, UUID, random, or filesystem acquisition;
- recursive substitution;
- plugins;
- binary/NUL-safe processing.
