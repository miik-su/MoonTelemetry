# Validation record — 2026-11-13

Toolchain: moon 0.1.20261104 / moonc 0.10.20+65efd5b93, Native.
Local evidence uses Windows x64/MSVC; CI also exercises Ubuntu x64.
Only selected packages and necessary integration scenarios are tested. No
full-suite test command was used. Historical evidence remains separately dated.

## Focused package checks

[Implementation 118d469, both platforms passed](https://github.com/miik-su/MoonTelemetry/actions/runs/43419164652):

| Selected package | Passed tests per platform | Focus |
| --- | ---: | --- |
| core/component | 3 | Budgets and lifecycle |
| pipeline | 2 | Reservations, in-flight and fanout accounting |
| extensions/memory | 1 | Native RSS |
| core/data | 22 | Exact integers, oneofs, future enums, unknown-field loss, metric sint32/float boundaries and structural semantics |
| processor | 5 | Processing order and privacy transforms |
| config | 8 | Endpoint/auth/budget validation, export deadlines and deterministic mutations |
| exporter | 2 | Response/retry classification |
| service | 1 | Runtime contracts |
| cli | 1 | Argument boundaries |
| receiver/otlp | 2 | Decoding/admission boundaries |
| tests/integration | 27 Linux / 26 Windows | Dynamic request reservations, export deadlines, readiness, privacy, overload policy, Linux ENOSPC and existing HTTP/file/plugin cases |

These counts describe that run: 74 selected tests on Linux, 73 on Windows.
Linux's additional case executes an actual `/dev/full` write failure; it also
has an explicit single-test step in the lifecycle workflow. CI additionally
checks formatting, generated interfaces/version, 40 upstream descriptors,
dependency policy and a five-second HTTP smoke run. [Structured counts and
job provenance](results/2026-11-13/tests.json) preserve the exact source revision.

## External implementation and model matrix

The official Go Collector 0.165.0 is downloaded from its release with
repository-pinned Windows/Linux archive SHA-256 values checked before extraction.
See [helper lock](../tools/interop-lock.json) and
[both-platform CI](https://github.com/miik-su/MoonTelemetry/actions/runs/43415697256).

Six datasets × two ingress encodings × two export encodings produce 24 return
batches. Every batch must equal the normalized fixture: 20 logs, 28 metric
points and 16 spans in total. Expanded fixtures cover all five metric branches,
negative exponential-histogram offsets, exemplars, resource/scope attributes,
AnyValue forms, exact integer limits, parent/child spans, links and events.
This is fixture interoperability, not full OTLP certification.

Nine direct differential cases compare acceptance with Go. Both accept unknown
JSON fields, future enums, exact numeric int64 and unpacked histogram values;
both reject truncated protobuf and malformed JSON. Oversized bodies are rejected
with MoonTelemetry 413 versus Go 400. All-zero IDs and duplicate JSON keys are
rejected by this project's stricter profile while this Go configuration accepts
them. Ordinary protobuf relay drops unknown fields; there is no transparent
raw-forwarding contract. The 68e863d follow-up expands the differential set to
14 cases: quoted finite doubles, NaN and quoted repeated doubles are accepted;
numeric and quoted floating-point overflow are rejected by both implementations.
Three focused float regression tests passed locally. These rules follow the
[ProtoJSON floating-point representation](https://protobuf.dev/programming-guides/json/#representation-of-each-type).
Metric semantics remain structural, without repairing
histogram relationships or cross-request time-series semantics.

```sh
moon run tools/run_external_interop.mbtx --target native
```

The launcher manages helper readiness and cleanup. Raw results, sources and
limitations are indexed in [the dated evidence](results/2026-11-13/README.md).

## Mutation feedback and dependency provenance

The isolated Native fuzz worker uses real compiler coverage counter feedback.
Newly covered inputs enter the mutation corpus; each input has a time and size
bound, and crashes retain the input before failing the driver. The recorded
local run completed 1,024 iterations, observed 936 counter slots and retained
26 interesting mutations with zero crashes. This is not a coverage percentage,
ASan run or security certification.

```sh
moon build tests/fuzzcase --target native --enable-coverage
moon run tools/coverage_fuzz.mbtx --target native
moon run tools/replay_fuzz_corpus.mbtx --target native
# Replay a retained case after building the worker:
moon run tests/fuzzcase --target native -- _build/fuzz/active-case.json
moon run tools/check_dependencies.mbtx --target native
```

[Linux coverage workflow passed](https://github.com/miik-su/MoonTelemetry/actions/runs/43366262332).
Dependency checks enforce the three declared/resolved module versions, repository
and license policy, including transitive imports. The CycloneDX file hashes
manifests only; it does not attest complete package integrity or absence of CVEs.
Root CI actions and compiler/core versions are pinned. Tagged transitive setup
actions and missing enforced compiler/core archive checksums remain gaps.

## Load, faults and limits

[Dated load records](results/2026-11-13/README.md) distinguish an older one-hour
run affected by a latency-sampling race from corrected measurements. The old
run's 11 transport errors are retained. No zero-error claim applies to it.
RSS includes the load generator; concurrent work on the same host prevents
interpreting these results as isolated production capacity.
The corrected 89ed4eb baseline completed 3,600 seconds with 32 clients:
7,958,982 accepted and delivered, 7,883 HTTP 503 rejections, zero transport
errors, zero queue/shutdown loss and zero final logical/request budgets. The
verified final 10,000-sample window reports P50/P95/P99 10/24/29 ms. Sampled
whole-harness RSS peak/final is 19,124,224 / 14,741,504 bytes. This source predates
the subsequent float parsing change; its exact revision and shared-host limits
remain in the [raw record and automatic checks](results/2026-11-13/README.md).

Linux signal/crash/restart checks and the actual ENOSPC regression run in
[Native lifecycle fault checks](https://github.com/miik-su/MoonTelemetry/actions/workflows/faults.yml).
Signal checks require a pending acknowledged record to flush, beyond simply
observing process termination. Hard termination/restart demonstrates volatile
loss, not durable recovery. `/dev/full` exercises a low-level destination;
service config correctly refuses device outputs. It does not simulate a whole
deployment filesystem filling up.

Multi-hour/day soak, container deployment, Windows console signals and sustained
disk-exhaustion recovery still require qualification. The project remains
experimental, with volatile queues and no exactly-once guarantee.
