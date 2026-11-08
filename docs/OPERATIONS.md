# Operations and delivery semantics

## Admission and memory

Start with examples/collector.json. Listener defaults are loopback, 32 MiB
maximum body, 32 connections, 3 s header deadline, 3 s body-idle deadline,
1 s processing deadline and 10 s total request deadline. Connections can serve
multiple requests; idle headers eventually release connection permits.
Synchronous parsing cannot be preempted mid-operation: complexity checks bound
its work, and elapsed processing time is checked afterwards.

service.memory_budget_bytes defaults to 1 GiB and request_memory_budget_bytes
to 256 MiB. A request reserves three maximum-body buffers against both budgets
before reading/decompression, even for a small request. Reservations release
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

## Queues and delivery

Each pipeline owns an input queue and one queue per exporter attachment.
Defaults are 64 batches / 32 MiB per queue. Matching-pipeline input admission is
atomic: any full input rejects the request with 503. A full output queue drops
that destination's copy and increments overflowDropped; healthy outputs continue.
Distinct destinations run independently. A shared destination serializes all
sends, including custom exporters, and reuses HTTP connections.

Input delivered means processing completed. Output delivered means a target
accepted the response or a local append completed. Neither proves durable
storage. Successful partial OTLP responses count rejected records without retry.
Retryable HTTP codes are 429/502/503/504; transport failures also retry within
the configured attempt count. retries: 0 disables retries. Exponential backoff
includes random jitter and respects capped Retry-After seconds/HTTP dates.

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

Shutdown stops admission, flushes batches and drains within shutdown_timeout_ms
(default 30 s). Expiry records outstanding data as shutdown loss. Crashes can
lose volatile queues, and retry after interruption can duplicate delivery.
No exactly-once or durable at-least-once guarantee is provided. Timed shutdown
is tested; console-signal behavior needs deployment-host verification.
