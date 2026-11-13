# Operations and delivery semantics

## Admission and memory

Start with examples/collector.json. Listener defaults are loopback, 32 MiB
maximum body, 32 connections, 3 s header deadline, 3 s body-idle deadline,
1 s processing deadline and 10 s total request deadline. Connections can serve
multiple requests; idle headers eventually release connection permits.
Synchronous parsing cannot be preempted mid-operation: complexity checks bound
its work, and elapsed processing time is checked afterwards.

service.memory_budget_bytes defaults to 1 GiB and request_memory_budget_bytes
to 256 MiB. Reads grow reservations in chunks of at most 8 KiB, charging three
logical buffer bytes per prospective byte before each read. Gzip expansion has
its own growing reservation, and parsing reserves another three decoded-body
bytes per byte before decoding. Both budgets must accept every increase atomically.
The final one-byte body-limit probe is charged too. A small request no longer
reserves three maximum-body buffers. Reservations release
on success, failure, timeout and cancellation. max_total_connections defaults
to 1024 and bounds configured listeners' combined connection limits.

Each pipeline reserves three queue-byte limits for processing workspace;
batching reserves three batch-byte limits. These reservations last until runtime
shutdown. Validation requires workspace plus request budget to fit the global
budget. Queues additionally charge retained serialized batches, including those
in flight. Outbound encoding/response work reserves against the same budget.

These are conservative logical byte/workspace budgets, not a hard RSS ceiling.
Decoded object overhead, allocation behavior and trusted plugins can consume
additional memory. /health reports RSS independently where supported. Apply
deployment-level memory/CPU limits and observe actual usage.
payload_size_guard.max_bytes bounds a payload's serialized size; memory_limiter
remains a compatibility alias for that processor.

The limits section can lower max_records_per_request (100,000),
max_attributes_per_record (256, applied to attribute containers),
max_total_fields_per_request (1,000,000), and max_nesting_depth (64).
These defaults are also the maximum permitted settings.

## Network and health access

Non-loopback listeners require auth_token, unless an administrator explicitly
sets allow_remote_without_auth: true. Send Authorization: Bearer <token>.
allowed_ips restricts literal socket peer addresses; forwarded headers do not
override the peer. Use an entire environment reference such as
`${env:OTLP_TOKEN}` for a secret configuration value. The receiver serves plain
HTTP; remote deployments need trusted TLS termination.

Health defaults to enabled on loopback and disabled remotely. Explicit remote
health_enabled requires a separate health_token. Status includes lifecycle,
logical budgets, RSS, receiver requests/rejections/timeouts, pipeline filtering,
processor failures, queue overflow/shutdown losses and per-destination export
counts, retry attempts and safe error categories. It excludes request bodies
and credentials. Counters reset on restart.

`/health/live` reports HTTP 200 while the listener can answer. `/health/ready`
returns 200 only for lifecycle status ready, otherwise 503. It does not promise
capacity for every signal or destination. Both use the same health enablement,
source restrictions and token policy. `/health` retains the legacy HTTP 200
snapshot behavior; load balancers should use `/health/ready`.
Health probes share the receiver listener and connection permits with telemetry.
Reserve connection headroom for probes; a fully occupied persistent-connection
limit may prevent a new probe from reaching the handler.

## Queues and delivery

Each pipeline owns an input queue and one queue per exporter attachment.
Defaults are 64 batches / 32 MiB per queue. Matching-pipeline input admission is
atomic: any full input rejects the request with 503. A full output queue drops
that destination's copy and increments overflowDropped; healthy outputs continue.
Distinct destinations run independently. A shared destination serializes all
sends, including custom exporters, and reuses HTTP connections.

`service.delivery_policy` defaults to `best_effort`. `reject_on_overload` also
rejects admission with 503 when an attached output is already full or draining.
This is early load shedding, not reserved output capacity: concurrent admission,
processor expansion, later failures and crashes can still lose accepted copies.
Neither mode is durable or guarantees all destinations receive an HTTP-200 input.
Durable queues and durable at-least-once delivery remain unsupported.

Input delivered means processing completed. Output delivered means a target
accepted the response or a local append completed. Neither proves durable
storage. Successful partial OTLP responses count rejected records without retry.
Retryable HTTP codes are 429/502/503/504; transport failures also retry within
the configured attempt count. retries: 0 disables retries. Exponential backoff
includes random jitter and respects capped Retry-After seconds/HTTP dates.

OTLP `attempt_timeout_ms` defaults to 10,000 ms. `timeout_ms` is a compatibility
alias; specifying both is rejected. `total_timeout_ms` defaults to 30,000 ms and
covers mutex waiting, requests and retry sleeps. `max_retry_delay_ms` defaults
to 10,000 ms. If Retry-After or backoff cannot fit the delay/remaining-time policy,
the batch is abandoned and counted, rather than retried earlier than requested.
Total expiry releases the active client, budget and lock; waiting callers have
their own total deadline. Cancellation for shutdown follows drain/loss accounting.

Batch limits bound serialized retention. One request can exceed the batch
record threshold while remaining within its byte bound. Overflow, filter
decisions, processor errors and shutdown loss have separate counters.

## Files, plugins and shutdown

JSONL exporters default to max_bytes: 67108864 and max_files: 5, including the
current file. Rotation retains numbered archives and removes the oldest. A line
larger than the size limit fails rather than violating it. Writes are not fsynced.
Rotation bounds files managed by that destination, not the entire disk; monitor
free space and keep output directories private.
service.file_budget_bytes defaults to 1 GiB and caps the sum of configured
max_bytes * max_files across independent file destinations (up to 2 GiB minus
one byte when explicitly configured). Shared attachments count once. Preflight
rejects existing current/archive files above their configured per-file limit
without deleting or truncating them. Unrelated files and external writers are
outside this retention contract; this is not a filesystem quota.

Preflight resolves parent paths and rejects colliding destinations/archives,
existing symlink/nonregular outputs and overlapping resolved listeners.
It cannot prevent hostile local directory changes after validation.
Configuration rejects unreferenced components before invoking custom factories.

Factories validate without I/O. Processors return independent envelopes and
must handle reuse across pipelines safely. Exporters report rejected counts
and release resources in close. Each close has a deadline; a hung plugin does
not prevent another plugin closing. Plugins are trusted code.

For a stricter privacy starting point, use `examples/strict-security.json` and
set distinct MOONTELEMETRY_INGEST_TOKEN / MOONTELEMETRY_HEALTH_TOKEN values.
It masks every log body, removes non-allowlisted attributes and runs before all
exporters. Review the allowlist for your data. The regular example retains body
text; key redaction alone cannot remove secrets embedded in arbitrary free text.

Shutdown stops admission, flushes batches and drains within shutdown_timeout_ms
(default 30 s). Expiry records outstanding data as shutdown loss. Crashes can
lose volatile queues, and retry after interruption can duplicate delivery.
No exactly-once or durable at-least-once guarantee is provided. Timed shutdown
is tested. Linux CI additionally checks SIGINT/SIGTERM with a pending record
and a strong-kill/restart loss case; Windows console events and deployment-host
supervisor behavior still need verification. On Linux, the async runtime retains
the signal exit status after cleanup; a nonzero signal status alone does not
mean flushing failed.
