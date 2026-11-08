# Validation record — 2026-11-08

Local toolchain: moon 0.1.20261023 / moonc v0.10.17+d971670cd, Native,
Windows x64 / MSVC. Only affected packages and key integration targets were run;
no full-suite test command was used.

| Target | Focused evidence |
| --- | --- |
| core/data | 15 tests: exact integers, oneofs, IDs, future enums, packed/unpacked, response boundaries, deterministic 6,000 malformed-byte decode attempts |
| core/component / pipeline | Reservation rollback, in-flight accounting, fanout isolation and lifecycle |
| processor | Transform order, nested redaction/allowlist/removal, mixed future-enum batches |
| config | Six tests: references, endpoint authority, source/auth policy, memory/file limits, duplicates and environment expansion |
| exporter | Retry classification, partial responses and Retry-After seconds/date |
| extensions/memory | Native RSS observation |
| service / tests/integration | 16 integration tests: HTTP signal/encoding matrix, gzip boundaries, slow body, auth/health/source controls, cancellation, destination isolation, plugin deadlines, file failures/oversize archives, safe processor failure metadata and shutdown accounting |
| tools | Generated version consistency and 40 upstream descriptor checks |

moon check, moon fmt and moon info pass locally. GitHub Actions runs key checks
on Ubuntu and Windows. The main run for commit 4747559 passed both platforms:
[workflow run](https://github.com/miik-su/MoonTelemetry/actions/runs/42491224845).
Later commits require their own run; that result does not cover future changes.
CI root actions are SHA-pinned. Compiler and core installation are fixed to
0.10.20+65efd5b93; all four official Windows/Linux archive URLs were checked.
The setup action still uses a tagged transitive action and does not enforce
repository-pinned archive checksums. Supply-chain reproducibility is incomplete.

## External Go Collector interoperability

A locally launched official OpenTelemetry Collector 0.165.0 accepted both
HTTP/JSON and HTTP/Protobuf output for logs, metrics and traces.
Configuration: examples/interop/otelcol.yaml. Harness: tests/external/main.mbt.

```sh
otelcol --config examples/interop/otelcol.yaml
moon run tests/external
```

The harness sends six requests to MoonTelemetry (three signals, two ingress
encodings), then fans out to JSON and protobuf destinations. Each shared
destination reports six successful batches, zero failed batches/retries/rejected
records. Go Collector forwards to a second MoonTelemetry instance and JSONL.
Its queue/retries are disabled so the test observes immediate export results.
The return receiver accepts all 12 requests without rejection. JSONL contains
4 logs, 8 metric points and 4 spans. Every returned batch is compared against
the original fixture's normalized envelope, including values, IDs, attributes,
scope/resource fields and events. Both instances return logical/request budgets
to zero on shutdown. The official helper is stopped after verification.

Test listeners allow 64 KiB bodies. An earlier run with the default 32 MiB body
reservation and Go's parallel queue produced expected 503 request-budget
rejections. Small-fixture interop must not assume the conservative default
budget permits unlimited concurrent worst-case requests. This overload result
is separate from the final successful roundtrip configuration.

Windows amd64 release asset:
[otelcol_0.165.0_windows_amd64.tar.gz](https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.165.0/otelcol_0.165.0_windows_amd64.tar.gz).
Verified SHA-256 against the release checksum file before execution:

```text
e5db5558e57e05044c62998d3f635082f945f362920a335224360272b4aacc17
```

The binary is ignored under _build and is not distributed by this repository.
This validates committed fixture interoperability with that Collector version;
it is not certification of every possible OTLP field or backend.

## Load and remaining qualification

The 60-second eight-client HTTP test completed with zero transport errors,
175,806 accepted requests and zero loss of accepted records.
[Performance details and limits](PERFORMANCE.md) include RSS and latency.

Long-duration soak, container deployment, console-signal behavior across
platforms, isolated-process capacity measurements and production disk exhaustion
remain qualification work. The current patch is experimental.
