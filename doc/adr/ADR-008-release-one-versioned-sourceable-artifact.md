# ADR-008: Release One Versioned Sourceable Artifact

Date: 2026-08-14

## Status

Proposed

## Intent and Documentation Posture

This ADR defines the consumer-facing release model and compatibility policy for
`mktext`.

## Context

The library is intentionally small enough that a generated distribution bundle
is unnecessary.  Introducing modular source assembly would add a second
representation of the code before the project has a need for it.

Consumers do need a stable artifact they can vendor or pin, and version numbers
should communicate compatibility expectations.

## Decision Drivers

- Keep source and released behavior easy to compare.
- Avoid generated artifacts without demonstrated need.
- Give downstream consumers stable versions to pin.
- Make compatibility changes deliberate.
- Preserve room for the internal implementation to evolve.

## Decision

The canonical runtime artifact SHALL be a single file named:

```text
mktext.bash
```

The maintained source file and the released library artifact SHALL be the same
file for v1.  The project SHALL NOT introduce a generated `dist/` copy or source
concatenation pipeline unless later complexity justifies it.

The project SHALL use Semantic Versioning for releases.

Git tags and GitHub Releases SHALL identify published versions.  Consumers
SHOULD pin a release or tag rather than source the moving `main` branch in
production automation.

Public compatibility includes:

- the `mktext` function and operation names;
- argument ordering and context semantics;
- macro grammar and normalization;
- rendering and preservation behavior;
- standard-output behavior;
- return-status meanings;
- the sourceable `mktext.bash` artifact.

Breaking public changes require deliberate migration guidance and normally a
major version increment.

When practical, stable public behavior should be deprecated before removal.
Experimental behavior, if ever introduced, must be explicit and must not be
mistaken for a stable v1 contract.

Release automation may add checksums or provenance attestations without changing
the library API.

## Considered Alternatives

### Generate a distribution file from modules

Bootstrap benefits from this model because its engine grew into multiple
responsibilities.  `mktext` begins with a deliberately tiny implementation, so
a build-time assembly layer would currently be machinery in search of a problem.

### Commit both source and generated release files

Maintaining two copies would create two candidate sources of truth and review
noise.

### Use calendar or ad-hoc versions

These schemes communicate recency but not compatibility impact as clearly as
Semantic Versioning.

## Consequences

Release review remains straightforward because the file users source is the file
maintainers edit and test.

If `mktext` eventually becomes large enough to require modular source files, a
future ADR may supersede this decision and introduce a deterministic build
artifact.

## Open Questions and Follow-Ups

The initial version number and exact release workflow are implementation and
release-management decisions to be established before the first public release.

## Related Decisions

- Related to: ADR-002
- Related to: ADR-003
- Related to: ADR-009
- Source assessment: `doc/bootstrap-adr-port-assessment.md`
