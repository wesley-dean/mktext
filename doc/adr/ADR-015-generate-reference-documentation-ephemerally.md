# ADR-015: Generate Reference Documentation Ephemerally

Date: 2026-08-17

## Status

Accepted

## Intent and Documentation Posture

This ADR defines the lifecycle of generated Doxygen reference documentation and
the downloaded Doxygen Bash filter used to produce it.

## Context

`mktext` keeps its durable documentation close to the maintained source.  The
Bash implementation carries Doxygen-compatible comments, the behavioral contract
lives in `doc/mktext-spec.md`, and architectural decisions live in `doc/adr/`.
Doxygen turns those maintained inputs into a browsable HTML site under
`doc/reference/`.

The generated HTML, JavaScript, CSS, indexes, and navigation files are derived
artifacts.  Tracking them in Git duplicates information already present in the
maintained source, makes ordinary Doxygen version changes produce large review
diffs, and exposes generated third-party support assets to repository scanners
that are intended to assess maintained project content.

The Pages deployment workflow already has enough information to reproduce the
site from a clean checkout: it can install Doxygen, run `make docs`, upload the
resulting `doc/reference/` directory, and deploy that artifact directly to GitHub
Pages.  The workflow uses read-only repository contents permission, so publishing
documentation does not require writing generated files back to the repository.

The Doxygen Bash filter under `vendor/` has the same lifecycle.  It is downloaded
by the Makefile when needed and is an input cache for documentation generation,
not maintained project source.

## Decision Drivers

- Keep maintained source, specifications, and ADRs as the documentation sources
  of truth.
- Avoid review noise from generated HTML, JavaScript, CSS, and indexes.
- Avoid scanning generated Doxygen support assets as maintained project code.
- Keep documentation generation reproducible through `make docs`.
- Keep GitHub Pages deployment independent of committed generated files.
- Keep downloaded documentation tooling out of version control.
- Preserve a visible repository-homepage signal for documentation deployment
  health.

## Decision

Generated Doxygen reference documentation SHALL be written to:

```text
doc/reference/
```

The entire `doc/reference/` directory SHALL be treated as generated output.  It
SHALL NOT be committed to the repository and SHALL be ignored by Git.

The downloaded Doxygen Bash filter and any other files materialized under:

```text
vendor/
```

SHALL likewise be treated as generated/downloaded build inputs.  The `vendor/`
directory SHALL NOT be committed to the repository and SHALL be ignored by Git.

`make docs` SHALL remain the canonical local and automation interface for
building the browsable reference site.  Documentation generation SHALL start
from a clean `doc/reference/` directory and recreate that directory before
running Doxygen.  No tracked sentinel file is required inside the generated
output directory.

`make clean` SHALL remove generated reference documentation and downloaded
vendor content through the existing Make lifecycle.

The GitHub Pages workflow SHALL generate documentation from maintained source in
its disposable runner workspace and upload `doc/reference/` directly as the
Pages artifact.  It SHALL NOT stage, commit, push, or otherwise write generated
reference documentation back to the repository.  Its repository contents
permission SHALL remain read-only.

The Pages workflow SHALL run automatically for pushes to `main`.  Manual
deployment SHALL remain constrained to the `main` ref so a feature branch cannot
replace the published documentation site through workflow dispatch.

The repository README SHALL expose the Pages workflow status with a
`Documentation` badge that links to `.github/workflows/static.yml`, matching the
status-badge convention used by related Bash projects.

The durable documentation inputs remain:

- Doxygen-compatible comments in maintained source;
- `Doxyfile`;
- `doc/mktext-spec.md`;
- ADRs under `doc/adr/`;
- contributor and user documentation such as `README.md` and `AGENTS.md`.

Generated reference output is a publication artifact derived from those inputs;
it is not an additional documentation source of truth.

## Considered Alternatives

### Continue committing `doc/reference/`

This makes the rendered site browsable directly in the repository and preserves
an exact generated snapshot for every commit.  It also duplicates derived
content, creates large review diffs, couples commits to local Doxygen versions,
and causes generated support assets to enter scanning and maintenance workflows.
The Pages workflow can reproduce the site without those costs.

### Have GitHub Actions regenerate and commit documentation

A bot commit could keep generated files synchronized automatically.  That would
still preserve all of the repository churn of tracked generated output and would
introduce automated commits that bypass the normal human-authored change set.
Publishing directly from the runner is a cleaner boundary.

### Publish from a dedicated generated branch

A dedicated Pages or documentation branch would keep generated files away from
`main`, but it would add another long-lived branch and synchronization lifecycle.
GitHub Pages artifact deployment already provides the required publication
boundary without a generated branch.

### Publish only an Actions artifact

An ordinary workflow artifact would avoid committing generated files, but it
would not provide the browsable GitHub Pages site that the project already uses.
Direct Pages artifact deployment preserves that user-facing documentation.

## Consequences

Repository diffs become smaller and focus on maintained documentation inputs
rather than Doxygen output.

Running `make docs` locally creates ignored files under `doc/reference/` and may
materialize the ignored `vendor/` directory.  Contributors can inspect the
rendered site locally without creating Git changes.

The published documentation site is rebuilt from the exact source revision that
reaches `main`, so a successful Pages workflow becomes the observable signal that
the generated reference was produced and deployed successfully.

A failure to generate documentation is surfaced by the Pages workflow and its
README badge rather than by a committed generated-file diff.

Removing tracked generated output also means historical repository commits remain
the place to inspect older generated snapshots that were previously committed;
new commits intentionally stop carrying those snapshots.

## Open Questions and Follow-Ups

The Doxygen Bash filter URL currently follows its upstream `main` branch.  Pinning
that documentation-generation dependency to an immutable revision may be
considered separately if stronger reproducibility is required.

## Related Decisions

- Related to: ADR-009
- Related to: ADR-011
- Related to: ADR-012
- Related to: ADR-014
