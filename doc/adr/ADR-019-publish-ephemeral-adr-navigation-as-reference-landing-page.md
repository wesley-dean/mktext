# ADR-019: Publish Ephemeral ADR Navigation as the Reference Landing Page

Date: 2026-09-09

## Status

Accepted

## Intent and Documentation Posture

This decision makes the Architecture Decision Record collection the navigational
landing page for mktext's generated Doxygen reference site while keeping the
assembled landing-page Markdown ephemeral.

The maintained inputs remain ordinary repository documentation.  `adrctl` owns
the mechanically generated linked ADR list, Doxygen owns the rendered reference
site, and neither generated representation becomes a second maintained source of
truth.

This ADR also tightens the documentation dependency boundary established by
ADR-016.  Documentation dependencies continue to be managed through bashdeps, but
`make docs` becomes an offline consumer of already-prepared dependency state rather
than a target that silently performs dependency synchronization.

## Context

ADR-015 established that Doxygen output under `doc/reference/` is generated state
and should be rebuilt for GitHub Pages rather than committed.  ADR-016 later moved
the Bash Doxygen filter into the repository's bashdeps-managed dependency manifest
and defined explicit acquisition and verification behavior.

The current generated reference site is nevertheless source-code-centric.  The
Doxyfile reads `src/mktext.bash` but does not provide a maintained project landing
page or expose the ADR corpus as the site's primary architecture navigation.
Readers arriving at the Pages site therefore receive useful implementation
reference material without an equally useful entry point into the decisions that
constrain that implementation.

A manually maintained ADR table of contents would solve the immediate navigation
problem, but it would create a synchronization obligation each time an ADR is
added, renamed, or retitled.  Committing a generated `doc/adr/README.md` would
replace manual synchronization with a different synchronization obligation: the
repository would need to ensure that the committed derivative always matches the
maintained ADR corpus and framing fragments.

The related Bash projects now use `adrctl generate toc` to derive a linked ADR list
from the actual ADR files.  `adrctl` can combine maintained introductory and
closing prose with that generated list, making it suitable for producing a Doxygen
main page without committing the assembled Markdown.

The repository's current dependency lifecycle creates one additional issue.
ADR-016 explicitly states that `make docs` may use the network and shall invoke
`make deps` before Doxygen.  The project family has since converged on a clearer
boundary: acquisition and repair belong to `make deps`; `make docs` should consume
prepared state and fail clearly when that state is absent.  This keeps target names
honest about side effects and makes local, CI, and Pages documentation generation
reproducible after one explicit preparation step.

## Decision Drivers

- Give the published Doxygen site a useful architecture-oriented landing page.
- Derive ADR navigation from the actual ADR corpus rather than a manually
  synchronized list.
- Keep maintained prose and generated navigation visibly separate.
- Avoid committing generated Markdown solely to support Doxygen or Pages.
- Preserve ADR-015's ephemeral generated-documentation model.
- Preserve ADR-016's bashdeps-managed, digest-verified dependency model.
- Make dependency acquisition and repair explicit through `make deps`.
- Keep `make docs` offline and non-repairing after dependencies are prepared.
- Reuse the repository's existing `dependencies.txt` rather than introducing a
  second dependency-management mechanism.
- Keep `adrctl` outside mktext's runtime and release-artifact dependency surface.
- Preserve atomic publication of the generated Markdown input.
- Keep routine documentation generation free of ADR relationship diagrams.
- Provide a concise current-decision map in addition to the full ADR corpus.

## Decision

### Maintain landing-page framing as source

The repository SHALL maintain these files as human-authored documentation source:

```text
doc/adr/README.intro.md
doc/adr/README.outro.md
```

The introductory fragment SHALL explain the role of the ADR corpus and the
maintained/generated ownership boundary.  The closing fragment MAY point readers
to related maintained project documentation and explain how the generated page is
produced.

Neither fragment SHALL duplicate the complete ADR list manually.

### Generate the ADR landing page ephemerally

The complete Doxygen landing-page Markdown SHALL be generated at:

```text
doc/adr/README.md
```

That file SHALL be ignored by Git and SHALL NOT be committed as maintained source.
It is a build input derived from maintained ADRs and framing fragments.

Generation SHALL use the released, pinned `adrctl` artifact and its `generate toc`
command.  The generated report SHALL contain:

1. the heading emitted by `adrctl`;
2. the maintained introductory fragment;
3. the linked ADR list derived from the current ADR corpus; and
4. the maintained closing fragment.

The routine documentation path SHALL NOT generate or compose an ADR relationship
graph.  `adrctl generate graph` remains an explicit capability of adrctl itself;
this decision does not remove, alter, or invoke that capability.

### Generate the landing page atomically

The Makefile SHALL provide an `adr-index` target.

`adr-index` SHALL require an already-prepared executable `vendor/adrctl.bash` and
SHALL fail with actionable guidance when that dependency is missing or unsafe to
execute.  It SHALL NOT invoke `make deps`, `bashdeps sync`, or another acquisition
path.

The target SHALL write `adrctl` output to a temporary candidate adjacent to the
final `doc/adr/README.md` path and move the candidate into place only after
successful generation.  A failed generation SHALL NOT replace a previously valid
landing page with partial output.

### Manage adrctl through the existing dependency manifest

The released `adrctl` executable SHALL be declared in the existing
`dependencies.txt` manifest alongside the repository's other build/development
artifacts.

The selected artifact SHALL be pinned by immutable release URL and committed
SHA-256 digest through bashdeps.  `vendor/adrctl.bash` SHALL remain ignored,
generated dependency state.

A separate documentation-only manifest SHALL NOT be introduced for this change.
The existing manifest already governs repository build/development dependencies,
while the Make targets that consume those dependencies preserve distinct
responsibilities.

`adrctl` is a documentation-only dependency of mktext.  It SHALL NOT be copied,
sourced, concatenated, or otherwise incorporated into any `dist/mktext*.bash`
artifact, and it SHALL NOT become a runtime dependency of the public mktext API.

### Make documentation generation consume prepared state

`make deps` remains the explicit convergence target and MAY use the network.
It SHALL prepare and verify the manifest-managed Bash-Minifier, Bash Doxygen
filter, and adrctl artifact according to the existing dependency contract.

`make deps-check` SHALL remain offline and non-repairing.

`make docs` SHALL become an offline consumer of prepared dependency state.  It
SHALL NOT depend on `deps` and SHALL NOT synchronize or repair dependencies.
It SHALL require the prepared Bash Doxygen filter and adrctl executable, regenerate
the ADR landing page, and then invoke Doxygen.

A missing required documentation dependency SHALL fail clearly with guidance to
run `make deps` or `make all` as appropriate.  Documentation generation SHALL NOT
turn that failure into implicit network access.

This decision supersedes ADR-016 only where ADR-016 states that `make docs` may use
the network and shall synchronize dependencies before invoking Doxygen.  All other
ADR-016 dependency-management and trust decisions remain in force.

### Use the generated page as Doxygen's main page

The Doxyfile SHALL include the ADR directory as Markdown input and SHALL set:

```text
USE_MDFILE_AS_MAINPAGE = doc/adr/README.md
```

The generated landing page and actual ADR files SHALL be available through the
reference site.  Maintained source fragments such as `README.intro.md` and
`README.outro.md`, plus non-ADR helper material such as the pre-flight checklist,
SHALL be excluded from appearing as independent ADR/reference pages.

The source-code reference generated from `src/mktext.bash` remains part of the
same site and continues to use the pinned Bash Doxygen filter.

### Keep generated documentation removable

`make docs-clean` SHALL remove both:

- `doc/reference/`; and
- the generated `doc/adr/README.md` landing page, including any abandoned adjacent
  temporary candidate.

`make clean` SHALL continue to remove the broader generated project state according
to the existing lifecycle.

### Publish Pages from explicit dependency preparation

The GitHub Pages workflow SHALL explicitly run dependency preparation and
verification before documentation generation:

```text
make deps
make deps-check
make docs
make deps-check
```

The workflow SHALL continue to deploy only the generated `doc/reference/` output
and SHALL NOT commit generated documentation back to the repository.

CI SHALL verify that:

- `make docs` fails rather than acquiring missing adrctl state;
- the real pinned dependency set can be synchronized and verified;
- `make docs` generates `doc/adr/README.md`;
- the generated landing page contains the current ADR;
- the generated landing page is ignored by Git;
- Doxygen produces `doc/reference/index.html`;
- generated reference output is ignored by Git;
- dependency verification still succeeds after documentation generation; and
- tracked repository state remains clean after the documentation build.

### Maintain a concise decision map

The repository SHALL provide:

```text
doc/decisions.md
```

This file SHALL summarize the current architectural decisions and link to the
full ADRs.  It is maintained source, not generated output.  When a summary and an
ADR appear to conflict, the ADR remains authoritative and the inconsistency SHALL
be surfaced rather than resolved silently in favor of the summary.

## Dependency and Trust Review

Adding adrctl expands mktext's documentation trusted computing base and therefore
requires explicit review even though it does not affect consumer runtime.

The selected dependency executes as a subprocess during documentation generation.
It receives repository-controlled ADR Markdown and maintained framing files as
input, emits generated Markdown to standard output, and writes no mktext runtime
state.  The Makefile redirects that output into a same-directory staging file and
publishes it only after successful completion.

The selected release artifact is pinned by immutable release URL and SHA-256
digest through the existing bashdeps boundary.  Digest verification establishes
which bytes execute; it does not prove that those bytes are behaviorally safe.
The dependency executes with the filesystem and process authority of the local or
CI documentation build and can influence the generated reference site.

The dependency does not receive a public mktext context, template stream, runtime
secret, or release-publication credential merely by being added to this path.  It
is not assembled into release artifacts and is absent from normal consumer
runtime.

The residual risk is therefore bounded to the documentation/build environment and
published documentation integrity, subject to the ordinary authority of that
environment.  A compromised adrctl artifact could misrepresent ADR navigation or
act with the documentation process's local authority.  Pinning, digest
verification, explicit preparation, and the absence of runtime inclusion reduce
that surface without claiming to eliminate it.

## Promises

1. The generated reference site has an ADR-oriented landing page derived from the
   current ADR corpus.
2. Maintained landing-page prose remains reviewable source while the mechanically
   assembled `doc/adr/README.md` remains ephemeral.
3. `make docs` does not synchronize or repair repository dependencies.
4. `adrctl` is pinned and digest-verified through the existing bashdeps manifest.
5. The generated Markdown is published atomically after successful TOC generation.
6. Routine documentation generation does not add an ADR relationship graph.
7. mktext runtime behavior and release artifacts remain independent of adrctl and
   other documentation tooling.
8. `doc/decisions.md` provides concise architectural discovery without replacing
   the ADR corpus.

## Non-Promises

1. This decision does not make generated Doxygen output authoritative over
   maintained source, specifications, or ADRs.
2. It does not guarantee that adrctl or Doxygen is free of defects or malicious
   behavior.
3. It does not make `make docs` usable before dependencies have been prepared.
4. It does not make `make docs` install Doxygen or other system packages.
5. It does not publish the generated `doc/adr/README.md` as a standalone release
   artifact.
6. It does not add automatic ADR relationship-diagram generation.
7. It does not change mktext's public API, rendering grammar, runtime dependency
   floor, release artifact set, or checksum policy.

## Adversary and Failure Model

This decision accounts for:

- a missing or tampered adrctl dependency;
- a partial TOC write caused by adrctl or filesystem failure;
- a stale manually maintained ADR list drifting from the actual corpus;
- a committed generated README drifting from its maintained inputs;
- `make docs` unexpectedly acquiring network state;
- a compromised documentation dependency influencing generated content or using
  the authority of the documentation process;
- a future maintainer accidentally presenting framing fragments or helper Markdown
  as independent ADR pages; and
- routine documentation generation silently growing into graph-generation or
  another unrelated publishing responsibility.

The decision does not attempt to sandbox adrctl or Doxygen.  They remain trusted
documentation tooling within the authority of the process that invokes them.

## Operational Constraints

- `doc/adr/README.intro.md` and `doc/adr/README.outro.md` MUST be maintained source.
- `doc/adr/README.md` MUST be generated, ignored, and uncommitted.
- `adr-index` MUST consume prepared `vendor/adrctl.bash` state and MUST NOT acquire
  dependencies.
- ADR landing-page generation MUST publish atomically after successful generation.
- `adrctl` MUST be declared in the existing `dependencies.txt` with immutable
  release identity and committed SHA-256 digest.
- `adrctl` MUST remain outside mktext runtime/release artifacts.
- `make docs` MUST consume prepared dependency state and MUST NOT invoke `deps`.
- `make deps` remains the explicit network-capable convergence path.
- Doxygen MUST use the generated ADR README as its main page.
- Framing fragments and non-ADR helper Markdown MUST NOT appear as independent ADR
  pages in generated reference output.
- Routine docs generation MUST NOT generate or compose an ADR relationship graph.
- `make docs-clean` MUST remove the generated landing page and reference output.
- Pages MUST prepare and verify dependencies explicitly before `make docs`.
- `doc/decisions.md` MUST remain a concise maintained map of current decisions.

## Considered Alternatives

### Commit the generated ADR README

A committed page would make the linked index visible directly in a fresh GitHub
checkout.  It was rejected because it creates a synchronization contract for a
pure derivative and duplicates the same drift problem ADR-015 already avoids for
Doxygen HTML.

### Maintain the ADR list manually

A hand-authored list avoids another executable documentation dependency.  It was
rejected because the repository already has a machine-readable ADR corpus and the
project family has a released tool whose purpose is to derive the navigation from
that corpus.  Manual synchronization adds ongoing review risk for little value.

### Keep make docs responsible for make deps

This preserves the ADR-016 convenience behavior.  It was rejected because a target
named `docs` would continue to hide network acquisition and dependency mutation.
The explicit `deps` boundary is easier to audit, test, and reproduce offline.

### Use a separate documentation dependency manifest

A second manifest could isolate adrctl and the Doxygen filter from Bash-Minifier.
It was rejected because the repository already governs ordinary external
build/development artifacts through one manifest, and the distinct Make consumers
already keep build and documentation execution paths separate.

### Generate a relationship graph with the TOC

A graph could provide another architecture view.  It was rejected from the routine
site-generation path because linked textual navigation solves the discovery need
without adding renderer/version complexity or another generated artifact.  The
explicit adrctl graph command remains available when a maintainer deliberately
wants it.

### Use a hand-written Doxygen main page unrelated to the ADR corpus

This would improve the Pages root without adding adrctl.  It was rejected because
architecture navigation is the useful missing context, and deriving that
navigation from the ADR files avoids a second independently maintained list.

## Consequences

A fresh checkout must run `make deps` or another explicit dependency-preparation
path before `make docs` can succeed.  This is intentional and makes network access
visible.

The repository gains two small maintained framing fragments, one ignored generated
Markdown input, one additional pinned documentation dependency, a concise decision
map, and CI assertions around the new ownership boundary.

The Pages site becomes a more useful entry point for both implementation reference
and architectural context.  Adding or renaming an ADR changes the generated linked
list automatically the next time documentation is built.

The change does not alter mktext's public substitution behavior, generated release
artifacts, Bash 4.3 runtime floor, or runtime dependency surface.

## Superseded Decisions

This ADR supersedes ADR-016 only where ADR-016 states that `make docs` may use the
network and shall synchronize dependencies through `make deps` before invoking
Doxygen.  `make docs` is now offline and consumes already-prepared dependency
state.

ADR-015 remains in force and is refined to include the generated ADR landing-page
Markdown as ephemeral documentation state in addition to `doc/reference/`.

ADR-017 and ADR-018 remain in force without modification.  Their build, release,
and checksum decisions are independent of this documentation change.

## Related Decisions

- ADR-009: Use Make and Test Observable Behavior
- ADR-010: Adopt Documentation-Driven, Test-Second Development
- ADR-011: Documentation-First Source Code Commenting Standard for AI-Assisted Development
- ADR-012: Treat Documentation and Architectural Context as Product Artifacts
- ADR-015: Generate Reference Documentation Ephemerally
- ADR-016: Manage Documentation Dependencies Through bashdeps
- ADR-017: Publish Development, Stripped, and Minified Artifacts
- ADR-018: Standardize SHA-256 Checksum Companion Filenames
