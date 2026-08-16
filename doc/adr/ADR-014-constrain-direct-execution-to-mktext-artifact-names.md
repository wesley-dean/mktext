# ADR-014: Constrain Direct Execution to mktext Artifact Names

Date: 2026-08-15

## Status

Accepted

## Intent and Documentation Posture

This ADR defines when the sourceable-and-executable `mktext` implementation owns
the process entry point.  The goal is to preserve direct informational execution
for the `mktext` product while allowing the same maintained source to be
concatenated safely into a larger generated Bash executable.

This decision refines the direct-execution contract established by ADR-008.  It
does not change the public `mktext` function, context semantics, rendering
behavior, or generated artifact identity.

## Context

`mktext` is distributed as one generated Bash file that can be sourced as a
library or executed directly for context-free informational operations.  The
current source distinguishes those modes with:

```bash
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  ...
fi
```

That condition is sufficient while `mktext.bash` remains a separate file.  When
sourced, `BASH_SOURCE[0]` identifies the library while `$0` identifies the
caller.  When executed directly, both identify the executable.

Concatenated embedding changes that physical relationship.  A consumer such as
`adrctl` may build one executable by concatenating its own source with the normal
`mktext` source.  The former `mktext.bash` lines then reside physically inside
the generated `adrctl` file, so both `BASH_SOURCE[0]` and `$0` identify `adrctl`.
The original guard therefore succeeds and `mktext` consumes `adrctl`'s process
arguments before the owning program reaches its own entry point.

A caller could introduce an embedding-specific build flag or remove the guard
while assembling its executable, but that would make safe composition depend on
rewriting a dependency.  The library already knows its product identity and can
make the ownership decision deterministically from the invocation basename.

Issue #7 established the concrete embedding requirement and approved the
explicit supported-basename model.

## Decision Drivers

- Preserve direct help and version execution for the released `mktext` artifact.
- Allow unmodified `mktext` source to be concatenated into larger Bash programs.
- Keep exactly one process entry-point owner in a generated executable.
- Avoid embedding-specific build flags or source rewriting.
- Avoid substring matching that could produce accidental executable identities.
- Keep the decision deterministic and free of filesystem or external-command
  dependencies.
- Preserve Bash 4.3 compatibility.

## Decision

`mktext` SHALL dispatch process arguments automatically only when both of these
conditions are true:

1. the containing file is being executed directly, as indicated by
   `BASH_SOURCE[0] == $0`; and
2. the invocation basename `${0##*/}` is exactly one of the explicitly supported
   `mktext` executable names.

The supported executable basenames SHALL be:

```text
mktext
mktext.bash
```

The basename comparison SHALL be exact.  Names such as these SHALL NOT acquire
`mktext` process-entry semantics:

```text
mktext-old
foo-mktext-debug
notmktext
adr
adrctl
```

Only `${0##*/}` participates in the product-identity check.  Directory names and
other path components SHALL NOT affect the decision.  For example, executing:

```text
/home/user/src/mktext-testing/adrctl
```

SHALL NOT dispatch `mktext` merely because a directory contains the string
`mktext`.

Invocation through a symbolic link SHALL use the invocation basename visible in
`$0`.  A link named `mktext` intentionally opts into `mktext` direct-execution
semantics.  A link such as `adr` that targets a larger executable containing
embedded `mktext` SHALL leave the embedded library inert at top level.

When the direct-execution conditions are not satisfied, loading the source SHALL
only define its variables and functions.  It SHALL NOT dispatch process
arguments and SHALL NOT terminate the containing process.

When both conditions are satisfied, the existing public `mktext` dispatcher
SHALL receive the process arguments and its returned status SHALL remain the
process exit status, preserving ADR-008 and the existing status contract.

The canonical generated artifact remains:

```text
dist/mktext.bash
```

The extensionless `mktext` basename is also supported so packaging, installation,
or a deliberate symlink may expose the conventional command name without
changing behavior.

## Considered Alternatives

### Keep only the `BASH_SOURCE[0] == $0` guard

This preserves the existing standalone behavior but cannot distinguish a
standalone `mktext` executable from `mktext` code concatenated into another
executable.  It therefore prevents straightforward single-file composition.

### Remove direct execution entirely

Making the artifact source-only would eliminate entry-point collisions, but it
would also remove the accepted help/version discovery surface defined by
ADR-008.  The demonstrated conflict can be solved without giving up that useful
behavior.

### Add an embedding build flag

A consumer could set a variable before the embedded source or patch the guard at
assembly time.  This was rejected because safe composition should not require a
consumer to rewrite or configure library internals merely to keep the dependency
inert.

### Match any basename containing `mktext`

Substring or broad regular-expression matching would preserve direct behavior
for arbitrary renamed copies, but names such as `mktext-old` or
`foo-mktext-debug` could accidentally claim process ownership.  Explicit names
make the public executable identity inspectable and deliberate.

### Resolve the physical file through the filesystem

Following symbolic links or canonicalizing paths could distinguish some physical
layouts, but it would introduce external commands or filesystem semantics into a
decision that can be made from Bash-provided invocation state.  It would also
work against the deliberate use of an extensionless `mktext` symlink.

### Require consumers to embed only the public function body

Extracting selected source fragments would couple consumers to implementation
structure and weaken the one-maintained-source model.  Concatenating the normal
source should remain safe.

## Consequences

The released `dist/mktext.bash` artifact retains direct help and version behavior.
An installed or linked command named `mktext` receives the same behavior.

Arbitrarily renamed standalone copies no longer automatically behave as the
`mktext` command.  This is an intentional restriction of accidental behavior;
the documented product artifact and command identities remain supported.

Consumers may concatenate the unmodified source into generated executables such
as `adrctl` without `mktext` consuming the outer program's arguments or exiting
before the owning entry point runs.

The executable basename becomes part of the public direct-execution contract and
must therefore be covered by observable behavior tests.

No new public function, runtime dependency, build flag, or persistent state is
introduced.

## Open Questions and Follow-Ups

Additional executable basenames may be added later when a concrete packaging or
compatibility requirement demonstrates the need.  Such names should be added
explicitly rather than through broad pattern matching.

## Related Decisions

- Refines: ADR-008
- Related to: ADR-002
- Related to: ADR-003
- Related to: ADR-009
- Related issue: `wesley-dean/mktext#7`
