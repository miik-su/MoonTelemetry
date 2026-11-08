# Audit remediation: first batch S01–S07

Implemented first, following the latest audit's sequencing:

- Shared `MemoryBudget`: reserve/release/used/available/is_overloaded. Reservation
  failure leaves accounting unchanged. Operations are synchronous on the single
  cooperative event loop; cross-thread use is unsupported.
- `service.memory_budget_bytes` defaults to 1 GiB;
  `request_memory_budget_bytes` to 256 MiB; total configured active connection
  limits must fit `max_total_connections` (default 1024).
- Every active request reserves three max-body buffers against both request
  and shared budgets before reading. This conservative charge includes gzip
  input/output and decoding workspace. Even small requests reserve this worst
  case. Both reservations release on success, error, timeout and cancellation.
- All runtime queues share the global budget; in-flight batches remain charged.
  Atomic ingress fanout rolls back reservations on partial failure. Output
  budget exhaustion follows the existing per-destination overflow policy.
- Processing/pending buffers reserve three queue byte limits per pipeline;
  batch buffers reserve three batch byte limits. Reservations last until runtime
  shutdown. Validation rejects insufficient combined request/workspace budgets.
- Parsing guards: 100,000 records/request, 256 attributes/container, 1,000,000
  fields/request and nesting depth 64. JSON has a pre-parser lexical guard;
  protobuf checks run before the generated decoder allocates records. These
  initial complexity limits are fixed, not user-configurable yet.

These are logical serialized-byte/workspace budgets, **not RSS limits**. Buffer
growth overhead, object headers, allocator behavior, outbound encoding and trusted
plugins can use additional physical memory. Arbitrarily expanding custom plugins
are outside this resource contract. Native RSS collection remains outstanding.

Focused regression evidence: global queue rollback/in-flight release; request
parse-failure release; concurrent request denial; cancellation release; gzip
expansion bound; runtime drain releases reservations; record/attribute guards.
Full test suite and sustained stress tests have not been run.

Later audit batches remain open: protocol numeric/unpacked compatibility,
identifier semantics, endpoint/path validation, exporter retry/connection work,
plugin serialization, redaction/rotation and disclosure/third-party policies.
