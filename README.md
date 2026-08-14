# mktext

`mktext` is a tiny deterministic Bash text-substitution library.

It replaces named macros such as `{TITLE}` or `{NUMBER4}` with literal values
from a caller-owned Bash associative array.

Its design is intentionally narrow:

```text
Acquisition    -> caller
Transformation -> caller
Rendering      -> mktext
```

`mktext` does not generate dates, inspect Git, create UUIDs, slugify text, pad
numbers, evaluate expressions, execute template code, or provide a general
programming language.  Callers prepare values.  `mktext` substitutes them.

## Requirements

Runtime requirements are intentionally small:

- Bash 4.3 or newer
- no external runtime commands for ordinary `mktext` operations

Bash cannot represent NUL bytes in variables, so `mktext` is a text library and
does not claim binary-safe behavior.

## Installation

The canonical runtime artifact is `mktext.bash`.

Source it from a supported Bash process:

```bash
. ./mktext.bash
```

Published consumers should pin a tagged release rather than depending on the
moving `main` branch.

## Basic Usage

Create an associative-array context, populate values, and render template text:

```bash
declare -A context=()

mktext set context TITLE "Fewer Incidents"
mktext set context NUMBER4 "0042"

printf '%s\n' 'ADR {NUMBER4}: {TITLE}' | mktext render context
```

Output:

```text
ADR 0042: Fewer Incidents
```

The public operations are:

```text
mktext set CONTEXT KEY VALUE
mktext get CONTEXT KEY
mktext exists CONTEXT KEY
mktext unset CONTEXT KEY
mktext render CONTEXT
```

Context variable names must be legal Bash identifiers and must not begin with
the private `__mktext_` prefix.  Readonly associative arrays may be used with
`get`, `exists`, and `render`; mutating operations reject them.

## Macro Grammar

Keys use this grammar before case normalization:

```text
[A-Za-z][A-Za-z0-9_-]*
```

Template macros use one pair of braces and may contain spaces or horizontal
tabs around the key:

```text
{TITLE}
{ title }
{NUMBER4}
```

Keys are normalized to uppercase.  Hyphens and underscores remain distinct.

## Rendering Semantics

Rendering is lexical, literal, and single-pass.

- Template text is never evaluated as shell code.
- Context values are inserted exactly as stored.
- Inserted values are not rescanned for additional macros.
- Unknown recognized macros remain unchanged.
- Malformed or unrelated brace text remains unchanged.
- Macros do not span input newlines.
- `render` reads standard input and writes standard output.
- Whether the input ended with a newline is preserved.

For example:

```bash
declare -A context=()
mktext set context A '{B}'
mktext set context B 'expanded'
printf '%s' '{A}' | mktext render context
```

produces:

```text
{B}
```

rather than `expanded`.

## Return Statuses

The public status contract is:

```text
0  success, or a predicate is true
1  requested key is absent for get/exists
2  invalid operation name, arity, or other API usage
3  invalid context reference, readonly mutation, or invalid key
4  data input/output failure
```

Diagnostics are written to standard error.  Rendered data and `get` values use
standard output.

## Development

The project follows documentation-driven, test-second development.

Common development tasks are exposed through Make targets:

```bash
make check
make format
make test
make docs
make all
```

Bats is the primary behavior-test framework.  ShellCheck and shfmt are the
canonical Bash static-analysis and formatting tools.

## Architecture

Architecture Decision Records are stored in `doc/adr/`.

The normative public behavior is documented in `doc/mktext-spec.md`.

AI-assisted contributors should also review `AGENTS.md` before making
substantive changes.

## License

See [LICENSE](LICENSE).

## Contributing

Contributions are welcome.  Please read [CONTRIBUTING.md](CONTRIBUTING.md) and
follow the project's documented architecture and behavior contracts.
