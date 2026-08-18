# ADR-017: Publish Development, Stripped, and Minified Artifacts

Date: 2026-08-18

## Status

Accepted

## Intent and Documentation Posture

This ADR defines the generated mktext artifact set, the build-time Bash-Minifier
dependency, checksum publication, and the dependency boundary required to produce
all supported consumer flavors.

## Context

mktext historically generated one consumer artifact, `dist/mktext.bash`, from the
maintained `src/mktext.bash` source.  ADR-008 defined that artifact as a generated,
sourceable and executable copy with build metadata and full-line source comments
removed.  ADR-016 later established that mktext had no external consumer-build
dependency; at that time the only manifest-managed artifact was the Bash Doxygen
filter used by `make docs`.

Consumers now benefit from three deliberately different representations of the
same release:

- a development artifact that retains maintained source comments;
- the established comment-stripped artifact; and
- a compact artifact produced by Bash-Minifier from the stripped artifact.

All three representations are release products.  They must carry the same mktext
version/build identity and preserve the same public behavior.  The minified form
introduces a genuine build dependency, so the earlier dependency-free build
assumption no longer describes current state.

The build also needs independently verifiable byte identity for every published
artifact.  Each Bash artifact therefore has a companion SHA-256 checksum file.

## Decision Drivers

- Preserve a readable generated artifact for debugging and inspection.
- Preserve `mktext.bash` as the established conventional consumer filename.
- Offer a smaller minified form without making minified code the maintained source.
- Apply the same observable behavior contract to every published Bash flavor.
- Keep build dependency acquisition explicit and separate from plain `make build`.
- Pin Bash-Minifier by immutable commit URL and SHA-256 digest through bashdeps.
- Keep the released artifacts independent of bashdeps, Bash-Minifier, and `vendor/`
  at runtime.
- Publish checksums beside every Bash artifact.
- Preserve deterministic metadata and existing SemVer/release ownership.

## Decision

### Publish three Bash flavors

`make build` SHALL produce these executable Bash artifacts:

```text
dist/mktext.dev.bash
dist/mktext.bash
dist/mktext.min.bash
```

`dist/mktext.dev.bash` SHALL contain the generated interpreter directive and build
metadata followed by the complete maintained mktext source, including full-line
comments and Doxygen documentation.  If maintained source gains its own shebang in
the future, the build SHALL avoid duplicating that source shebang beneath the
generated one.

`dist/mktext.bash` SHALL remain the conventional distribution artifact.  It SHALL
contain the same generated metadata and executable implementation while removing
full source comment lines according to the established comment-stripping contract.
Generated artifact-identification comments emitted by Make remain present.

`dist/mktext.min.bash` SHALL be produced by running the pinned Bash-Minifier over
`dist/mktext.bash`.  Minification is therefore downstream of the existing
comment-stripping boundary rather than an alternate transformation of maintained
source.

The maintained file `src/mktext.bash` remains the single human-edited
implementation.  No generated artifact is committed as maintained source.

### Preserve identical public behavior

All three Bash artifacts SHALL be sourceable and directly executable and SHALL
implement the same public mktext behavior, return statuses, rendering semantics,
help output, and embedded version/build metadata.

The supported direct-execution basename contract SHALL include:

```text
mktext
mktext.bash
mktext.dev.bash
mktext.min.bash
```

This deliberately extends ADR-014's explicit executable-ownership list.  Exact
basename matching remains required so embedding mktext into a differently named
outer executable remains inert.

Tests SHALL exercise the complete public behavior suite against all three generated
artifacts.  Minimum-Bash compatibility coverage SHALL also exercise all three
flavors.

### Publish one checksum per artifact

`make build` SHALL also produce:

```text
dist/mktext.dev.bash.256
dist/mktext.bash.256
dist/mktext.min.bash.256
```

Each `.256` file SHALL contain the SHA-256 checksum of its corresponding artifact
in the conventional `sha256sum`/`shasum -a 256` check-file form, naming only the
artifact basename so verification works from within `dist/`.

The build SHALL fail when neither supported SHA-256 command is available.

### Manage Bash-Minifier through bashdeps

Bash-Minifier is an ordinary build/development dependency and SHALL be declared in
`dependencies.txt` with:

- an immutable commit-pinned raw GitHub URL;
- destination `vendor/bash-minifier.bash`; and
- a committed SHA-256 digest identifying the approved bytes.

The declaration SHALL refer to the upstream `Minify.sh` artifact while giving the
local managed copy the repository-conventional `.bash` name.

Make SHALL NOT add project-specific Bash-Minifier download or verification policy.
The existing released `vendor/bashdeps.bash` bootstrap remains the only dependency
Make acquires directly.  `make deps` SHALL synchronize Bash-Minifier together with
other manifest-managed development/documentation dependencies, and
`make deps-check` SHALL verify that prepared state without network repair.

### Redefine build and all boundaries

`make build` SHALL remain network-free and SHALL NOT invoke dependency
synchronization or verification.  It SHALL require an already-prepared
`vendor/bash-minifier.bash` because the minified artifact cannot be produced
without that build input.  When the required dependency is absent or unsafe to
consume, `build` SHALL fail with a clear instruction to run `make deps` or
`make all`.

`make all` SHALL become the fresh-checkout convergence path:

```text
make deps
make build
```

Ordering SHALL remain explicit under parallel Make execution by invoking the build
only after dependency synchronization succeeds.

This supersedes ADR-009 and ADR-016 only where they previously defined `all` as a
build-only alias and `build` as requiring no external artifact.  The important
boundary remains: network access is an explicit consequence of `deps` or `all`,
never of plain `build`.

### Keep documentation and build dependencies distinct by use

The manifest now contains at least two ordinary external artifacts:

- Bash-Minifier, consumed by `make build`;
- the Bash Doxygen filter, consumed by `make docs`.

A single manifest and `deps`/`deps-check` lifecycle manages both because they share
the same trust and convergence requirements.  Their consumers remain distinct:
`build` executes only the minifier, while `docs` executes only the Doxygen filter.

### Preserve runtime isolation

None of the three released Bash artifacts SHALL require bashdeps,
`dependencies.txt`, Bash-Minifier, the Doxygen filter, or `vendor/` at runtime.
Build tooling is consumed only while producing artifacts.

### Update CI and releases

CI SHALL verify at least:

- plain `make build` fails from a clean checkout when Bash-Minifier is absent and
  does not acquire dependency state;
- `make deps` prepares the pinned minifier and documentation filter;
- `make deps-check` verifies prepared dependency state offline;
- `make all` synchronizes dependencies before producing all six artifacts;
- all three Bash artifacts pass syntax, behavior, direct-execution, and minimum
  Bash compatibility checks;
- all three checksum files verify their corresponding artifact;
- the development flavor retains source comments;
- the conventional flavor excludes full-line maintained comments;
- the minified flavor is generated from the stripped flavor and remains functional;
- released artifacts remain functional after `vendor/` and the manifest are
  unavailable.

The semantic-version release workflow SHALL explicitly run dependency
synchronization and offline verification before `make build`.  It SHALL publish all
six generated files in the GitHub Release.

## Considered Alternatives

### Minify maintained source directly

This would make the minified artifact a sibling transformation of maintained
source and could diverge from the exact stripped artifact consumers already use.
Minifying `mktext.bash` establishes an explicit pipeline and makes the relationship
between the three flavors inspectable.

### Keep make build dependency-free and omit the minified artifact when absent

Conditional artifact sets make build output dependent on local state and weaken
release reproducibility.  The build contract is clearer when all six files are
required outputs and missing prepared dependencies fail explicitly.

### Let make build acquire Bash-Minifier automatically

This would hide network and mutation behind an ordinary build invocation.  The
existing `deps` boundary provides an explicit repair/convergence operation and is
retained.

### Commit Bash-Minifier under vendor

Committing generated dependency state would duplicate upstream bytes in repository
history and bypass the manifest/convergence model established by ADR-016.

### Publish only the scripts and omit checksums

Consumers can calculate hashes themselves, but release-provided checksum files make
byte verification convenient and align artifact publication with other repository
patterns.

### Replace mktext.bash with the minified flavor

That would make the least-readable representation the conventional artifact and
change the established consumer file unexpectedly.  The conventional stripped form
remains stable while minification is an explicit opt-in filename.

## Consequences

A fresh checkout that needs release artifacts uses `make all` or runs `make deps`
followed by `make build`.  Plain `make build` is intentionally offline and assumes
prepared dependency state.

Release size and CI duration increase modestly because three behavioral-equivalent
artifacts and three checksums are generated and tested.

Consumers can choose readability, conventional distribution form, or compactness
without changing mktext semantics.

A Bash-Minifier update becomes a reviewed dependency-manifest change with an
immutable upstream commit and new digest rather than an implicit tool update.

## Superseded Decisions

This ADR supersedes the following portions of earlier accepted ADRs while
preserving those records historically:

- ADR-008: one consumer-facing generated artifact and the rejection of a
  general-purpose minifier;
- ADR-009: `make all` as a build-only alias and testing only one generated artifact;
- ADR-014: the exact direct-execution basename list, extended by the two new
  artifact names;
- ADR-016: the assertion that mktext has no external consumer-build dependency and
  that `make all` therefore need not synchronize dependencies.

All unaffected decisions in those ADRs remain in force.

## Related Decisions

- Supersedes in part: ADR-008
- Supersedes in part: ADR-009
- Related to: ADR-010
- Supersedes in part: ADR-014
- Related to: ADR-015
- Supersedes in part: ADR-016