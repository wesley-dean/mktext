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
usable for development, and the generated artifact must preserve the sourced
library behavior while also carrying the expected build metadata and supporting
its documented direct-execution interface.

The design handoff selects Bats, ShellCheck, shfmt, and Doxygen-style
documentation as the expected engineering toolchain.

## Decision Drivers

- Keep local and CI validation aligned.
- Make common project commands easy to discover.
- Keep the default Make invocation focused on producing the consumer artifact.
- Keep validation explicit rather than hiding tests behind a build target.
- Protect public behavior rather than incidental implementation structure.
- Keep the toolchain conventional for Bash.
- Validate both maintained source and the exact sourceable/executable artifact
  users receive.
- Keep release metadata injection under automated regression coverage.
- Exercise direct artifact invocation under the minimum supported Bash release.

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
and executable artifact properties defined by ADR-008.

`all` SHALL be the default build target and SHALL produce the same distribution
artifact as `build`.  It SHALL NOT implicitly run `check`, `test`, or other
validation targets.  Validation SHALL remain available through explicit Make
targets so callers can choose build-only or build-and-validate behavior without
surprise.

Bats SHALL be the primary automated test framework.

The primary behavior suite SHALL run against both `src/mktext.bash` and the
generated `dist/mktext.bash`.  Tests SHALL exercise the public `mktext` function
rather than depending on private helpers or incidental source structure.

The suite and compatibility checks SHALL cover, at minimum:

- help aliases and usage output;
- version aliases and embedded metadata output;
- invalid-usage diagnostics and nonzero status;
- direct execution of generated-artifact help and version forms;
- direct-execution status propagation for missing or unknown operations;
- generated-artifact executable mode and interpreter directive;
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
supported Bash release in CI.  When the selected target is the executable
distribution artifact, that harness SHALL exercise the direct-execution surface
as well as sourced-library behavior.

Private helpers may receive direct tests when necessary for difficult logic, but
such tests are exceptions rather than the default strategy.

ShellCheck and shfmt SHALL be the canonical shell static-analysis and formatting
tools.  Static analysis and formatting SHALL target hand-maintained source rather
than treating generated `dist/` output as a second source of truth.

Doxygen-compatible source comments SHALL be used as defined separately.

CI SHOULD invoke explicit Make validation targets rather than duplicating their
underlying commands or relying on `all` to perform validation implicitly.

## Considered Alternatives

### Make `all` build and validate everything

This is convenient for CI, but makes the default build command perform more work
than its name suggests and couples artifact generation to development-tool
dependencies.  Explicit `check` and `test` targets make validation equally
reproducible without surprising callers who only want the built artifact.

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

### Test the generated artifact only by sourcing it

That would verify library semantics while missing defects in executable mode,
interpreter placement, argument dispatch, and process-status propagation.  The
distribution artifact is a documented executable surface, so direct execution
must be exercised explicitly.

### Use a custom Bash task runner

A project-specific task runner would duplicate a capability Make already
provides.

### Test private functions extensively

Unit-level tests can be useful, but making them the primary suite would couple
correctness to the current implementation rather than the documented public
contract.

## Consequences

A contributor can build the consumer artifact with `make` or `make all` without
also invoking the development validation toolchain.

A contributor or CI job can reproduce validation explicitly with `make check`
and `make test`.

The same behavior suite protects maintained source and published distribution
semantics, while compatibility checks also protect the executable distribution
entry point.

Refactoring internal helpers should not require rewriting most tests when public
behavior remains unchanged.

Development tools are dependencies for contributors and CI, not runtime or
build-only dependencies for library consumers.

## Open Questions and Follow-Ups

Coverage thresholds are intentionally not established by this ADR.  The project
should prefer meaningful behavioral coverage over a numeric target without
context.

## Related Decisions

- Related to: ADR-008
- Related to: ADR-010
- Related to: ADR-011
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
