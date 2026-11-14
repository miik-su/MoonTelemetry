# Ecosystem positioning and independent contribution

Reviewed 2026-11-14 using Mooncakes searches for `telemetry`, `opentelemetry`,
`collector` and `otelmoonback`, and the linked projects' published documentation.
Search results are not an exhaustive uniqueness certification.

| Project | Main responsibility | Relationship to MoonTelemetry |
| --- | --- | --- |
| [moonbit-community/opentelemetry](https://mooncakes.io/docs/moonbit-community/opentelemetry) | Application instrumentation APIs, SDK providers, processing and outbound OTLP export | Dependency: generated protocol models are reused; the SDK demo supplies real telemetry to the separate Collector |
| [moonbitstack/moontel](https://mooncakes.io/docs/moonbitstack/moontel) | Application tracing/logging/metrics, propagation and export to a collector | Related instrumentation layer; MoonTelemetry focuses on independent ingestion, routing and service lifecycle |
| [KKKIIO/otelmoonback](https://mooncakes.io/docs/KKKIIO/otelmoonback) | Moonback HTTP server instrumentation, context extraction and request metrics | Produces application telemetry; its published description does not establish a standalone Collector implementation |
| [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector) | Mature Go Collector framework | Architecture reference: component boundaries and service pipelines; Apache-2.0; no Go source is copied or distributed |

MoonTelemetry is an independently implemented MoonBit Collector that runs as a
separate process. Its own implementation covers:

- OTLP/HTTP admission, JSON/protobuf/gzip boundaries, authentication and source
  controls, dynamic request reservations and receiver statistics.
- Configured signal pipelines, ordered transforms, privacy filtering, batching
  and independent bounded destination queues with explicit loss accounting.
- Shared serialized destinations, retry classification and total export
  deadlines, bounded close, startup preflight and health/readiness contracts.
- A runnable CLI, strict configuration and extension traits/factories.
- Model roundtrips and differential checks against an official Go Collector,
  replayable mutation feedback, lifecycle faults and retained load evidence.

The generated telemetry models, async I/O and protobuf runtime are dependencies,
not original models or a new SDK. Original/borrowed code, fixtures and reference
scope are distinguished in [third-party notices](../THIRD_PARTY_NOTICES.md).
The project makes no claim to be the first or only MoonBit observability project,
or to implement the entire Go Collector ecosystem.

The delivery scope remains Native, OTLP/HTTP and volatile queues. See
[scope](../SCOPE.md) and [compatibility](../COMPATIBILITY.md). Practical reuse is
through the CLI or the published packages' generated interfaces; production
qualification and unsupported transports remain separate.
