# Local performance evidence

Measured 2026-11-08 on Windows x64 / MSVC, Native release build,
moon 0.1.20261023. Reproduce with:

```sh
moon run benchmarks/collector --release -- --soak
```

The harness runs the HTTP load generator and Collector in one process for
60 seconds with eight concurrent clients. It exercises admission, processing,
batching and a rotating JSONL exporter (1 MiB current file, three retained files).
Latencies use a rolling buffer of the final 10,000 observations.

| Measurement | Observed |
| --- | ---: |
| Accepted requests | 175,806 |
| Overload rejections | 374 |
| Transport errors | 0 |
| Accepted requests / second | 2,930.1 |
| p50 / p95 / p99 of final 10,000 | 1 / 17 / 18 ms |
| Peak whole-process RSS | 13,950,976 bytes |
| Final whole-process RSS | 11,821,056 bytes |
| Successful file batches | 1,382 |
| Failed file batches | 0 |
| Delivered accepted records | 175,806 |
| Overflow / shutdown losses | 0 / 0 |
| Logical / request budget after shutdown | 0 / 0 |

This is a single short local measurement. RSS includes the load generator and
Collector; it is not isolated service RSS. Latency percentiles describe the
rolling tail sample, not the entire run. Results depend on fixture, host,
filesystem, configuration and compiler. No cross-language comparison or
production capacity guarantee follows from them.

The workload exposed connection churn and reuse of server-closed sockets in the
harness. The receiver now supports persistent requests; the harness reconnects
when Connection: close is returned. The table records the final corrected run.

Long-duration soak, allocator growth, disk-full behavior under sustained load,
many independent destinations and separate-machine load generation still need
deployment qualification. The microbenchmark in benchmarks/main.mbt measures
a different decode/transform/encode workload and cannot substitute for HTTP load.
