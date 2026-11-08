# MoonTelemetry

MoonBit native observability **Collector**, not an instrumentation SDK.
Receive Logs, Metrics and Traces over OTLP/HTTP, process them in configured
order, and fan out to independent bounded exporter queues.

The implementation follows the 12-stage plan in the MoonTelemetry conversation.
Native is the deployment target. JSON configuration comes first; YAML, gRPC,
persistent queues, tail sampling and a dashboard are deferred.

## Implementation sequence

1. Scope and dependency foundation
2. Reused OTLP data envelopes and codecs
3. Extensible component registry and lifecycle
4. Attribute/resource/filter processors
5. Bounded batch and admission control
6. Isolated fanout and delivery accounting
7. Strict configuration and environment expansion
8. Debug/file/OTLP exporters and retry classification
9. HTTP receiver and protocol errors
10. Runtime wiring, CLI and graceful drain
11. Protocol and end-to-end examples
12. CI, performance harness and deployment documentation

Each stage is committed separately with targeted validation. No full test run
is required for this implementation session.
