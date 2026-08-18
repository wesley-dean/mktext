# AGENTS.md

This file provides guidance for AI coding agents working in this repository.

Use this file together with `README.md`.  The README is the human-facing project
overview.  This file is the agent-facing operational map.

## Project Overview

`mktext` is a tiny deterministic Bash text-substitution library.

Given template text and a named Bash associative-array context, it replaces
recognized macros such as `{TITLE}` or `{NUMBER4}` with literal values.

The project deliberately does less than a general template engine.  Acquisition
and transformation belong to callers.  `mktext` performs rendering only.

The canonical maintained implementation is `src/mktext.bash`.  `make build`
generates the canonical sourceable release artifact at `dist/mktext.bash` and
embeds version, source-revision timestamp, and commit metadata.  Bash 4.3+ callers
source the generated artifact in production use.

## Read the ADRs and Specification First

The ADR collection is the canonical source of architectural intent.

Before making significant changes, review the relevant files under `doc/adr/`.
Also review `doc/mktext-spec.md` when the change can affect public behavior.

In particular, preserve these foundational boundaries:

- `mktext` performs substitution, not acquisition or transformation;
- templates are untrusted data and are never executed or shell-expanded;
- context values are inserted literally;
- rendering is nonrecursive;
- unknown and malformed macro text is preserved by default;
- the public API is intentionally small and stable;
- deterministic, inspectable behavior is preferred over convenience features.

## Clarify Before Acting

When a request is ambiguous or incomplete, identify whether two reasonable
answers would produce meaningfully different software.

If they would, ask the minimum question necessary to resolve the architectural
ambiguity unless existing ADRs, the specification, tests, or repository context
already answer it.

If they would not, choose the conventional answer, state a material assumption
when useful, and continue.

Do not invent rationale when the repository does not establish it.

## Architectural Principles

- Bash 4.3+ is the minimum runtime.
- `src/mktext.bash` is the maintained implementation.
- `dist/mktext.bash` is the generated, sourceable release artifact.
- Build metadata is injected at build time and does not add runtime Git access.
- `make build` and `make all` do not acquire, synchronize, or verify external
  documentation dependencies.
- Make directly bootstraps only the pinned released `vendor/bashdeps.bash` used by
  documentation dependency management.
- Ordinary externally acquired repository artifacts are declared in
  `dependencies.txt` and synchronized by bashdeps under ADR-016.
- The current manifest-managed artifact is only the Bash Doxygen filter used by
  `make docs`.
- One public `mktext` function dispatches context, rendering, help, and version
  forms.
- Callers own Bash associative-array contexts.
- Keys are normalized to uppercase and follow the documented ASCII grammar.
- Rendering is lexical, literal, single-pass, and nonrecursive.
- Templates and values are never evaluated as shell code.
- Rendering reads standard input and writes standard output.
- Exact line termination is part of the public behavior.
- No implicit external state is acquired by ordinary rendering operations.
- Keep the core intentionally small.

## Technology Stack

Runtime:

- Bash 4.3+
- Bash builtins and language features

Development:

- Make
- Bats
- ShellCheck
- shfmt
- bashdeps for exact external documentation artifacts
- Doxygen-compatible source documentation
- GitHub Actions

## Coding Guidelines

Prefer small, readable Bash functions with explicit responsibilities.

Avoid `eval` categorically in rendering or context handling.

Do not `source` template, context, or dependency-manifest data.

Do not use command substitution, parameter expansion, or shell parsing to
interpret template content.

Quote expansions deliberately.  Preserve arbitrary context values literally.

Validate a context name and its associative-array type before creating a
nameref.

Do not add external runtime commands when Bash builtins can implement the
required behavior clearly and safely.

Private helpers and metadata variables use the reserved `__mktext_` namespace.
Do not expand the public namespace without an architectural decision.

## Build and Release Boundaries

Treat `src/mktext.bash` as the source of truth.  Do not edit generated
`dist/mktext.bash` directly.

Keep the build step narrow: inject metadata and copy maintained source.  Do not
introduce modular assembly, minification, transpilation, another template
language, dependency synchronization, or documentation tooling into the consumer
build without a demonstrated need and an architectural decision.

`make build` and `make all` SHALL remain network-free with respect to project
artifact acquisition.  They do not require bashdeps, `dependencies.txt`, or the
`vendor/` tree.  A clean checkout can build the consumer artifact without
preparing documentation dependencies.

External documentation inputs are prepared separately:

```text
make deps
```

may bootstrap the pinned released `vendor/bashdeps.bash` and synchronize the
committed `dependencies.txt` manifest.  Make directly owns only that one bootstrap
artifact.  The bootstrap is pinned by immutable release URL and SHA-256 digest and
is deliberately excluded from its own consumer manifest.

```text
make deps-check
```

verifies the already-present bootstrap and manifest-managed dependency state
without network access or repair.  Do not make `deps-check` depend on the bootstrap
file target, because that would silently turn verification into acquisition.

The current manifest contains only `vendor/doxygen-bash.awk`.  `make docs` invokes
`make deps` because reference generation needs that filter.  Do not reintroduce a
direct moving `main`/`master` download path for the filter or duplicate substantial
bashdeps policy in Make.

Treat `dependencies.txt` as reviewed project source and `vendor/` as ignored,
generated dependency state.  Digest equality, not the destination filename,
defines acceptable external bytes.  Download candidates must be verified before
publication, and acquisition failure must not replace an existing file with
unverified bytes.

Release versions come from the semantic-version workflow and are passed
explicitly to Make.  Development builds use the documented development version.
Commit metadata and the build date are derived from the source revision when Git
metadata is available.

The released `dist/mktext.bash` artifact must remain independent of bashdeps,
`dependencies.txt`, the Doxygen filter, and `vendor/`.  The release workflow does
not prepare documentation dependencies merely to build the consumer artifact.

Tests must cover both maintained source and generated distribution behavior.

## Scope Discipline

Unless explicitly requested otherwise, produce the smallest correct change that
satisfies the requested behavior and the existing architecture.

Do not expand the project into a general template language.

Features such as filters, expressions, loops, conditionals, includes,
slugification, case conversion, numeric padding, date generation, UUIDs, Git
queries, environment acquisition, and plugin systems belong outside the core
unless a later ADR deliberately changes that boundary.

Do not perform unrelated refactoring, formatting, renaming, or documentation
changes in a focused patch.

If additional improvement opportunities are discovered, report or record them
separately rather than silently broadening the change.

Documentation-only requests must preserve executable behavior exactly.

## Documentation Standards

Follow the documentation-driven philosophy established by the ADRs.

Documentation should explain intent, assumptions, constraints, safety posture,
observable behavior, and non-goals where appropriate.

Source-code documentation follows ADR-011.  Documentation generation and its
external dependency lifecycle follow ADR-015 and ADR-016.  When a
documentation-only source change is requested, preserve executable lines verbatim
and verify that only comments changed.

When intent cannot be established confidently, expose the ambiguity rather than
writing plausible-sounding rationale.

## Testing

The project follows documentation-driven, test-second development.

Documentation establishes intent.  Implementation realizes it.  Automated tests
then verify observable behavior.

Use Bats for the primary behavior suite and for repository build/dependency
boundary regression coverage.

Tests should exercise the public `mktext` function rather than private helper
structure whenever practical.

Run the behavior suite against both `src/mktext.bash` and the generated
`dist/mktext.bash`.  The generated artifact is a product artifact and must not be
assumed correct merely because its maintained source passed tests.

Build/dependency tests should verify observable Make contracts rather than private
bashdeps internals.  In particular, protect the facts that `build` and `all` do not
materialize documentation dependency state, `deps-check` does not repair state,
and the literal consumer artifact works after the dependency tree is removed.

Every functional change should prompt these questions:

- What observable behavior changed?
- Which documented contract governs that behavior?
- How can the behavior be verified automatically?
- Does the change affect final-newline, quoting, literal-value, usage, version,
  or return-status semantics?

Bug fixes should add or update a regression test that would have failed before
the fix.

A behavioral change is normally incomplete when corresponding documentation or
tests are missing.

## Validation

When practical:

- review the resulting diff;
- run the relevant Make targets;
- run Bash syntax validation;
- run Bats tests against source and distribution artifacts;
- run the build/dependency boundary tests;
- run ShellCheck and shfmt checks on maintained source;
- use `make deps` and `make deps-check` when documentation dependency state is in
  scope;
- generate or validate documentation when documentation inputs change;
- verify a clean `make build` does not materialize `vendor/`;
- verify generated artifact metadata when build behavior changes;
- verify documentation-only source changes did not alter executable lines.

If a validation tool is unavailable, do not invent its result.  Report only what
was actually verified.

## Common Failure Modes

Avoid:

- editing `dist/mktext.bash` as though it were maintained source;
- releasing a distribution artifact carrying stale or mismatched version
  metadata;
- coupling `make build` or `make all` to documentation dependency acquisition;
- making `make deps-check` bootstrap, download, or repair dependency state;
- placing `vendor/bashdeps.bash` in `dependencies.txt` and creating a bootstrap
  cycle;
- reintroducing direct Makefile acquisition for manifest-managed dependencies;
- using moving dependency URLs when an immutable release or tag is available;
- trusting a dependency filename or version label instead of the committed digest;
- adding transformations because they appear convenient;
- using `eval` or shell expansion for substitution;
- rescanning replacement values and accidentally making rendering recursive;
- deleting or normalizing unknown macro text;
- buffering the entire template and losing trailing-newline fidelity;
- accepting malformed context names before creating namerefs;
- treating `-` and `_` as equivalent keys;
- writing diagnostics to standard output;
- returning success for invalid API usage;
- calling `exit` from ordinary library error paths;
- testing private implementation details as though they were public contracts;
- inventing architectural rationale;
- silently expanding scope.

## Final Principle

`mktext` knows how to replace names with values and almost nothing else.

Every change should preserve that clarity and leave the repository easier for
the next contributor to understand.
