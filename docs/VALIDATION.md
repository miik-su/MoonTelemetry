# Validation record — 2026-11-08

Toolchain: moon 0.1.20261023; Native; Windows x64; MSVC.
No full-suite test command was run. Relevant packages were exercised during
their implementation and again when downstream behavior changed.

| Target | Evidence |
| --- | --- |
| core/data | 6 tests: three signal codecs, timestamp/ID roundtrip, oneofs, metric aggregations, malformed protobuf |
| core/component | Registry namespace/duplicate tests and lifecycle transition checks |
| processor | Attribute isolation/resource/filter order; batch threshold/timeouts/flush |
| pipeline | Atomic fanout, capacity, retained in-flight budget |
| config | Defaults, references, bad limits, environment and escaped duplicate keys |
| exporter | Retry status classification and three-signal partial response codecs |
| receiver/otlp | Routes/media negotiation and streaming body limits |
| cli | Commands, missing flags and unknown arguments |
| service | Real HTTP -> batch -> shutdown flush -> JSONL |
| tests/integration | 5 tests: SDK golden signals with six encoding/signal combinations and dual fanout; 503 retry/partial success; gzip expansion; slow destination isolation; custom registry execution/close |

`moon check` passes without warnings after explicit trait exports. `moon fmt`
and `moon info` regenerate and verify source/API formatting. The SDK demo was
run against the live collector; traces, logs and metrics reached JSONL with
resource enrichment. The demo uses protobuf due to the upstream JSON enum issue
documented in COMPATIBILITY.md.

## Microbenchmark

`moon run benchmarks --release` on this host:

```json
{"iterations":10000,"records":10000,"elapsed_ms":1619,"records_per_second":6176}
```

This measures JSON decode + attribute deletion + protobuf encode for the log
fixture. It is a single local measurement, not a network throughput, p99 latency,
RSS, sustained-load or cross-language comparison. The executable is committed
so measurements can be repeated; no production capacity claim is made.

## Remaining release acceptance

Long-duration soak/load testing, RSS/latency measurements, Linux execution,
container deployment, console-signal behavior across platforms and independent
external collector interoperability remain release follow-up work. The local
integration target is a real HTTP server but not Jaeger/Tempo or the Go Collector.
