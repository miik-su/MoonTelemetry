# Operations and delivery semantics

## Shared resource budget (audit remediation)

Runtime queues now share `service.memory_budget_bytes` (default 1 GiB).
Requests additionally share `request_memory_budget_bytes` (default 256 MiB).
Processing/batch workspaces reserve capacity until shutdown; configured active
receiver connection limits must total no more than `max_total_connections`
(default 1024). Requests reserve three maximum-body buffers before allocation,
including gzip workspace, and return 503 when either budget is exhausted.
See [SECURITY_REMEDIATION.md](SECURITY_REMEDIATION.md) for exact accounting,
fixed complexity guards, tests and outstanding audit tasks. These additions
supersede the earlier per-queue-only budget description below.

Start with `examples/collector.json`. All addresses default to loopback; the
collector does not supply an authentication layer. HTTP headers and body reads
share a per-connection timeout; each connection serves one request and closes.
The configured connection limit also bounds concurrent body/decompression work.

Each pipeline owns an input queue and one queue per exporter attachment. Input
admission across matching pipelines is atomic: any full input rejects the
request with 503. One worker per destination prevents retries from blocking
other destinations. When an output queue is full, that destination's copy is
dropped and `overflowDropped` increases. Healthy destinations continue.

`GET /health` includes queue accepted/delivered/dropped counts, overflow drops,
retained bytes, processor filtering and shutdown losses. Input delivered means
processing completed, not remote durability. Exporter delivered means the target
accepted the response (or a local append completed), not durable downstream
storage. A file is opened, appended and closed per batch; it is not fsynced.

Queue byte limits include in-flight retrying batches. Batch limits cap retained
serialized payloads; one request can exceed the record threshold but cannot
exceed the byte budget. Transformations and decoded object overhead consume
additional memory. These are finite serialized-data budgets, not a process RSS
ceiling. Account for input/output queues, pending batches, transformations and
max_connections * max_body_bytes when sizing the process.

Shutdown cancels listeners/workers, resumes retained queues, flushes batches and
drains within shutdown_timeout_ms. On expiry outstanding data is counted as
dropped. Custom exporter close calls have an additional bounded close window.
The process can lose memory queues on crashes and can duplicate delivery after
timeouts or interruption. There is no exactly-once or durable at-least-once
guarantee. Native timed shutdown is tested; platform console signal behavior
should be verified on the deployment host.

OTLP retries 429/502/503/504 and transport errors using capped exponential delay
and bounded attempts. Other HTTP errors and successful partial responses are
not retried. Retry-After headers and random jitter are not implemented yet.

Factories in core/component register custom Processor and Exporter types.
Pass the factories to config.parse, then construct service.Runtime. Factories
must validate without performing I/O. Processors return independently owned
envelopes and must keep mutable state safe when reused across pipelines.
Exporters return rejected counts and close resources in close. See the runnable
registration example in tests/integration/plugin_test.mbt.
