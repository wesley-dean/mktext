# ADR-016: Manage Documentation Dependencies Through bashdeps

Date: 2026-08-18

## Status

Accepted

## Intent and Documentation Posture

This ADR defines how `mktext` acquires and verifies external documentation tooling
while preserving the project's dependency-free consumer build and runtime
boundaries.

## Context

`mktext` has one externally acquired repository artifact: the Bash Doxygen filter
used by `make docs` to preprocess maintained Bash source before Doxygen reads it.
The filter is a development/documentation dependency only.  It is not required to
build `dist/mktext.bash`, test the maintained rendering implementation, or use the
released consumer artifact at runtime.

Before this decision, the Makefile acquired the filter directly from the moving
`main` branch of `wesley-dean/bash-doxygen` and stored it at
`vendor/doxygen-bash.awk`.  ADR-015 established that `vendor/` is generated state
and that the reference site is generated ephemerally, but it still described the
filter as a file downloaded directly by the Makefile.

Related Bash projects now use `bashdeps.bash` to centralize exact external-artifact
acquisition, SHA-256 verification, convergence, and offline verification.  The
released bashdeps contract accepts a committed manifest whose URL and digest
define the approved bytes, stages network candidates before publication, reuses
already-correct destinations, and provides a non-mutating `verify` operation.

There remains one unavoidable bootstrap boundary: bashdeps cannot use itself to
obtain the first trusted copy of `bashdeps.bash`.  Make therefore needs to own one
small, explicit, independently verified bootstrap path.

`mktext` also has a repository-specific constraint that differs from projects such
as `adrctl`: no external artifact is required by `make build`.  Requiring
`make all` to synchronize documentation tooling would add network access and
vendor state to a build path that does not need either.  ADR-009 already defines
`all` as the build-only default and requires it to produce the same consumer
artifact as `build`.

## Decision Drivers

- Centralize ordinary external-artifact acquisition and verification through one
  released dependency tool.
- Pin documentation tooling to immutable upstream content and committed SHA-256
  identity.
- Keep the unavoidable bashdeps bootstrap small, explicit, and independently
  verified.
- Keep `bashdeps.bash` outside the manifest it is required to process.
- Preserve `make build` and `make all` as network-free, dependency-manager-free
  consumer-artifact operations.
- Make documentation dependency acquisition an explicit consequence of
  `make deps` or `make docs`.
- Provide an offline, non-repairing dependency verification target.
- Avoid replacing a usable dependency with unverified bytes.
- Preserve `vendor/` as generated, removable dependency state.
- Keep bashdeps and documentation tooling out of the released mktext runtime.

## Decision

### Bootstrap bashdeps directly from Make

The Makefile SHALL directly own exactly one externally acquired bootstrap
artifact:

```text
vendor/bashdeps.bash
```

The bootstrap artifact SHALL be pinned to a stable released `bashdeps.bash` by:

- exact semantic version;
- immutable release URL; and
- committed expected SHA-256 digest.

The bootstrap artifact SHALL NOT appear in `dependencies.txt` because doing so
would create a circular dependency: bashdeps would be required to materialize the
manifest entry that provides bashdeps itself.

An existing bootstrap file MAY be reused only when its SHA-256 digest matches the
committed expected digest.  A missing or mismatched bootstrap SHALL be repaired by
downloading a candidate to staging, verifying its SHA-256 digest, and publishing
it to `vendor/bashdeps.bash` only after verification succeeds.

A failed network transfer or failed digest verification SHALL NOT replace an
existing file with unverified candidate bytes.

The bootstrap Make logic SHALL remain intentionally narrow.  Ordinary dependency
set policy belongs to bashdeps rather than being duplicated in project-specific
Make recipes.

### Declare ordinary documentation dependencies in dependencies.txt

The committed file:

```text
dependencies.txt
```

SHALL be the source of truth for ordinary externally acquired project artifacts.
For the current repository, that set contains only the Bash Doxygen filter used by
`make docs`.

The manifest SHALL use immutable release/tag URLs and committed SHA-256 digests.
Moving `main` or `master` URLs SHALL NOT be used when an immutable release or tag
can identify the intended bytes.

Dependency identity SHALL be established by the committed digest.  Filename,
version-shaped path components, timestamps, HTTP metadata, or an existing cache
entry do not substitute for digest equality.

The manifest is trusted project source and SHALL remain reviewable in ordinary Git
diffs.  bashdeps SHALL treat it as data according to its released parser and
security contract; the repository SHALL NOT source or evaluate it as shell code.

### Define Make target boundaries

`make deps` MAY use the network.  It SHALL:

1. bootstrap or repair the pinned `vendor/bashdeps.bash` when necessary;
2. verify the bootstrap before executing it; and
3. run `vendor/bashdeps.bash sync dependencies.txt` to converge the declared
   documentation dependency state.

`make deps-check` SHALL NOT use the network and SHALL NOT repair dependency state.
It SHALL:

1. require an already-present acceptable bootstrap artifact;
2. verify the bootstrap SHA-256 digest; and
3. run `vendor/bashdeps.bash verify dependencies.txt`.

`make build` SHALL NOT acquire, synchronize, or verify external dependencies.  It
SHALL continue to build `dist/mktext.bash` solely from maintained mktext source and
local build metadata.

`make all` SHALL retain the ADR-009 build-only contract and SHALL remain equivalent
to `make build`.  The generic consumer pattern of `all: deps -> build` is not
appropriate here because mktext's only managed dependency is unrelated to the
consumer build.

`make docs` MAY use the network because documentation generation requires the
manifest-managed Bash Doxygen filter.  It SHALL synchronize dependencies through
`make deps` before invoking Doxygen.

### Preserve generated dependency state

`vendor/` SHALL remain ignored generated state as defined by ADR-015.

The repository's existing `make clean` lifecycle SHALL remove generated
`vendor/` state along with generated distribution and reference-documentation
output.  A new `distclean` target is not required merely to match another
repository when mktext's existing clean contract already owns generated vendor
state.

bashdeps `sync` converges declared destinations to the committed manifest.  Files
outside the manifest are not historical dependency versions and do not become
part of the dependency contract merely because they are present under `vendor/`.

### Keep runtime and release artifacts isolated

Neither `bashdeps.bash`, `dependencies.txt`, `vendor/`, nor the Bash Doxygen filter
SHALL be required by the generated or released `dist/mktext.bash` artifact.

The consumer artifact SHALL preserve the Bash 4.3+ runtime contract and ordinary
runtime behavior defined by the existing mktext ADRs and specification.

The release workflow does not need to prepare documentation dependencies before
building `dist/mktext.bash`, because those dependencies are not build inputs.  If
a future release workflow begins generating documentation as part of release,
that documentation step SHALL use the same `deps`/`deps-check` boundary rather
than reintroducing direct download logic.

### Exercise the boundary in CI

CI SHALL verify the repository-specific dependency contract, including applicable
coverage for:

- a clean `make build` succeeding without creating `vendor/` state;
- `make deps` bootstrapping bashdeps and synchronizing the documentation manifest;
- reuse of already-correct dependency bytes;
- convergence of stale managed dependency bytes to the manifest digest;
- `make deps-check` detecting missing or tampered dependency state without repair;
- failed acquisition or digest verification not publishing unverified bytes;
- `make docs` generating reference output through the synchronized filter;
- `make clean` removing generated dependency state; and
- the literal generated consumer artifact remaining functional with no bashdeps,
  manifest, or vendor tree available at runtime.

## Considered Alternatives

### Continue downloading the Doxygen filter directly from Make

This keeps the repository small but duplicates acquisition and verification policy
that bashdeps exists to centralize.  The previous moving `main` URL also made the
accepted filter bytes change independently of mktext source review.

### Put bashdeps.bash in dependencies.txt

This creates a bootstrap cycle and is therefore invalid as a consumer integration
model.  One explicitly bootstrapped and independently verified bashdeps artifact
is the intentional exception.

### Make all synchronize dependencies before building

This matches projects whose consumer build requires external artifacts.  mktext's
only external artifact is documentation tooling, so doing this would add network
access and vendor mutation to a build path that does not need them and would
conflict with ADR-009's build-only `all` contract.

### Make build depend on deps

This would make documentation tooling a hidden prerequisite of the consumer build.
It would also violate the existing expectation that a clean checkout can build the
mktext distribution artifact without external dependency acquisition.

### Commit vendor dependencies permanently

Committing bashdeps or the Doxygen filter would avoid bootstrap network access but
would reintroduce generated/vendor state into repository history.  ADR-015 already
establishes `vendor/` as removable generated state.

### Dynamically trust an upstream checksum at bootstrap time

Fetching an upstream checksum together with the artifact would move the trust
decision out of the reviewed repository.  The committed digest is the project's
approved byte identity and SHALL not be silently replaced by live upstream data.

## Consequences

The Makefile retains a small amount of bootstrap logic for one trusted released
bashdeps artifact, while ordinary dependency synchronization and verification are
centralized in bashdeps.

Documentation generation becomes reproducible from committed dependency metadata
rather than a moving upstream branch.

A clean consumer build remains as small as before and does not require network
access, bashdeps, or documentation tooling.

Contributors generating documentation may see `vendor/bashdeps.bash` and
`vendor/doxygen-bash.awk` materialized locally.  Both remain ignored generated
state and are removed by `make clean`.

Offline dependency verification is meaningful after `make deps` has prepared the
local dependency state.

## Superseded Decisions

This ADR supersedes only the portions of ADR-015 that describe the Makefile as
directly downloading the Bash Doxygen filter.  ADR-015 remains the historical
record for ephemeral reference documentation and generated `vendor/` state.

ADR-009's build-only definitions of `make build` and `make all` remain in force.

## Open Questions and Follow-Ups

Additional ordinary external build/development artifacts, if introduced later,
should be evaluated for inclusion in `dependencies.txt`.  Their existence SHALL
not be assumed from patterns used by other repositories.

## Related Decisions

- Related to: ADR-002
- Related to: ADR-008
- Related to: ADR-009
- Related to: ADR-010
- Supersedes in part: ADR-015
