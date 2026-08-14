# Bootstrap ADR Port Assessment for mktext

## Purpose

This document assesses the Bootstrap Architecture Decision Record (ADR)
corpus as a source of architectural guidance for `mktext`.

It is a planning artifact, not an ADR.  Its purpose is to answer one question
for every Bootstrap ADR:

> Does this decision belong in `mktext` as-is, with modification, or not at
> all?

The assessment also treats Bootstrap's `AGENTS.md` as an architectural artifact
for review purposes, while preserving its distinct filename and role.

This document deliberately separates source classification from the later task
of deciding the final `mktext` ADR sequence.  A Bootstrap ADR may be relevant
without deserving a one-to-one `mktext` ADR.  Several related Bootstrap ADRs
may be better expressed as one smaller `mktext` decision.

## Classification meanings

### Relevant as-is

The decision is project-agnostic enough that its architectural substance can
be adopted without reinterpretation.  Project-name or example substitutions do
not change this classification.

### Relevant with modification

The architectural principle applies to `mktext`, but Bootstrap-specific
responsibilities, assumptions, terminology, or consequences must be removed or
rewritten.

This classification does not imply one-to-one porting.  The decision may be
merged with another relevant Bootstrap ADR when the resulting `mktext` design
is clearer and smaller.

### Not relevant

The decision depends on Bootstrap responsibilities that `mktext` intentionally
does not have.  Porting it would introduce concepts, interfaces, or complexity
outside `mktext`'s narrow substitution boundary.

## Summary

The Bootstrap corpus contains 50 ADRs: ADR-000 through ADR-050, with no
ADR-032.

The assessment is:

- Relevant as-is: 2
- Relevant with modification: 29
- Not relevant: 19

The numerical result should not be read as a recommendation for 31 inherited
`mktext` ADRs.  The corpus contains deliberate repetition and layered policy
that made sense while Bootstrap evolved.  `mktext` begins with the benefit of
that history and can express the same durable principles with fewer decisions.

## ADR-by-ADR assessment

### ADR-000: Capability Scope, Epistemic Honesty, and Separation of Concerns

Classification: **Relevant as-is**

Disposition: retain the existing repository-template ADR.

Rationale: ADR-000 is explicitly project-agnostic and governs AI-assisted
reasoning, capability honesty, scope control, and evidence-oriented work rather
than Bootstrap behavior.  The existing `mktext` copy is therefore appropriate
as the foundational ADR.

### ADR-001: Use a Single Bash 5+ Script as the Bootstrap Entry Point

Classification: **Relevant with modification**

Disposition: derive the `mktext` Bash/runtime decision from this ADR, but do not
port its entry-point or remote-execution model.

Rationale: `mktext` is intentionally a Bash library, so the language-selection
reasoning remains useful.  The Bootstrap decision assumes Bash 5+, a remotely
executed bootstrap program, environment detection, and package installation.
`mktext` instead targets Bash 4.3+ so that namerefs and associative arrays are
available, and its intended consumption model is a sourceable library artifact.

### ADR-002: Describe Desired State Rather Than Installation Procedures

Classification: **Not relevant**

Disposition: do not port.

Rationale: desired system state is a Bootstrap domain concept.  `mktext` does
have a related boundary -- substitution rather than transformation -- but that
is a distinct `mktext` decision and should not be presented as an adaptation of
workstation desired-state semantics.

### ADR-003: Treat Native Package Managers as the Source of Truth

Classification: **Not relevant**

Disposition: do not port.

Rationale: `mktext` has no package-manager responsibility or equivalent
external authority.  Its deliberate absence of acquisition and transformation
logic should be documented independently.

### ADR-004: Separate the Bootstrap Engine from User Intent

Classification: **Relevant with modification**

Disposition: adapt into the boundary between `mktext` rendering and caller
policy.

Rationale: this is one of the strongest conceptual matches.  Bootstrap keeps
reusable engine behavior separate from user policy.  `mktext` should likewise
remain independent of ADR semantics, slugification, padding, date generation,
environment acquisition, Git state, UUID generation, and other caller policy.
The caller constructs the context; `mktext` performs literal substitution.

### ADR-005: Design the Bootstrap Experience Around Progressive Adoption

Classification: **Not relevant**

Disposition: do not port.

Rationale: progressive adoption addresses a growing provisioning ecosystem with
multiple capability stages.  `mktext` is intentionally a very small library and
should not acquire an adoption ladder or staged feature model.

### ADR-006: Preserve a Stable Bootstrap Interface While Allowing Internal Evolution

Classification: **Relevant with modification**

Disposition: merge its durable principle with the `mktext` stable-public-API
decision derived from ADR-030.

Rationale: `mktext` should expose a small stable contract while retaining
freedom to change parser or helper implementation.  The relevant public surface
is the `mktext` function, its operations, context semantics, rendering grammar,
I/O behavior, diagnostics, and exit statuses rather than Bootstrap's CLI and
manifest workflow.

### ADR-007: Prefer Inspectable and Reviewable Bootstrap Execution

Classification: **Not relevant**

Disposition: do not port as a separate decision.

Rationale: this ADR governs execution of remotely obtained, privileged
Bootstrap code and specifically prefers `vet` over `curl | bash`.  `mktext` is a
sourceable library and has no comparable privileged remote-execution workflow.
The general inspectability principle is captured more appropriately by ADR-027.

### ADR-008: Define a Human-Centered Package Manifest Format

Classification: **Not relevant**

Disposition: do not port.

Rationale: package-manifest structure is Bootstrap-specific.  `mktext` needs a
small human-readable macro grammar, but that is more directly derived from
ADR-018 and from `mktext`'s own rendering requirements.

### ADR-009: Distribute the Bootstrap Engine as a Single Executable Artifact

Classification: **Relevant with modification**

Disposition: adapt to a single sourceable `mktext.bash` release artifact.

Rationale: the consumer-facing simplicity remains valuable.  The artifact is a
library rather than an executable program.  The current `mktext` direction also
differs from Bootstrap because the source file itself may be the release
artifact; a generated concatenated distribution is not presently required.

### ADR-010: Build the Distribution Artifact from Modular Source Files

Classification: **Not relevant**

Disposition: do not port for the initial architecture.

Rationale: this decision solves growth pressure in Bootstrap by separating a
modular source tree from a generated executable.  `mktext` is intentionally
small enough that its source may itself be the released artifact, and the
preferred initial design is literally one public Bash function.  Introducing a
source-to-distribution assembly layer now would add machinery without a
corresponding need.

### ADR-011: Publish Release Artifacts Through GitHub Releases

Classification: **Relevant with modification**

Disposition: adapt for versioned `mktext.bash` publication and pinning by
consumers.

Rationale: the handoff already calls for a stable versioned release artifact and
for downstream consumers to pin a known version.  GitHub Releases cleanly
separates source development from published consumption.

### ADR-012: Use Make as the Local and CI Orchestration Interface

Classification: **Relevant with modification**

Disposition: adapt the Make-based development interface to `mktext`.

Rationale: the same drift problem exists between local development and CI.
`make test`, `make check`, and `make format` are already part of the intended
`mktext` workflow.  Artifact-specific targets should reflect the simpler
library release model rather than Bootstrap's generated `dist/bootstrap.bash`.

### ADR-013: Fail Conservatively and Avoid Surprising System Changes

Classification: **Relevant with modification**

Disposition: combine its fail-conservatively principle with `mktext`'s parsing,
validation, and least-surprise decisions.

Rationale: `mktext` does not mutate the operating system, so the privileged
safety rationale does not carry over.  Conservative handling of invalid API
usage, invalid contexts, invalid keys, and malformed recognized syntax does.
This decision must coexist with the intentional choice to preserve unknown or
unrecognized macro text literally rather than treating all non-matches as
errors.

### ADR-014: Separate Manifest Parsing from Package Installation

Classification: **Not relevant**

Disposition: do not port.

Rationale: there is no installation stage in `mktext`.  Parser/rendering
responsibilities can be documented directly without importing Bootstrap's
parse-before-mutation pipeline.

### ADR-015: Perform a Planning Phase Before Making System Changes

Classification: **Not relevant**

Disposition: do not port.

Rationale: `mktext` performs no system changes and needs no execution plan.
Adding a planning abstraction would be contrary to its small rendering model.

### ADR-016: Provide Dry-Run and Explain Modes for Planned Changes

Classification: **Not relevant**

Disposition: do not port.

Rationale: rendering is already non-mutating and deterministic.  A dry-run mode
would duplicate normal rendering, while an explain mode would expand the public
surface without a demonstrated need.

### ADR-017: Delegate Package Operations to Native Package Managers

Classification: **Not relevant**

Disposition: do not port.

Rationale: package operations have no equivalent within `mktext`.

### ADR-018: Define a Stable Manifest Grammar

Classification: **Relevant with modification**

Disposition: adapt into the stable, intentionally small macro grammar.

Rationale: the architectural concern maps directly even though the language is
different.  `mktext` should define a minimal grammar, reject pressure to become
a template programming language, and specify compatibility for brace syntax,
key names, whitespace normalization, malformed candidates, and future syntax
changes.

### ADR-019: Define Stable Version Constraint Semantics

Classification: **Not relevant**

Disposition: do not port.

Rationale: package version expressions are outside `mktext`'s domain.

### ADR-020: Provide Human-Centered Diagnostics

Classification: **Relevant with modification**

Disposition: adapt to API and rendering diagnostics on standard error.

Rationale: invalid context names, non-associative variables, invalid keys, and
usage errors should identify what failed and what the caller can correct.
Diagnostics should remain separate from rendered standard output.

### ADR-021: Layer the Bootstrap Engine Around Well-Defined Responsibilities

Classification: **Relevant with modification**

Disposition: preserve responsibility boundaries conceptually, but do not port
Bootstrap's six-stage pipeline or require a separate `mktext` ADR if the same
boundaries are clearer inside the API and rendering decisions.

Rationale: context validation, key normalization, macro recognition,
substitution, and output handling should not be conflated.  However, `mktext`
should not acquire architectural layers merely to resemble Bootstrap.  The one
public function and intentionally small implementation remain stronger design
constraints.

### ADR-022: Define a Stable Package Backend Interface

Classification: **Not relevant**

Disposition: do not port.

Rationale: `mktext` has no platform backend or provider abstraction.  Adding one
would conflict directly with the decision to avoid plugins and acquisition
subsystems.

### ADR-023: Prefer Explicit Configuration Over Implicit Discovery

Classification: **Relevant with modification**

Disposition: adapt into the caller-supplied context and no-acquisition boundary.

Rationale: `mktext` should render only from explicit template input and explicit
context values.  It should not inspect the environment, Git repository,
filesystem metadata, current date, random sources, or other ambient state.

### ADR-024: Provide a Stable and Explicit Command-Line Interface

Classification: **Not relevant**

Disposition: do not port as a CLI decision.

Rationale: `mktext` is designed as a library with one public Bash function and
operation verbs, not as a standalone command-line program.  Stability and
explicitness remain relevant but are covered by the public API decisions derived
from ADR-006 and ADR-030.

### ADR-025: Provide Human-Centered Logging with Progressive Levels of Detail

Classification: **Not relevant**

Disposition: do not port.

Rationale: `mktext` should keep standard output reserved for rendered text and
standard error for diagnostics.  A progressive runtime logging subsystem would
expand the library surface and risk interfering with composition in shell
pipelines.

### ADR-026: Define a Stable Exit Code Philosophy

Classification: **Relevant with modification**

Disposition: adapt and resolve the currently open `mktext` exit-status design.

Rationale: the public operations need documented semantics for success,
`exists` false/not-found results, usage errors, invalid contexts, invalid keys,
and rendering failures.  The Bootstrap categories should not be copied
verbatim, but the principle that numeric statuses form a stable machine-facing
contract applies directly.

### ADR-027: Establish Trust Through Inspectability

Classification: **Relevant with modification**

Disposition: adapt around readable source, simple semantics, hostile-input
safety, and traceable releases.

Rationale: `mktext` does not need Bootstrap's privileged-execution trust model,
but its security claims should be easy to inspect.  A small sourceable artifact,
no `eval`, literal values, no recursive interpretation, and transparent release
provenance all support this principle.

### ADR-028: Favor the Principle of Least Surprise

Classification: **Relevant with modification**

Disposition: merge with conservative input handling where that produces a
smaller `mktext` ADR set.

Rationale: predictable handling of unknown macros, whitespace, key
normalization, newlines, standard streams, and literal values is central to a
renderer.  The decision should be expressed in rendering terms rather than
system-change terms.

### ADR-029: Ensure Reproducible and Verifiable Releases

Classification: **Relevant with modification**

Disposition: adapt to the versioned `mktext.bash` release artifact.

Rationale: downstream consumers, including the future ADR tool, should be able
to pin a release to an immutable source revision and verify its provenance.
Because the source file may itself be the release artifact, reproducibility may
be simpler than Bootstrap's generated-artifact model.

### ADR-030: Preserve Stable Public Interfaces

Classification: **Relevant with modification**

Disposition: combine with ADR-006 into a stable `mktext` public API contract.

Rationale: the `mktext` function name, operations, context semantics, macro
grammar, I/O behavior, exit statuses, and documented rendering behavior are
long-lived commitments.  Private helpers and internal parsing technique should
remain free to evolve.

### ADR-031: Adopt Semantic Versioning and Deliberate Compatibility

Classification: **Relevant with modification**

Disposition: adapt to `mktext` releases.

Rationale: consumers are expected to pin versions of a library artifact.
Semantic Versioning gives those consumers a meaningful signal when the public
API or rendering contract changes.

### ADR-032

There is no ADR-032 in the Bootstrap repository.  This is an intentional fact
of the source inventory, not a missing file to reconstruct.

### ADR-033: Prefer Composition Over Special Cases

Classification: **Relevant with modification**

Disposition: adapt to the caller-composition model and resistance to built-in
special cases.

Rationale: padding, slugification, dates, UUIDs, Git values, environment values,
and application-specific behavior should be composed by callers through
context construction rather than added as special renderer features.

### ADR-034: Keep the Core Engine Small

Classification: **Relevant with modification**

Disposition: adapt as a central `mktext` scope decision.

Rationale: this principle is exceptionally aligned with the project's thesis.
`mktext` should perform named literal substitution and almost nothing else.  A
small core protects determinism, security, testability, and resistance to
feature creep.

### ADR-035: Prefer Data Over Code

Classification: **Relevant with modification**

Disposition: adapt into the template/context data model and security boundary.

Rationale: templates and context values are data, not executable Bash.  The
renderer must not source, evaluate, expand, execute, or recursively interpret
them.  This is stronger and more security-specific in `mktext` than the
Bootstrap desired-state rationale.

### ADR-036: Make Architectural Decisions Explicit

Classification: **Relevant with modification**

Disposition: port with `mktext` terminology and references.

Rationale: the planned design process already depends on ADRs preceding
specification, tests, and implementation.  Preserving alternatives and
reasoning is especially useful because many `mktext` decisions deliberately
reject attractive template-language features.

### ADR-037: Establish a Deliberate Deprecation Policy

Classification: **Relevant with modification**

Disposition: adapt for the sourceable library API and rendering grammar.

Rationale: once downstream projects pin and consume `mktext`, public operation
names, macro semantics, and exit statuses should not disappear without a clear
compatibility path.  The policy can remain smaller than Bootstrap's but the
principle applies.

### ADR-038: Introduce Experimental Features Deliberately

Classification: **Not relevant**

Disposition: do not port initially.

Rationale: `mktext`'s design objective is a deliberately constrained stable
library, not an evolving feature laboratory.  Creating an experimental feature
lifecycle now would introduce governance for capabilities the project is
explicitly trying not to accumulate.  A future need can justify a future ADR.

### ADR-039: Test Observable Behavior Rather Than Implementation

Classification: **Relevant with modification**

Disposition: adapt directly to Bats coverage of the public function and
rendering contract.

Rationale: tests should protect context operations, substitution behavior,
literal safety, malformed input behavior, standard-stream contracts, exit
statuses, newline preservation, and streaming behavior without coupling the
suite unnecessarily to private helper names or internal source organization.

### ADR-040: Prefer Deterministic Behavior

Classification: **Relevant with modification**

Disposition: adapt as a central `mktext` decision.

Rationale: determinism is already a foundational project requirement.  Given
the same template, context, and implementation version, output should be
identical.  Ambient state acquisition belongs to the caller.

### ADR-041: Treat Documentation as Part of the Product

Classification: **Relevant with modification**

Disposition: adapt to the library's README, behavioral specification, ADRs,
source comments, examples, and contributor guidance.

Rationale: `mktext` relies on intentionally narrow semantics.  Precise
documentation is necessary to keep "substitution" from gradually being
reinterpreted as a richer template language.

### ADR-042: Minimize the Trusted Computing Base

Classification: **Relevant with modification**

Disposition: adapt to the no-runtime-dependency goal and hostile-template
security model.

Rationale: a small Bash library should not require external rendering engines,
compiled helpers, `envsubst`, plugin loaders, or other runtime machinery without
strong justification.  Fewer dependencies also make the security boundary
easier to audit.

### ADR-043: Favor Stable Concepts Over Clever Implementations

Classification: **Relevant with modification**

Disposition: adapt to the parser and library design.

Rationale: straightforward lexical substitution, a small key grammar, and
explicit context handling are preferable to terse Bash tricks or increasingly
clever template syntax.  The implementation should remain boring enough to
inspect confidently.

### ADR-044: Optimize for the Next Contributor

Classification: **Relevant with modification**

Disposition: adapt with `mktext` terminology.

Rationale: the project is intentionally small enough that future contributors
should be able to recover its complete mental model from the source,
documentation, specification, tests, and ADRs without reconstructing historical
chat context.

### ADR-045: Documentation-First Source Code Commenting Standard for AI-Assisted Development

Classification: **Relevant as-is**

Disposition: port the accepted project-agnostic standard, allowing only example
or project-name substitutions where useful.

Rationale: ADR-045 explicitly states that it is project-agnostic.  Its
Doxygen-compatible shell documentation rules, non-destructive documentation
requirements, ambiguity handling, and emphasis on intent align directly with
the desired `mktext` source-documentation model.

### ADR-046: Adopt Documentation-Driven, Test-Second Development

Classification: **Relevant with modification**

Disposition: adapt to `mktext` and preserve the sequence of documentation,
implementation, immediate test coverage, and validation.

Rationale: the handoff already calls for ADRs, a behavioral specification, Bats
tests, and only then production implementation.  This ADR captures the broader
development discipline behind that sequence.

### ADR-047: Represent Planned Bootstrap Operations as Immutable Action Records

Classification: **Not relevant**

Disposition: do not port.

Rationale: `mktext` has no planner/resolver/executor architecture and no planned
operations.  Introducing Action Records would add an abstraction unrelated to
literal text substitution.

### ADR-048: Execution SHALL Consume Only Resolved Actions

Classification: **Not relevant**

Disposition: do not port.

Rationale: the Resolved Action execution boundary is specific to Bootstrap's
multi-stage package-operation pipeline.

### ADR-049: Preflight All Manifests Before Execution

Classification: **Not relevant**

Disposition: do not port.

Rationale: `mktext` has no multiple-manifest execution model, privileged action
barrier, planner, or resolver.  Its input is a template stream and an explicit
context.

### ADR-050: Bound Package Installation and Report Progress

Classification: **Not relevant**

Disposition: do not port.

Rationale: package timeouts, package-manager interaction, progress output, and
installation recovery are entirely outside the renderer's responsibility.

## AGENTS.md assessment

Classification: **Relevant with modification**

Disposition: port `AGENTS.md` to the repository root after the ADR synthesis is
accepted, preserving its operational role while rewriting project-specific
content for `mktext`.

The following Bootstrap sections are broadly reusable:

- Read the ADRs first
- Clarify before acting
- Scope discipline
- Documentation standards
- Documentation-driven, test-second testing guidance
- Handling ambiguity
- Validation
- Common failure modes
- Optimize for the next contributor

The following content requires `mktext`-specific replacement:

- project overview;
- Bootstrap package-management responsibilities;
- Bash 5+ requirement;
- package-manager technology stack;
- package-manifest and execution-pipeline terminology;
- the final principle's reference to the Bootstrap engine.

The `mktext` version should instead make the following boundaries prominent:

- Bash 4.3+;
- one public function named `mktext`;
- substitution rather than transformation;
- caller-owned acquisition and formatting;
- templates and values are untrusted literal data;
- no `eval`, sourcing, recursive rendering, or shell interpretation;
- deterministic rendering;
- stable standard-input and standard-output behavior;
- exact newline preservation;
- a deliberately small renderer and public API.

## Recommended synthesis instead of one-to-one porting

The 31 relevant Bootstrap ADRs should not become 31 inherited `mktext` ADRs.
A smaller synthesis better matches the project's scope.

The following clusters are natural candidates for consolidation.

### Stable API and compatibility

Combine the reusable parts of ADR-006 and ADR-030, with ADR-031 and ADR-037
remaining closely related versioning and deprecation decisions.

The `mktext` public contract should explicitly include the one-function API,
operation semantics, context model, grammar, standard streams, diagnostics, and
exit status behavior.

### Conservative and unsurprising behavior

Combine the reusable parts of ADR-013 and ADR-028 where practical.  This should
cover invalid API use and parser behavior without turning preserved unknown
macros into errors.

### Small, composable, data-oriented core

Treat ADR-004, ADR-023, ADR-033, ADR-034, and ADR-035 as a coherent family.
Together they support the most important `mktext` boundary:

```text
Acquisition    -> caller
Transformation -> caller
Rendering      -> mktext
```

This family should explicitly reject built-in formatting, slugification,
external-state acquisition, plugins, recursive evaluation, and executable
templates.

### Release and supply-chain discipline

ADR-009, ADR-011, ADR-029, and ADR-031 can be expressed with less machinery than
Bootstrap because `mktext.bash` may be both the maintained source and release
artifact.  The durable requirements are a single consumable artifact, immutable
versioned releases, pinning, traceability, and verification.

### Documentation and development discipline

ADR-036, ADR-039, ADR-041, ADR-043, ADR-044, ADR-045, and ADR-046 form the
engineering-governance foundation.  Some may remain separate because they serve
different purposes, but they should be edited to remove Bootstrap history and
avoid repeating the same maintainability argument unnecessarily.

## Preliminary mktext-only decisions

The Bootstrap corpus cannot supply several decisions because they arise from
`mktext`'s own rendering model.  These should be addressed explicitly during
ADR synthesis.

### Public function and context representation

Decide and document:

- one public function named `mktext`;
- operation dispatch through `set`, `get`, `exists`, `render`, and the final
  decision on `unset`;
- associative arrays as contexts;
- context passage by variable name;
- Bash namerefs;
- validation of context variable names and associative-array type.

### Substitution, literal values, and nonrecursive rendering

Document that:

- `mktext` substitutes names with values;
- it does not transform values;
- inserted context values are literal;
- inserted values are not rescanned for macros;
- template or value content never receives a second shell interpretation.

### Macro grammar and normalization

Finalize and document:

- single-brace syntax;
- whitespace handling inside braces;
- canonical key case;
- legal key grammar;
- treatment of tabs and internal whitespace;
- malformed brace candidates;
- unknown macro preservation.

### Standard streams and exact byte-level text behavior

Document that:

- template input comes from standard input;
- rendered output goes to standard output;
- diagnostics go to standard error;
- input newline termination is preserved exactly;
- rendering does not append an unconditional newline.

### Streaming boundary

Finalize and document:

- line-at-a-time streaming as the initial production model;
- whether macros are forbidden from spanning lines;
- behavior for very long lines;
- the relationship between streaming and bounded resource use.

### Error and status semantics

Finalize the numeric exit-status contract for:

- success;
- `exists` false/not-found;
- usage error;
- invalid context;
- invalid key;
- rendering failure.

## Recommended next step

The next step should be review of this assessment, followed by a synthesis pass
that proposes the actual `mktext` ADR titles, boundaries, lineage, and numbering.

Only after that synthesis is accepted should the project draft the ported and
`mktext`-specific ADR bodies and update `AGENTS.md`.
