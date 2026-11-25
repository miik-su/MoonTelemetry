# Local performance evidence

The [separate process mixed-signal run](results/2026-11-23/README.md) measures
Collector CPU and RSS independently, with three clients and two HTTP sinks.
It runs a paced workload on one host. Use that page for its source revision,
duration, counts and reproduction commands.

For longer runs, set `MOONTELEMETRY_MIXED_SECONDS`. The local helper accepts up
to 86,400 seconds and the manual GitHub workflow up to 14,400 seconds. New
reports include sampled input/output queue lengths, retained output bytes,
logical/request budget use and Collector RSS. Samples are taken about once a
second for short runs and once every five seconds at 600 seconds or longer.
The configured pause rate applies per client after each completed request.

When testing a second harness concurrently, choose separate
`MOONTELEMETRY_MIXED_RESULT_DIR` and `--target-dir` paths. Report the shared-host
load and use separate hosts for production capacity qualification.

For local synthetic qualification, use a clean dedicated checkout and run
`moon run tools/run_local_qualification.mbtx --target native`. It runs a
four-hour profile with a 10 ms per-client pause, then a 24-hour profile with a
25 ms pause. The long profile starts only after the first profile succeeds.
Reports and stage status stay in `_build/local-qualification/`. Keep the host
awake for both runs. These profiles exercise paced loopback delivery and
resource behavior for the tested source. Live deployment acceptance depends on
the actual host, network, storage and supervisor.

This page retains historical measurements. Current dated matrix evidence and
the older one-hour run's sampling limitation are in
[2026-11-13 results](results/2026-11-13/README.md).
That page includes a corrected one-hour/32-client run: 7,958,982 accepted and
delivered, 7,883 HTTP 503, zero transport errors and verified final budgets.
Its sampled RSS and queue trend are generated from retained progress records;
read its exact baseline revision and shared-host limitations before comparing.

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

## Ten-minute run

The same eight-client workload was extended to 600 seconds with the same local
0.10.17 toolchain and Collector source based on a97f7e0. The harness gained
configurable duration and HTTP status counts; later compiler/cleanup changes
were not part of this running binary. Reproduce the workload with:

```sh
moon run benchmarks/collector --release -- --seconds 600
```

| Measurement | Observed |
| --- | ---: |
| Accepted / HTTP 200 | 1,728,309 |
| Rejected / HTTP 503 | 4,127 |
| Transport errors | 0 |
| Accepted requests / second | 2,880.515 |
| p50 / p95 / p99 of final 10,000 | 1 / 17 / 19 ms |
| Peak whole-process RSS | 14,819,328 bytes |
| Final whole-process RSS | 12,062,720 bytes |
| Successful / failed file batches | 13,687 / 0 |
| Delivered accepted records | 1,728,309 |
| Overflow / shutdown losses | 0 / 0 |
| Logical / request budget after shutdown | 0 / 0 |

RSS includes the load generator. These observations do not prove absence of
long-term growth: no multi-hour/daily run or disk-exhaustion load was performed.
Status counts separate overload rejection from transport failure; only accepted
records are subject to the delivery accounting comparison above.
