# Protocol compatibility

Reference: [OTLP specification](https://opentelemetry.io/docs/specs/otlp/).
Generated models are reused from `moonbit-community/opentelemetry` 0.1.8.

| Area | Supported behavior |
| --- | --- |
| Transport | OTLP/HTTP JSON and protobuf on /v1/logs, /v1/metrics, /v1/traces; persistent connections |
| Compression | gzip input, including up to 16 concatenated members; compressed and cumulative expanded sizes bounded |
| Signals | Logs, traces, Gauge, Sum, Histogram, ExponentialHistogram and Summary |
| Structure | Resource/scope attributes, events, links, exemplars, correlation IDs and typed AnyValue |
| Integers | Decimal strings and exact integral JSON numeric/exponent forms for 64-bit fields; fractional or out-of-range values rejected |
| Enums | Integer JSON enums; unknown positive and negative numbers retained through supported transforms and batching |
| IDs | Hex JSON / binary protobuf; nonempty IDs require valid length and nonzero contents; spans and links require trace/span IDs |
| Repeated primitives | Packed and unpacked protobuf input normalized before generated-model decoding |
| JSON boundaries | Duplicate keys rejected; unknown fields ignored; known null fields treated as absent; oneof identity checked |
| Responses | Matching JSON/protobuf success and google.rpc.Status errors; successful partial responses counted and never retried |

Symbolic JSON enum names are rejected. The pinned SDK can emit these names, so
the SDK demo uses protobuf; numeric-enum JSON fixtures exercise JSON ingestion.
Unknown protobuf fields are skipped by the generated models. Ordinary relay
without any processors also does **not** guarantee their preservation. This is
not a transparent raw-protobuf proxy. Root and nested unknown-field injection
are covered in core/data/unknown_fields_wbtest.mbt; known fields are preserved
while the injected unknown fields disappear on normal decode/re-encode.
Some fallback paths may retain wire bytes, but this is not a preservation
contract. Transforms and JSON conversion reconstruct only recognized fields.
The future-enum fallback preserves enum numbers, not arbitrary future schemas.
Protobuf oneofs use the last member on the wire; JSON with multiple members of
the same oneof is rejected.

Ingress acknowledgement means admission to volatile input queues. Filtering and
export occur afterwards. Invalid input returns 400, unsupported media/encoding
415, oversized input 413, unavailable/full admission 503, and missing configured
signal routes 404. Authentication and source restrictions precede body reads.
Slow headers, body stalls and total request duration are bounded.

Successful outbound responses must match the selected media type and decode as
the signal response. Empty protobuf is valid; empty JSON is invalid. Response
reads default to 4 MiB and can be configured up to 64 MiB per exporter.
429/502/503/504 and transport failures can retry. Retry-After supports seconds
and IMF-fixdate, capped at one hour; retries include bounded random jitter.

`core/data` contains field-dispatch metadata to adapt upstream JSON oneof
inference and enum representation. It defines no duplicate telemetry structs.
`tools/check_protocol_metadata.mbtx` checks 40 descriptors against the pinned
generated source; review the adapter when upgrading dependencies.

Real Go Collector 0.165.0 received all three signals in both HTTP encodings and
forwarded them back to a second MoonTelemetry with fixture-equivalent contents;
see [validation](docs/VALIDATION.md). This covers the committed fixtures and
does not establish full OTLP conformance certification.

Metric validation is structural: it does
not enforce every histogram bucket/count relationship, timestamp ordering,
monotonicity or cross-request time-series business rule. Structurally accepted
data is forwarded without silently repairing these semantics. A focused test
documents this boundary in core/data/semantic_boundary_test.mbt.

Not implemented: gRPC, receiver TLS termination, YAML configuration, profiles,
persistent/durable queues, durable delivery guarantees, Prometheus ingestion,
Kafka, tail sampling, remote configuration or
cluster coordination. Bearer authentication and source-IP restrictions are
available; use trusted TLS termination for remote deployment. HTTPS export
uses the async library's trust roots.
