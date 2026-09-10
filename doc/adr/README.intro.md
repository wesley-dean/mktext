Architecture Decision Records preserve the reasoning behind consequential
technical and process decisions in mktext.  They are intentionally more detailed
than an operational summary because context, alternatives, constraints, and
rejected options are part of the architectural record.

The repository uses a layered documentation model.  `README.md` provides public
orientation, `AGENTS.md` provides contributor and automation guidance,
`doc/decisions.md` summarizes current architectural decisions,
`doc/mktext-spec.md` defines the public behavioral contract, ADRs preserve durable
reasoning, and Doxygen comments preserve implementation-local contracts.

When these surfaces disagree, the conflict should be investigated rather than
resolved by silently choosing the shortest or most convenient document.  Accepted
ADRs govern architectural intent, while the behavioral specification governs the
current public mktext contract.

This landing page is generated during documentation builds.  The prose in
`README.intro.md` and `README.outro.md` is maintained source; the linked ADR list
between them is generated from the ADR corpus by the pinned `adrctl` dependency.
The assembled `doc/adr/README.md` is therefore derivative build input and is not
committed.
