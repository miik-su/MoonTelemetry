# Security remediation record

The 0.1.1 hardening work covers the following audit areas. These are implemented
controls with focused regression evidence, not an independent security audit.

| Area | Implemented |
| --- | --- |
| Resource admission | Shared request/queue/workspace/outbound logical budgets; reservation rollback and cancellation cleanup; global connection limit |
| Parsing | Configurable lower complexity bounds, strict duplicate keys, UTF-8/wire/depth checks, cumulative gzip bound and 16-member cap |
| OTLP interoperability | Exact numeric 64-bit JSON, future enums, semantic IDs, unpacked repeated primitives, strict response encoding/size and oneof handling |
| Export lifecycle | Persistent serialized destinations, bounded retries with Retry-After/jitter, separately bounded plugin close |
| Configuration boundaries | Unused-component rejection, strict URL authority, resolved listener conflicts, output/rotation path preflight |
| Privacy and exposure | Bearer ingress auth, source-IP restrictions, separate health auth, recursive redaction with case-insensitive keys, allowlist and removal |
| Storage | Bounded per-file rotation/retention, oversize-line refusal and export failure accounting |
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

Remaining qualification includes a fully reproducible compiler/transitive build
chain, long-duration soak, deployment-host signal handling and sustained disk-full
testing. No claim of full protocol certification, production readiness or
exactly-once delivery is made. Root CI action pinning is implemented; installing
the compiler still follows latest and must not be described as fully pinned.
