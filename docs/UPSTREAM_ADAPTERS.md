# Upstream model and dependency maintenance

MoonTelemetry reuses OpenTelemetry generated types and keeps local adapters for
the OTLP wire and JSON profile. Require a focused regression before removing
an adapter. The generator and its emitted code can change independently of the
protobuf runtime.

| Area | Contract and regression |
| --- | --- |
| Signed metric fields | Nested protobuf lengths must match zigzag-encoded int32 scale and bucket offsets. Run `core/data/metric_sint_test.mbt`. |
| Numeric JSON enums | OTLP clients can send numeric enum values outside the current generated enum set. Preserve modeled future values through transforms. Run `core/data/enum_test.mbt` and `wire_compat_test.mbt`. |
| JSON oneof and typed values | Reject competing oneof fields, preserve exact 64-bit integers and bounded nested AnyValue, and compare JSON/protobuf roundtrips. Run protocol metadata, codec and model boundary checks. |
| Release gate | Verify the proposed archives and generated API diff, and compare all three signal fixtures with the official Go Collector before shipping. |

## 2026-11-23 evaluation

The registry listed OpenTelemetry 0.1.8 and protobuf 0.2.0. An isolated checkout
resolved OpenTelemetry 0.1.8 against protobuf 0.2.0. Native checking and six focused
protocol tests passed with the local adapters intact. Switching metrics to the
generated writer in that same checkout failed the existing nested zigzag
regression. Runtime-only upgrade therefore does not repair the pinned generated
model. Retain protobuf 0.1.3 and the adapter on the release branch.

A generator-side contribution should compare a negative exponential-histogram
offset and scales on both sides of a varint boundary. Check that the reported
nested message size equals the emitted byte length, then regenerate the model
and run the existing regression with the local workaround removed. Keep the JSON
enum and oneof gates independent of this binary change.

[OpenTelemetry module](https://mooncakes.io/docs/moonbit-community/opentelemetry%400.1.8)
and [protobuf generator](https://github.com/moonbitlang/protoc-gen-mbt).

## GitHub Actions update review

| PR | Checked change | Decision |
| --- | --- | --- |
| [#1](https://github.com/miik-su/MoonTelemetry/pull/1) | Checkout v7.0.1 changes checkout safeguards and uses Node 24. | Keep the existing reviewed pin while changing bootstrap. Evaluate the major update independently across all workflows. |
| [#2](https://github.com/miik-su/MoonTelemetry/pull/2) | Artifact v7.0.2 uses Node 24 and updates its artifact client. | Keep the existing pin for the evidence baseline. When updating, verify retention and download of Linux and Windows artifacts. |
| [#3](https://github.com/miik-su/MoonTelemetry/pull/3) | Setup v1.26 changes the transitive Nushell action to a newer tag. | Superseded by repository-owned compiler/core archive verification. |

Release notes: [checkout](https://github.com/actions/checkout/releases/tag/v7.0.1),
[upload-artifact](https://github.com/actions/upload-artifact/releases/tag/v7.0.2),
[setup-moonbit](https://github.com/hustcer/setup-moonbit/releases/tag/v1.26).

## Integrity scope

CI checks compiler and core archives before extraction. Compiler hashes were
cross-checked with the official checksum files. Core hashes record the exact
archives retrieved from the official versioned HTTPS endpoints. Mooncakes module
archive hashes and installed module manifests are checked after dependency sync
and before running project tests and executables.

An upgrade should update the archive and module locks in review, explain every
new transitive dependency and rerun the focused compatibility checks. Archive
verification does not cover the runner operating system, installed libraries,
the unpacked module tree or vulnerability status.
