# mktext

[![Dependabot Updates](https://github.com/wesley-dean/mktext/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/wesley-dean/mktext/actions/workflows/dependabot/dependabot-updates)
[![MegaLinter](https://github.com/wesley-dean/mktext/actions/workflows/megalinter.yml/badge.svg)](https://github.com/wesley-dean/mktext/actions/workflows/megalinter.yml)
[![Scorecard supply-chain security](https://github.com/wesley-dean/mktext/actions/workflows/scorecard.yml/badge.svg)](https://github.com/wesley-dean/mktext/actions/workflows/scorecard.yml)
[![Tests](https://github.com/wesley-dean/mktext/actions/workflows/test.yml/badge.svg)](https://github.com/wesley-dean/mktext/actions/workflows/test.yml)
[![Documentation](https://github.com/wesley-dean/mktext/actions/workflows/static.yml/badge.svg)](https://github.com/wesley-dean/mktext/actions/workflows/static.yml)

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

The maintained implementation lives at `src/mktext.bash`.

A prepared build produces three sourceable and executable consumer flavors:

```text
dist/mktext.dev.bash
dist/mktext.bash
dist/mktext.min.bash
```

`mktext.dev.bash` retains the complete maintained source comments and is the most
convenient generated artifact for inspection and debugging.  `mktext.bash` is the
conventional distribution artifact with full-line maintained comments removed.
`mktext.min.bash` is produced by running the pinned Bash-Minifier dependency over
`mktext.bash`.

All three artifacts begin with an `#!/usr/bin/env bash` interpreter directive,
are created with mode `0755`, embed the same semantic version, source-revision
timestamp, and source commit, and implement the same public mktext behavior.
`dist/` is generated output and is not maintained as a second source copy.

Each Bash artifact has a companion SHA-256 checksum file:

```text
dist/mktext.dev.bash.sha256
dist/mktext.bash.sha256
dist/mktext.min.bash.sha256
```

The `.sha256` files use the conventional `sha256sum`/`shasum -a 256` check-file
format and name the corresponding artifact basename.  New releases publish only
`.sha256` checksum companions.  Historical releases that published `.256`
companions remain unchanged.

A tool that explicitly retrieves release checksum sidecars may try `.256` only
when the preferred `.sha256` asset is confirmed absent.  Transport,
authorization, server, malformed-content, and checksum-mismatch failures should
fail rather than trigger a legacy fallback.

This compatibility rule does not change mktext's dependency trust model.  The
repository continues to accept externally acquired dependency bytes only when
they match the SHA-256 digest committed in project source; a live `.sha256` or
`.256` sidecar does not replace that committed authorization.

Help and version information can be inspected directly without sourcing any
flavor, for example:

```bash
./dist/mktext.dev.bash --version
./dist/mktext.bash --help
./dist/mktext.min.bash --version
```

Direct process dispatch is intentionally limited to supported mktext executable
names: `mktext`, `mktext.bash`, `mktext.dev.bash`, and `mktext.min.bash`.  This
keeps the normal command behavior while allowing the same library code to be
embedded in a differently named Bash executable without claiming that program's
entry point.  Directory names containing `mktext` do not affect this decision.

Source whichever release flavor best fits the consumer's needs when using
caller-owned associative-array contexts:

```bash
. ./dist/mktext.bash
```

Context operations execute in the current shell because Bash associative arrays
are shell state and cannot be exported to a child process as ordinary environment
variables.

Published consumers should pin one of the three Bash assets from a tagged GitHub
release rather than depending on the moving `main` branch.  The conventional
`mktext.bash` flavor remains the default recommendation when neither retained
comments nor minimum file size is a specific requirement.

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

The public context and rendering operations are:

```text
mktext set CONTEXT KEY VALUE
mktext get CONTEXT KEY
mktext exists CONTEXT KEY
mktext unset CONTEXT KEY
mktext render CONTEXT [--start-delimiter STRING] [--end-delimiter STRING]
```

Help is available through equivalent forms:

```text
mktext help
mktext -h
mktext --help
```

Artifact version information is available through:

```text
mktext version
mktext --version
```

A generated release artifact reports three lines:

```text
mktext 0.1.0
build_date=2026-08-14T20:32:21+00:00
commit=91de217275bd
```

The exact values identify the built release and source revision.

Context variable names must be legal Bash identifiers and must not begin with
the private `__mktext_` prefix.  Readonly associative arrays may be used with
`get`, `exists`, and `render`; mutating operations reject them.

Invalid operation names, missing operations, and wrong argument counts return
status 2 and print a concise diagnostic followed by usage information to
standard error.  Explicit help requests print usage to standard output and
return 0.  When a supported generated artifact is executed directly, its process
exit status is the status produced by the same `mktext` dispatcher.

## Macro Grammar

Keys use this grammar before case normalization:

```text
[A-Za-z][A-Za-z0-9_-]*
```

By default, template macros use one pair of braces and may contain spaces or
horizontal tabs around the key:

```text
{TITLE}
{ title }
{NUMBER4}
```

Delimited macro keys are normalized to uppercase.  Hyphens and underscores
remain distinct.

### Configurable Delimiters

`render` accepts literal start and end delimiters for templates that use a
different marker syntax:

```bash
printf '%s\n' '{{TITLE}}' | mktext render context \
  --start-delimiter '{{' \
  --end-delimiter '}}'
```

Delimiters are literal strings, not regular expressions.  Multi-character and
regex-looking strings therefore require no regex escaping by the caller.

Set both delimiters to empty strings to render bare key tokens:

```bash
printf '%s\n' 'ADR NUMBER4: TITLE' | mktext render context \
  --start-delimiter '' \
  --end-delimiter ''
```

Bare-key mode scans complete tokens using the normal key grammar and performs an
exact, case-sensitive lookup.  It does not perform substring replacement.  For
example, if only `TITLE` is present, `TITLE` is replaced while `SUBTITLE`,
`title`, `1TITLE`, and `_TITLE` remain unchanged.  Keys such as `FOO-BAR` and
`FOO_BAR` remain complete, distinct tokens and need no escaping.

The two delimiters must both be non-empty or both be empty.  One-sided empty
delimiters are not defined by the current API.

## Rendering Semantics

Rendering is lexical, literal, and single-pass.

- Template text is never evaluated as shell code.
- Context values are inserted exactly as stored.
- Inserted values are not rescanned for additional macros.
- Unknown recognized macros and bare tokens remain unchanged.
- Malformed or unrelated template text remains unchanged.
- Delimited macros and bare tokens do not span input newlines.
- Configured delimiters are matched literally, never as regular expressions.
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
0  success, requested informational output succeeded, or a predicate is true
1  requested key is absent for get/exists
2  invalid operation name, arity, render option/configuration, or other API usage
3  invalid context reference, readonly mutation, or invalid key
4  distinguishable recoverable public-data input/output failure
```

Diagnostics are written to standard error.  Rendered data, `get` values, help,
and version output use standard output.

## Development

The project follows documentation-driven, test-second development.

Common development tasks are exposed through Make targets:

```bash
make deps         # synchronize build/development dependencies; may use the network
make deps-check   # verify prepared dependency state offline
make build        # offline build of all three Bash flavors and three checksums
make all          # run deps first, then build all six artifacts
make check        # syntax and static analysis
make test         # test source, all generated flavors, checksums, and dependency boundaries
make test-source
make test-generated
make test-build
make format
make docs         # synchronize dependencies, then generate reference docs
```

`make build` intentionally performs no dependency acquisition or verification.  It
requires a previously prepared `vendor/bash-minifier.bash` and fails with guidance
to run `make deps` or `make all` when that build dependency is absent.  `make all`
is the fresh-checkout convenience path and explicitly synchronizes dependencies
before invoking the build.

`make deps` directly bootstraps one pinned, SHA-256-verified released
`vendor/bashdeps.bash` when necessary, then uses that executable to synchronize
the ordinary dependencies declared in `dependencies.txt`.  The bootstrap artifact
is deliberately excluded from the manifest to avoid a circular dependency.

The manifest currently contains the commit-pinned Bash-Minifier artifact used by
`make build` and the pinned Bash Doxygen filter used by `make docs`.  Their
immutable URLs and expected SHA-256 digests are committed as reviewable project
data.  `make deps-check` verifies the existing bootstrap and manifest state without
network access or repair.

`make test` exercises the public behavior suite against maintained source and each
of `mktext.dev.bash`, `mktext.bash`, and `mktext.min.bash`; verifies direct
execution and Bash 4.3 compatibility; checks all three SHA-256 files; and exercises
the build/dependency boundary.

`make docs` may use the network because it invokes `make deps` before generating
the ignored `doc/reference/` site.  The Pages workflow uses the same path from
`main`, verifies the resulting dependency state, and deploys the generated site
directly without committing generated documentation.  `vendor/` and
`doc/reference/` remain ignored generated state and are removed by `make clean`.

Bats is the primary behavior-test framework.  ShellCheck and shfmt are the
canonical Bash static-analysis and formatting tools.

## Architecture

Architecture Decision Records are stored in `doc/adr/`.

The normative public behavior is documented in `doc/mktext-spec.md`.

ADR-018 records the checksum companion naming and historical-read compatibility
policy.

AI-assisted contributors should also review `AGENTS.md` before making
substantive changes.

## License

See [LICENSE](LICENSE).

## Contributing

Contributions are welcome.  Please read [CONTRIBUTING.md](CONTRIBUTING.md) and
follow the project's documented architecture and behavior contracts.
