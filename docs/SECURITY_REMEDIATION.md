# Security remediation record

The current hardening work covers the following audit areas. These are implemented
controls with focused regression evidence, not an independent security audit.

| Area | Implemented |
| --- | --- |
| Resource admission | Shared request/queue/workspace/outbound logical budgets; reservation rollback and cancellation cleanup; global connection limit |
| Parsing | Configurable lower complexity bounds, strict duplicate keys, UTF-8/wire/depth checks, cumulative gzip bound and 16-member cap |
| OTLP interoperability | Exact numeric 64-bit JSON, future enums, semantic IDs, unpacked repeated primitives, strict response encoding/size and oneof handling |
| Export lifecycle | Persistent serialized destinations, bounded retries with Retry-After/jitter, separately bounded plugin close |
| Configuration boundaries | Unused-component rejection, strict URL authority, resolved listener conflicts, output/rotation path preflight |
| Privacy and exposure | Bearer ingress auth, source-IP restrictions, separate health auth, recursive redaction with case-insensitive keys, allowlist and removal |
| Storage | Global configured file-retention budget, per-file rotation, oversize-line/archive refusal and export failure accounting |
| Observability | Native RSS independent of logical usage; receiver, processor, queue and destination counters with safe error categories |
| Duplication and maintenance | Reused upstream models, descriptor consistency checker, shared component catalog, generated module/CLI version |
| Governance | Security policy, contribution policy, third-party license/LLVM-exception notices, changelog and explicit experimental scope |
| Validation | Malformed-input regression corpus, short HTTP load test, actual Go Collector interop, Ubuntu/Windows key CI checks |

MemoryBudget operations are synchronous and designed for one cooperative event
loop. Cross-thread access is unsupported. Logical charging does not include every
allocator/object cost and does not establish a hard RSS ceiling. Custom plugins,
configurations, environment values and output directories remain trusted inputs.

See [operations](OPERATIONS.md) for defaults and delivery contracts,
[compatibility](../COMPATIBILITY.md) for protocol limits,
[validation](VALIDATION.md) and [performance](PERFORMANCE.md) for evidence.

Recent changes add incremental request reservations, total export deadlines,
separate liveness/readiness responses, opt-in overload admission rejection,
strict privacy configuration, expanded external model tests, coverage feedback
and manifest provenance. Dated evidence includes Linux signals and real ENOSPC.

Remaining qualification includes a fully reproducible transitive build
chain, multi-hour/day soak, deployment-host console handling and sustained disk-full
recovery. No claim of full protocol certification, production readiness or
exactly-once delivery is made. Root CI actions, compiler and core versions are
pinned. Transitive action tags and unenforced archive checksums remain gaps.
