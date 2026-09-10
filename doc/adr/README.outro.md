## Reading the Decisions

`doc/decisions.md` provides a concise current map when a reader needs orientation
before opening the full records.  The ADRs remain authoritative for the reasoning,
tradeoffs, supersession history, and operational constraints behind each decision.

mktext's public runtime behavior is specified separately in `doc/mktext-spec.md`.
Generated reference documentation remains derivative of maintained source,
specifications, and ADRs; it does not supersede them.

## Generation

The linked list above is generated with the pinned `adrctl` release during
`make adr-index` and `make docs`.  Routine documentation generation intentionally
produces textual navigation only; it does not generate an ADR relationship graph.
