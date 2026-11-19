# License, protocol and operational contracts

These documents describe different contracts; none substitutes for the others.

| Contract | Authority and scope |
| --- | --- |
| Source license | Root LICENSE, Apache-2.0; NOTICE and THIRD_PARTY_NOTICES.md preserve attribution/exception information |
| Dependencies/models | Upstream licenses apply; reused generated models are not original telemetry schemas |
| Fixtures/mutations | Golden fixtures retain provenance; expanded fixtures and synthetic mutations have source/license notes |
| OTLP profile | COMPATIBILITY.md states implemented behavior and limits, not universal conformance |
| Delivery | OPERATIONS.md defines volatile admission, filtering, queues, retries, partial rejection and shutdown |
| Extension API | PLUGINS.md v1 describes ownership, serialization, rejection and cancellation; no sandbox or binary ABI |
| Security | SECURITY.md defines controls and trust; test evidence is not security certification |

Models here are OpenTelemetry protocol structures, not AI weights. The project
adds no AI training license. Runtime user telemetry does not automatically become
Apache-licensed by passing through the Collector. Operators determine their
authority to collect/store/export it and protect configurations and credentials.

Apache-2.0 grants software rights under its terms, including warranty/liability
provisions. Documentation does not add a paid SLA, production-security warranty,
exactly-once guarantee or data-processing service agreement. Deploying the code
does not operate a hosted service on this project's behalf. Do not imply
OpenTelemetry/CNCF endorsement or trademark rights.

Before adding dependencies, copied code or data, record source project/version,
repository, license and modifications. Preserve required copyright/NOTICE text;
review platform-library redistribution when distributing binaries. Label design
references separately from shipped source. Package checks verify selected files
and metadata, not independent legal compliance.

Protocol compatibility and license compatibility are separate. Structurally valid
metrics can violate application relationships; unknown protobuf fields can be
lost on re-encoding. Filters remove matching data after ingress acknowledgement.
These are operational limits, not changes to source licensing.

References: [LICENSE](../LICENSE), [third-party notices](../THIRD_PARTY_NOTICES.md),
[OTLP](https://opentelemetry.io/docs/specs/otlp/),
[plugin contract](PLUGINS.md), [security policy](../SECURITY.md).
