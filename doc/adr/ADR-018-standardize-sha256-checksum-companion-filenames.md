# ADR-018: Standardize SHA-256 Checksum Companion Filenames

Date: 2026-08-27

## Status

Accepted

## Intent and Documentation Posture

This Architecture Decision Record standardizes the filename suffix used for
SHA-256 checksum companions published with mktext release artifacts.

The change is deliberately narrow.  It changes release-sidecar names from `.256`
to `.sha256`; it does not change checksum contents, the SHA-256 algorithm, the
mktext public API, the build dependency model, or the repository's committed-digest
trust boundary.

This ADR supersedes only the checksum-filename portion of ADR-017.  ADR-017 remains
the historical record of the three-flavor release pipeline, Bash-Minifier build
dependency, checksum publication requirement, and dependency boundaries.

## Context

ADR-017 established one SHA-256 checksum companion for each generated mktext Bash
artifact using a `.256` suffix:

```text
mktext.dev.bash.256
mktext.bash.256
mktext.min.bash.256
```

The suffix works technically because checksum tools do not require a particular
filename extension, but `.256` is not self-describing.  A reader must already
know that the number refers to SHA-256 rather than another project-specific
convention.

The `.sha256` suffix names the algorithm directly and is easier to recognize
without repository-specific context.  Related Bash projects are adopting the same
convention, so aligning mktext avoids needless variation across release surfaces.

The migration must preserve two distinct concerns that should not be conflated.
Published checksum files are convenient release companions for humans and tools,
while mktext's external build/development dependencies are authorized by SHA-256
digests committed in repository source.  A naming change for published sidecars
must not cause live remote checksum files to become an implicit source of trust.

Historical mktext releases also remain part of the supported ecosystem.  Their
`.256` assets cannot be renamed without rewriting published release state, so
consumers that explicitly retrieve checksum companions need a narrow compatibility
rule spanning both naming eras.

## Decision Drivers

- Make the checksum algorithm evident from the sidecar filename.
- Use a consistent checksum naming convention across related Bash projects.
- Preserve the existing one-artifact/one-checksum relationship.
- Preserve conventional `sha256sum`/`shasum -a 256` checksum-file contents.
- Avoid publishing duplicate checksum assets indefinitely.
- Preserve access to historical releases that used `.256`.
- Fail closed instead of masking transport or verification problems as legacy
  compatibility.
- Preserve committed SHA-256 digests as the authority for external dependency
  acceptance.
- Leave mktext runtime behavior and source code unchanged.

## Decision

### Publish `.sha256` companions for new releases

`make build` SHALL produce these checksum files:

```text
dist/mktext.dev.bash.sha256
dist/mktext.bash.sha256
dist/mktext.min.bash.sha256
```

Each checksum file SHALL continue to contain the SHA-256 digest and matching
artifact basename in conventional checksum-tool syntax.  For example:

```text
0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  mktext.bash
```

The conventional artifact SHALL therefore be directly verifiable from the
distribution directory with:

```text
sha256sum -c mktext.bash.sha256
```

or the supported `shasum` equivalent.

New releases SHALL publish only the `.sha256` checksum companion for each Bash
artifact.  They SHALL NOT also publish duplicate `.256` companions merely for a
transition period.

The release artifact count remains six: three Bash artifacts and three checksum
companions.

### Preserve historical release assets

Existing releases and their `.256` checksum companions are historical published
artifacts and SHALL NOT be rewritten solely to adopt the new suffix.

A consumer that explicitly retrieves checksum companions from releases spanning
both naming eras SHOULD request `<artifact>.sha256` first.  It MAY retry
`<artifact>.256` only when the preferred `.sha256` asset is confirmed absent.

Legacy fallback SHALL NOT be used to recover from or conceal other failures,
including:

- TLS or certificate failures;
- authentication or authorization failures;
- timeouts or connection failures;
- HTTP server errors;
- malformed checksum contents; or
- a checksum mismatch.

Those conditions are failures and SHALL remain failures.

### Preserve committed-digest trust

This compatibility rule does not add checksum-sidecar discovery to mktext's
Make-owned bootstrap path or to bashdeps-managed dependency synchronization.

The Makefile continues to pin the released `vendor/bashdeps.bash` bootstrap by an
expected SHA-256 digest committed in repository source.  `dependencies.txt`
continues to pin ordinary external build/development artifacts by committed
`digest=sha256:...` values.

Neither bootstrap nor manifest synchronization SHALL dynamically replace a
committed expected digest with a value retrieved from `.sha256` or `.256`.

A maintainer or external helper may use an upstream checksum sidecar while
reviewing a dependency or release update, but committing the selected digest
remains the explicit authorization step.

### Preserve the existing build and runtime boundaries

This decision does not alter ADR-017's build pipeline:

```text
src/mktext.bash
  -> dist/mktext.dev.bash
  -> dist/mktext.bash
  -> dist/mktext.min.bash
```

`make build` remains network-free and consumes already-prepared Bash-Minifier
state.  `make all` remains the fresh-checkout convergence path that prepares
dependencies before building.  `make deps-check` remains offline and
non-repairing.

No maintained runtime source change is required.  Released mktext artifacts
remain independent of bashdeps, Bash-Minifier, the Doxygen filter,
`dependencies.txt`, and `vendor/` at runtime.

## Considered Alternatives

### Keep `.256`

This preserves historical naming and requires no migration, but the suffix does
not identify the checksum algorithm clearly and needlessly differs from the
self-describing convention adopted by related projects.

### Publish both `.sha256` and `.256`

Publishing both would make every new release immediately compatible with tools
that hard-code the legacy suffix.  It was rejected because both files would carry
the same information, permanently enlarge and clutter the release surface, and
make the deprecated convention appear equally current.

Read-side fallback provides compatibility with historical releases without
requiring duplicate write-side artifacts.

### Replace per-artifact companions with `SHA256SUMS`

An aggregate checksum file is conventional and compact, but ADR-017 deliberately
established a matching checksum companion for every published Bash artifact.  The
current decision changes only the suffix and does not revisit that artifact model.

### Dynamically trust remote checksum sidecars for dependencies

The Make bootstrap or dependency tooling could retrieve upstream checksum files
and use those values instead of committed digests.  This was rejected because it
would move authorization from reviewed repository source to live upstream state
and contradict ADR-016/017's exact-byte dependency boundary.

## Consequences

New mktext releases expose self-describing `.sha256` checksum filenames while
retaining the same checksum algorithm, contents, artifact count, and verification
workflow apart from the filename.

The Makefile, release workflow, build tests, behavioral specification, README, and
agent guidance use the new suffix consistently.

Consumers that rely only on committed digests require no behavior change.  Tools
that explicitly retrieve release checksum sidecars can support both naming eras
with a narrow absence-only fallback.

Historical `.256` assets remain valid for the releases that published them.

## Follow-Ups

Related Bash projects may adopt the same producer convention and legacy-read
policy in dependency-safe release order.

Any future feature that teaches mktext's repository bootstrap or dependency
workflow to discover and trust remote checksum sidecars would require a separate
architectural decision because it would change network behavior and the existing
trust boundary.

## Related Decisions

- Related to: ADR-008, which defines generated release provenance and compatibility.
- Related to: ADR-009, which defines Make and observable-artifact testing.
- Related to: ADR-016, which defines the committed-digest bashdeps bootstrap and
  dependency-management boundary.
- Supersedes checksum-filename portions of: ADR-017.
