# Audit follow-up — 2026-11-13

This maps the recent audit recommendations to implementation and evidence.
Evidence is tied to the source revision stated in each raw file or CI run;
documentation commits do not retroactively change measured revisions.

| Recommendation | Implemented response | Evidence / boundary |
| --- | --- | --- |
| Unknown protobuf fields | Root and nested unknown-field injection during ordinary relay; explicit loss contract | `core/data/unknown_fields_wbtest.mbt`; no transparent raw-relay mode promised |
| Broader model validation | All five metric branches, exemplars, complex AnyValue, multi-resource/scope and linked parent/child traces | [Dated interop records](results/2026-11-13/README.md), 24 fixture return batches and 14 differential cases |
| Current load and faults | Corrected unique latency sampling, 8/32/64 clients, small/large/slow scenarios, RSS/progress, queue conservation, real Linux signals/crash/restart/ENOSPC | [Load and fault evidence](results/2026-11-13/README.md); per-scenario durations and limitations remain explicit |
| CLI and receiver CI gaps | Both are direct package targets; external Collector and faults are independent jobs | Eleven selected package targets; full-suite execution intentionally omitted to respect the requested test scope |
| Coverage-guided mutation | Native compiler counters drive corpus growth; isolated bounded worker; inputs retained before execution | [Workflow](../.github/workflows/fuzz.yml), committed 26-case corpus replay, dated Windows/Linux results; no ASan claim |
| Dependency review | Exact direct/transitive module policy, repository/license review and CycloneDX manifest provenance | [Policy](../tools/dependency-policy.json); manifest hashes are not package integrity or CVE attestations |
| Delivery boundaries | best_effort/reject_on_overload, volatile admission and per-target loss accounting documented | No durable queue, crash replay or exactly-once guarantee; slow-target losses are shown alongside HTTP success |
| Document consistency | Removed duplicate unsupported list, clarified persistent queues, updated validation/model/results pages and generated charts | Historical evidence stays dated; old one-hour sampler issue and 11 transport errors remain visible |

Expanded external tests exposed an actual signed-zigzag nested-length bug in
the pinned metric writer, which is corrected through the existing protocol
adapter without duplicating upstream telemetry models. Further boundary review
found rejected legal quoted finite doubles; the parser now accepts them while
rejecting overflow and preserving explicit nonfinite values. Both fixes have
focused MoonBit regression tests and official Collector checks.

Longer production qualification is still separate: multi-hour/day deployment
soak, Windows console events, supervisor/container behavior, sustained full-disk
recovery, complete dependency package integrity and the transitive setup chain.
This work does not certify full OTLP conformance or production readiness.

All authored automation remains MoonBit `.mbtx`; native dependencies retain
their existing C stubs. See [validation](VALIDATION.md),
[security remediation](SECURITY_REMEDIATION.md) and
[compatibility](../COMPATIBILITY.md) for the precise operating boundaries.
