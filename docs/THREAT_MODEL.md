# Maintained threat model

Assets: telemetry confidentiality/integrity, bounded resources, private
credentials/output paths and trustworthy protocol/queue/error accounting.
Remote peers/payloads are untrusted. Configuration, plugins, host, toolchain and
deployment administrator remain trusted.

| Boundary / threat | Control | Evidence / retained limit |
| --- | --- | --- |
| Ingestion / unauthorized sender | Bearer and socket-peer checks before parsing | receiver_security_test.mbt; remote plain HTTP needs trusted TLS termination |
| Parser / large, deep, malformed data | Wire/UTF-8/type/field/record/depth limits, duplicate-key policy | core/data complexity/wire/model_boundary tests; bounded synchronous work is not preemptible |
| Gzip / expansion or many members | Shared growing reservations, cumulative cap, 16 members | gzip_fuzz_test.mbt, dynamic_budget_test.mbt; logical budget is not RSS quota |
| Filter config / expression cost | Typed DSL, depth 8, nodes 64, bounded groups/strings | processor/filter_test.mbt, config/filter_test.mbt; no script/regex |
| Privacy / unredacted export | Ordered redaction and post-redaction filtering | filter_pipeline_test.mbt, delivery_policy_test.mbt; arbitrary free text needs body masking/application controls |
| Export / retry lock exhaustion | Total deadline covers lock/backoff; bounded attempts/responses | export_deadline_test.mbt; uncertain network completion may duplicate delivery |
| Plugin / bookkeeping or lifecycle | Versioned registration, serialized send/close, count validation | plugin_api_test.mbt, plugin_rejection_test.mbt and plugin/close tests; trusted plugins can still block synchronously or access host resources |
| Files / collisions, growth, full disk | Preflight, retention bounds, safe failures | exporter_safety_test.mbt, Linux disk_full_test.mbt; no sandbox/quota/fsync guarantee |
| Process / crash or shutdown | Bounded drain, loss accounting, volatile contract | Linux lifecycle workflow; Windows console events and deployment supervisors need separate qualification |
| Supply chain / changed dependencies | Exact module policy, pinned module/toolchain archive hashes, descriptors and local package checks | check_dependencies.mbtx, setup-verified-moon, check_distribution.mbtx. Review of unpacked source, system libraries and CVEs is separate. |

Unprefixed runtime tests above are in tests/integration; plugin_api_test is in
core/component. Use synthetic reproductions, not customer telemetry/credentials.
Restrict health because it exposes operational state. Shared destinations appear
under several pipelines; do not sum their counters twice.

Update this mapping when changing network/storage/plugin behavior. Review actual
dependency advisories and pinned Action changes; passing CI is not a security
review. Upstream C/runtime issues are not excluded by MoonBit application code.
No ASan, penetration-test or absence-of-vulnerabilities claim is made.
