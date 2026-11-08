# Protocol compatibility

Reference: https://opentelemetry.io/docs/specs/otlp/.
Pinned generated models: moonbit-community/opentelemetry 0.1.8.

- OTLP/HTTP JSON and protobuf on the three standard signal paths.
- Gauge, Sum, Histogram, ExponentialHistogram and Summary metric data.
- Resource, scope, typed attributes, events, links and correlation IDs.
- Nanosecond timestamps and 64-bit numbers use decimal JSON strings. Numeric
  JSON forms for 64-bit fields are currently rejected; send strings.
- JSON enums use integers. Symbolic enum strings are rejected. The pinned SDK's
  JSON exporter can emit symbolic enums; the runnable SDK demo therefore uses
  HTTP/Protobuf. Standard numeric-enum SDK golden JSON fixtures are tested.
- Trace/span IDs use hex in JSON and bytes in protobuf. Empty/absent IDs are
  retained; nonempty IDs must have the specified length. Semantic validation
  beyond length/encoding (for example all-zero IDs) is not implemented.
- JSON unknown fields are ignored. Known fields with null are treated as absent.
- Successful receiver acknowledgements mean admission to volatile input queues.
  Configured filtering happens later and is recorded in pipeline statistics.
- Exporters decode partial success and never retry that successful response.
- gzip inputs are bounded both before and after decompression.
- Nested protobuf messages have length, wire-type and depth guards (64 levels).
  Packed metric arrays are supported; alternate unpacked repeated numeric wire
  encodings are not supported by the pinned generated decoder.
- Unknown binary fields are skipped but not preserved through transformations.
- Responses use matching JSON/protobuf encodings; errors use google.rpc.Status
  wire shape. Unsupported media/encoding returns 415; oversized bodies 413;
  malformed OTLP 400; unavailable/full admission 503.

The JSON adapter in core/data keeps field dispatch metadata to work around the
pinned generated FromJson implementation's oneof inference. It converts JSON
to the upstream binary model and normalizes enum/bytes output; it does not define
a second set of telemetry structs. Review this adapter when upgrading models.

Not supported: gRPC, TLS termination at the receiver, authentication, YAML,
profiles, persistent queues, Prometheus ingestion, Kafka, tail sampling,
remote configuration and cluster coordination. Use a trusted reverse proxy for
network exposure. HTTPS export uses the async library's trusted roots.
