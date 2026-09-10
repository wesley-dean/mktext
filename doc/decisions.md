# Architectural Decisions

This document is a concise map of mktext's Architecture Decision Records.  It is
a discovery aid rather than a substitute for the ADR corpus.  When a summary and
a governing ADR appear to conflict, read the ADR and surface the inconsistency
rather than silently choosing the shorter wording.

The public runtime contract is defined separately in `doc/mktext-spec.md`.

## Accepted Decisions

### ADR-000: Capability Scope, Epistemic Honesty, and Separation of Concerns

Accuracy, explicit capability limits, evidence-oriented reasoning, separation of
concerns, and resistance to performative agreement are foundational project
constraints.  Assistance must not claim capabilities it does not have or invent
certainty where evidence is insufficient.  These principles govern project work
independently of mktext's specific runtime behavior.

See [ADR-000](adr/ADR-000-capability-scope-and-epistemic-honesty.md).

### ADR-001: Define mktext Scope and the Caller Boundary

mktext performs named literal text substitution while callers own value
acquisition and transformation.  Date generation, Git/environment inspection,
slugification, case conversion, expressions, conditionals, includes, plugins, and
similar policy remain outside the core.  Crossing that rendering boundary requires
deliberate architectural justification.

See [ADR-001](adr/ADR-001-define-mktext-scope-and-caller-boundary.md).

### ADR-002: Require Bash 4.3+ and Minimize Runtime Dependencies

mktext requires Bash 4.3 or newer so it can use associative arrays and namerefs
without raising the compatibility floor further than needed.  Ordinary runtime
operations use Bash language features and builtins rather than external commands.
Bash cannot faithfully represent NUL bytes, so mktext is a text library rather
than a binary-safe rewriting tool.

See [ADR-002](adr/ADR-002-require-bash-4-3-and-minimize-runtime-dependencies.md).

### ADR-003: Expose One Stable Function and Associative-Array Contexts

The public Bash namespace exposes one `mktext` function that dispatches context,
rendering, help, and version operations.  Callers own named associative-array
contexts, while the `__mktext_` namespace is reserved for private library state.
Readonly contexts are valid for read operations and rendering but are rejected
before mutation.

See [ADR-003](adr/ADR-003-expose-one-stable-function-and-associative-array-contexts.md).

### ADR-004: Define Key and Macro Grammar

Public keys use the ASCII grammar `[A-Za-z][A-Za-z0-9_-]*` and are normalized to
uppercase for ordinary context operations and delimited macro lookup.  Default
macros permit optional spaces or horizontal tabs inside `{` and `}` while keeping
hyphens and underscores distinct.  Text outside the recognized grammar remains
literal rather than becoming an implicit expression language.

See [ADR-004](adr/ADR-004-define-key-and-macro-grammar.md).

### ADR-005: Render Lexically, Literally, and Non-Recursively

Templates and context values are data and must never be evaluated, sourced,
executed, or shell-expanded by mktext.  Rendering performs one lexical
substitution pass, inserts stored values literally, and does not rescan inserted
text.  Unknown recognized macros and malformed or unrelated brace syntax are
preserved rather than deleted or treated as execution instructions.

See [ADR-005](adr/ADR-005-render-lexically-literally-and-non-recursively.md).

### ADR-006: Stream STDIN to STDOUT and Preserve Line Termination

`mktext render` behaves as a Unix-style filter that reads standard input and writes
standard output.  Rendering processes one physical line at a time, preserves
whether the input ended with a newline, and does not permit macros to span input
newlines.  The public API deliberately leaves filename handling to normal shell
redirection and composition.

See [ADR-006](adr/ADR-006-stream-stdin-to-stdout-and-preserve-line-termination.md).

### ADR-007: Define Diagnostics and Return-Status Semantics

Diagnostics use standard error while rendered data, values, help, and version
information use standard output.  The public status model distinguishes success,
absent keys, invalid usage, invalid context/key state, and distinguishable
recoverable data-transfer failures without calling `exit` from ordinary sourced
library paths.  Signal-derived failures and Bash input ambiguities remain bounded
by the shell behavior the library can actually observe.

See [ADR-007](adr/ADR-007-define-diagnostics-and-return-status-semantics.md).

### ADR-008: Release One Versioned Sourceable Artifact

ADR-008 established the generated consumer boundary, build metadata, direct
execution behavior, and semantic-version compatibility model while retaining one
maintained implementation under `src/`.  It originally described one generated
`dist/mktext.bash` artifact and a narrow comment-stripping build transform.
ADR-017 later supersedes the one-artifact portions while preserving the underlying
generated-artifact, provenance, and compatibility principles.

See [ADR-008](adr/ADR-008-release-one-versioned-sourceable-artifact.md).

### ADR-009: Use Make and Test Observable Behavior

GNU Make is the canonical development and CI orchestration surface, and Bats tests
public observable behavior rather than incidental private helper structure.
Maintained source and generated consumer artifacts are separate validation
surfaces, with explicit static analysis, formatting, compatibility, and behavior
targets.  ADR-017 later expands the artifact matrix and changes the `all`/build
dependency relationship without replacing the broader Make and testing model.

See [ADR-009](adr/ADR-009-use-make-and-test-observable-behavior.md).

### ADR-010: Adopt Documentation-Driven, Test-Second Development

Human-readable intent should normally be established before implementation and
automated regression evidence.  Behavioral changes are incomplete when the
relevant documentation or tests are missing, while exploratory ordering remains
permitted when needed to clarify feasibility.  Tests provide executable evidence
for documented contracts rather than becoming an undocumented substitute for
architecture.

See [ADR-010](adr/ADR-010-adopt-documentation-driven-test-second-development.md).

### ADR-011: Documentation-First Source Code Commenting Standard

Maintained source uses a deliberately verbose, Doxygen-compatible documentation
style aimed at preserving comprehension, intent, assumptions, failure behavior,
and safety constraints under maintenance pressure.  AI-assisted documentation
work must preserve executable behavior when the requested change is comment-only
and must expose ambiguity instead of inventing rationale.  Documentation is
therefore part of the system's maintainability and incident-prevention surface.

See [ADR-011](adr/ADR-011-documentation-first-source-code-commenting-standard.md).

### ADR-012: Treat Documentation and Architectural Context as Product Artifacts

README, AGENTS, ADRs, the behavioral specification, and source comments have
distinct maintained roles and together form part of mktext's product surface.
Accepted ADRs should remain historical records and be refined or superseded by
later decisions rather than silently rewritten.  Public behavior changes should
keep the relevant maintained documentation and specification synchronized.

See [ADR-012](adr/ADR-012-treat-documentation-and-architectural-context-as-product-artifacts.md).

### ADR-013: Configure Render Delimiters Per Invocation

`mktext render` supports caller-selected literal start and end delimiters while
retaining `{` and `}` as defaults.  Empty start and end delimiters together select
complete-token, case-sensitive bare-key rendering so legacy templates can be
supported without substring replacement.  Delimiter configuration belongs to one
render invocation and does not become hidden context state or executable syntax.

See [ADR-013](adr/ADR-013-configure-render-delimiters-per-invocation.md).

### ADR-014: Constrain Direct Execution to mktext Artifact Names

Automatic process dispatch occurs only when the containing file is executed
directly and its invocation basename is an explicitly supported mktext artifact
name.  This prevents mktext source embedded inside another executable from
accidentally claiming that program's entry point.  ADR-017 extends the supported
artifact-name set for the additional generated flavors while preserving the exact
basename ownership rule.

See [ADR-014](adr/ADR-014-constrain-direct-execution-to-mktext-artifact-names.md).

### ADR-015: Generate Reference Documentation Ephemerally

Doxygen output under `doc/reference/` and downloaded/vendor documentation tooling
are generated state rather than maintained source.  GitHub Pages rebuilds the
reference site from maintained inputs and publishes the generated output without
committing it back to the repository.  ADR-019 refines this model by treating the
assembled ADR landing-page Markdown as ephemeral generated input as well.

See [ADR-015](adr/ADR-015-generate-reference-documentation-ephemerally.md).

### ADR-016: Manage Documentation Dependencies Through bashdeps

The repository bootstraps exactly one pinned bashdeps executable directly and uses
it to synchronize ordinary external artifacts declared in `dependencies.txt`.
Committed SHA-256 digests authorize dependency bytes, while `deps-check` verifies
prepared state without network repair.  ADR-019 supersedes only ADR-016's earlier
rule that `make docs` itself performs dependency synchronization; documentation
now consumes prepared state offline.

See [ADR-016](adr/ADR-016-manage-documentation-dependencies-through-bashdeps.md).

### ADR-017: Publish Development, Stripped, and Minified Artifacts

The build publishes development, conventional comment-stripped, and minified Bash
artifacts that share one public behavior and build identity, with Bash-Minifier as
a pinned build dependency.  Plain `make build` remains network-free and requires
prepared minifier state, while `make all` explicitly runs dependency convergence
before building.  Runtime consumers remain independent of bashdeps, the manifest,
Bash-Minifier, documentation tooling, and `vendor/`.

See [ADR-017](adr/ADR-017-publish-development-stripped-and-minified-artifacts.md).

### ADR-018: Standardize SHA-256 Checksum Companion Filenames

Current builds and releases publish one `.sha256` companion for each generated
Bash artifact and do not emit duplicate `.256` files.  Historical `.256` release
assets remain valid, with fallback permitted only after confirmed absence of the
preferred `.sha256` sidecar.  Published checksum sidecars do not replace committed
SHA-256 digests as the authority for repository dependency acceptance.

See [ADR-018](adr/ADR-018-standardize-sha256-checksum-companion-filenames.md).

### ADR-019: Publish Ephemeral ADR Navigation as the Reference Landing Page

The Doxygen site uses an ignored `doc/adr/README.md` assembled from maintained
intro/outro fragments and an adrctl-generated linked ADR list.  `adrctl` is pinned
through the existing bashdeps manifest and remains a documentation-only dependency;
`make docs` consumes prepared documentation state offline and no longer invokes
`make deps`.  The decision also establishes this file as the Doxygen main page,
keeps routine documentation graph-free, and adds this maintained decision map for
architectural discovery.

See [ADR-019](adr/ADR-019-publish-ephemeral-adr-navigation-as-reference-landing-page.md).
