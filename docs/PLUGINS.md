# Plugin API contract v1

`core/component.plugin_api_version()` returns 1. Factory registration accepts
`api_version=1` (also the legacy/default value). Unsupported versions reject
before reserving a name or invoking a factory. This is an in-process source API
contract, not a shared-library ABI or a sandbox. Future incompatible trait or
ownership changes must increment the contract and document migration.

| Stage | Contract |
| --- | --- |
| Registration | Unique name per component kind, no factory invocation |
| Validation/construction | Configuration is trusted; validate without network/file side effects; unused components reject before custom factories run |
| Processor input | Synchronous execution; return independently owned envelopes when modifying them; the same configured instance may be reused by pipelines |
| Exporter input | One shared destination per configured exporter ID; framework serializes calls, including retries and close |
| Rejection | Return a record count in 0..input.count(); invalid counts reject the whole batch with invalid_rejected_count, rather than reporting false success |
| Errors | Processor exceptions and exporter errors have safe category/component statistics; payloads and exception strings are not exposed through health |
| Cancellation | Sends may be cancelled by total deadlines or shutdown; release owned resources with cancellation-safe cleanup |
| Close | Must be idempotent from the plugin's perspective; framework enters close once after serialized sends, with a bounded deadline |

Factory registration is not resource initialization. Constructors should not
allocate external resources before successful runtime preflight. The framework
cannot preempt a synchronous infinite loop or make a non-cooperative plugin
safe. Cooperative event-loop use is supported; cross-thread sharing is not.

Exporter-specific retry policy is the plugin's responsibility unless it uses the
built-in OTLP exporter. Do not independently retry a partially successful batch
without understanding duplicate delivery. Plugins remain trusted code capable
of accessing the process environment/files/network; the API version does not
certify security, protocol conformance or compatibility with every future patch.

Registration compatibility is tested in core/component/plugin_api_test.mbt;
runtime ownership/serialization/startup cleanup/close deadlines are exercised
in tests/integration/plugin_test.mbt, exporter_safety_test.mbt and
close_timeout_test.mbt. See [delivery semantics](OPERATIONS.md).
