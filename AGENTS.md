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

The canonical runtime artifact is `mktext.bash`, which is intended to be sourced
by Bash 4.3+ callers.

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
- `mktext.bash` is the sourceable runtime and release artifact.
- One public `mktext` function dispatches the supported operations.
- Callers own Bash associative-array contexts.
- Keys are normalized to uppercase and follow the documented ASCII grammar.
- Rendering is lexical, literal, single-pass, and nonrecursive.
- Templates and values are never evaluated as shell code.
- Rendering reads standard input and writes standard output.
- Exact line termination is part of the public behavior.
- No implicit external state is acquired by the library.
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
- Doxygen-compatible source documentation
- GitHub Actions

## Coding Guidelines

Prefer small, readable Bash functions with explicit responsibilities.

Avoid `eval` categorically in rendering or context handling.

Do not `source` template or context data.

Do not use command substitution, parameter expansion, or shell parsing to
interpret template content.

Quote expansions deliberately.  Preserve arbitrary context values literally.

Validate a context name and its associative-array type before creating a
nameref.

Do not add external runtime commands when Bash builtins can implement the
required behavior clearly and safely.

Private helpers are implementation details.  Do not expand the public namespace
without an architectural decision.

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

Source-code documentation follows ADR-011.  When a documentation-only source
change is requested, preserve executable lines verbatim and verify that only
comments changed.

When intent cannot be established confidently, expose the ambiguity rather than
writing plausible-sounding rationale.

## Testing

The project follows documentation-driven, test-second development.

Documentation establishes intent.  Implementation realizes it.  Automated tests
then verify observable behavior.

Use Bats for the primary behavior suite.

Tests should exercise the public `mktext` function rather than private helper
structure whenever practical.

Every functional change should prompt these questions:

- What observable behavior changed?
- Which documented contract governs that behavior?
- How can the behavior be verified automatically?
- Does the change affect final-newline, quoting, literal-value, or return-status
  semantics?

Bug fixes should add or update a regression test that would have failed before
the fix.

A behavioral change is normally incomplete when corresponding documentation or
tests are missing.

## Validation

When practical:

- review the resulting diff;
- run the relevant Make targets;
- run Bash syntax validation;
- run Bats tests;
- run ShellCheck and shfmt checks;
- generate or validate documentation when documentation inputs change;
- verify documentation-only source changes did not alter executable lines.

If a validation tool is unavailable, do not invent its result.  Report only what
was actually verified.

## Common Failure Modes

Avoid:

- adding transformations because they appear convenient;
- using `eval` or shell expansion for substitution;
- rescanning replacement values and accidentally making rendering recursive;
- deleting or normalizing unknown macro text;
- buffering the entire template and losing trailing-newline fidelity;
- accepting malformed context names before creating namerefs;
- treating `-` and `_` as equivalent keys;
- writing diagnostics to standard output;
- calling `exit` from ordinary library error paths;
- testing private implementation details as though they were public contracts;
- inventing architectural rationale;
- silently expanding scope.

## Final Principle

`mktext` knows how to replace names with values and almost nothing else.

Every change should preserve that clarity and leave the repository easier for
the next contributor to understand.
