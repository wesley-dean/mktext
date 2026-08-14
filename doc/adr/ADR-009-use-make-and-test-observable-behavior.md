# ADR-009: Use Make and Test Observable Behavior

Date: 2026-08-14

## Status

Proposed

## Intent and Documentation Posture

This ADR defines the development and CI orchestration surface and the testing
philosophy for `mktext`.

## Context

A Bash project can easily accumulate slightly different commands in developer
documentation, local habits, pre-commit hooks, and GitHub Actions.  A small
Makefile provides one discoverable interface that each environment can reuse.

The implementation is also expected to evolve.  Tests that depend on private
helper names or source layout would make refactoring harder without protecting
user-visible contracts.

ADR-008 establishes a narrow generated distribution artifact.  That creates two
important validation surfaces: the maintained source must remain directly
usable for development, and the generated artifact must behave identically while
also carrying the expected build metadata.

The design handoff selects Bats, ShellCheck, shfmt, and Doxygen-style
documentation as the expected engineering toolchain.

## Decision Drivers

- Keep local and CI validation aligned.
- Make common project commands easy to discover.
- Protect public behavior rather than incidental implementation structure.
- Keep the toolchain conventional for Bash.
- Validate both maintained source and the exact sourceable artifact users receive.
- Keep release metadata injection under automated regression coverage.

## Decision

The project SHALL use Make as the canonical orchestration interface for common
development tasks.

The Makefile SHALL provide, at minimum, stable targets for:

```text
build
check
format
test
test-source
test-dist
docs
all
clean
```

The exact underlying commands may evolve while target meanings remain stable.

`build` SHALL generate `dist/mktext.bash` from `src/mktext.bash` with the metadata
defined by ADR-008.

Bats SHALL be the primary automated test framework.

The primary behavior suite SHALL run against both `src/mktext.bash` and the
generated `dist/mktext.bash`.  Tests SHALL exercise the public `mktext` function
rather than depending on the path being tested.

The suite SHALL cover, at minimum:

- help aliases and usage output;
- version aliases and embedded metadata output;
- invalid-usage diagnostics and nonzero status;
- context validation;
- key normalization and validation;
- set/get/exists/unset semantics;
- recognized substitution;
- literal value insertion;
- nonrecursive rendering;
- unknown and malformed macro preservation;
- whitespace handling inside macros;
- exact final-newline preservation;
- return-status and diagnostic behavior.

The Bash-only compatibility harness SHALL be capable of exercising either the
maintained source or generated artifact and SHALL be run under the minimum
supported Bash release in CI.

Private helpers may receive direct tests when necessary for difficult logic, but
such tests are exceptions rather than the default strategy.

ShellCheck and shfmt SHALL be the canonical shell static-analysis and formatting
tools.  Static analysis and formatting SHALL target hand-maintained source rather
than treating generated `dist/` output as a second source of truth.

Doxygen-compatible source comments SHALL be used as defined separately.

CI SHOULD invoke Make targets rather than duplicating their underlying commands.

## Considered Alternatives

### Put commands directly in GitHub Actions

This is workable for a small repository but creates an immediate opportunity for
local and CI behavior to drift.

### Test only maintained source

That provides fast implementation feedback but leaves metadata injection and the
actual release artifact unverified.

### Test only the generated artifact

That protects consumers but makes source-only development failures harder to
localize and can hide assumptions that exist only because the build prelude is
present.  Exercising both surfaces is inexpensive for this project.

### Use a custom Bash task runner

A project-specific task runner would duplicate a capability Make already
provides.

### Test private functions extensively

Unit-level tests can be useful, but making them the primary suite would couple
correctness to the current implementation rather than the documented public
contract.

## Consequences

A contributor can reproduce the important CI behaviors through Make.

The same behavior suite protects maintained source and published distribution
semantics.

Refactoring internal helpers should not require rewriting most tests when public
behavior remains unchanged.

Development tools are dependencies for contributors and CI, not runtime
dependencies for library consumers.

## Open Questions and Follow-Ups

Coverage thresholds are intentionally not established by this ADR.  The project
should prefer meaningful behavioral coverage over a numeric target without
context.

## Related Decisions

- Related to: ADR-008
- Related to: ADR-010
- Related to: ADR-011
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
