# Changelog

## 0.1.2 — 2026-11-14

- Grow request-body/decompression reservations incrementally; release them on
  errors and cancellation. Bound total export time including lock wait/backoff.
- Separate liveness/readiness, add opt-in overload rejection and a strict privacy
  example; document volatile admission and structural metric-validation limits.
- Fix metric nested protobuf lengths for signed zigzag fields. Accept quoted
  finite doubles while rejecting overflow, preserving explicit nonfinite values.
- Expand Go Collector fixture roundtrips to five metric branches and complex
  logs/traces, with 14 differential boundary cases and checksum-pinned helpers.
- Add CLI/receiver key CI checks, compiler-counter mutation feedback, committed
  corpus replay, dependency-manifest policy/provenance and Linux lifecycle faults.
- Publish dated synthetic raw results and generated delivery-loss charts.
  Correct the benchmark's async sample-ID race; preserve older affected evidence
  and its transport errors without treating its latency as qualified.
- Document ecosystem differentiation and architecture-reference licensing;
  add distribution guidance and a runnable protocol-library example.

## 0.1.1 — 2026-11-08

- Shared request/queue/workspace budgets, configurable parsing limits and RSS observation.
- Exact 64-bit numeric JSON input, future enums, packed/unpacked interoperability,
  semantic IDs, duplicate-key rejection and strict successful-response validation.
- Persistent serialized HTTP destinations, Retry-After seconds/HTTP dates, jitter,
  configurable response limits and per-plugin close deadlines.
- Endpoint/listener/file collision validation, bounded JSONL rotation, authenticated
  ingress/health, source allowlists, slow-body protection and nested redaction.
- Combined file-retention budgets, Windows path-alias guards, oversized archive
  preflight and component-specific failure accounting without exception payloads.
- Component catalog/version generation, upstream descriptor consistency checks,
  deterministic malformed-input regression tests and a Collector-level benchmark.
- Startup-failure plugin cleanup, strict generated-interface/format checks on a
  fixed toolchain, successful Windows/Linux key CI, lossless real Go Collector
  roundtrip and a ten-minute HTTP run with no loss of accepted records.

This is a pre-production release. It does not add gRPC, durable queues or
exactly-once delivery. See COMPATIBILITY.md for explicit support boundaries.

## 0.1.0

Initial native Collector implementation with three signals, processors,
independent exporter queues, JSON configuration, CLI and SDK examples.
