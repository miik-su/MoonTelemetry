# Project scope

MoonTelemetry is a native MoonBit observability Collector. It receives Logs,
Metrics and Traces over OTLP/HTTP, processes them in configured order and fans
out to independently bounded destination queues. Applications instrument with
an SDK; the Collector runs as a separate service.

Data adapters, configuration, orchestration, network handling, processors,
exporters, CLI, examples, tests, benchmarks and automation use MoonBit.
Generated protocol models and async I/O are dependencies. A small original C
shim supplies operating-system RSS measurements on native platforms.

Native is the deployment target. JSON configuration is strict. Components
extend through MoonBit traits and factory registration. Receiver, processor,
exporter and service contracts stay separate. Shared exporter instances
serialize sends and close after active sends finish.

This 0.1.x project remains experimental. Volatile queues, bounded retries,
logical memory budgets and rotating files do not provide durable delivery,
exactly-once semantics, a hard RSS ceiling or a filesystem security boundary.
See [compatibility](COMPATIBILITY.md), [operations](docs/OPERATIONS.md) and
[security policy](SECURITY.md) for concrete contracts.

gRPC, YAML, profiles, durable queues, tail sampling, dashboard and distributed
coordination are outside the current implementation. Long-duration production
qualification remains separate from the focused regressions and short-load
evidence recorded in [validation](docs/VALIDATION.md).
