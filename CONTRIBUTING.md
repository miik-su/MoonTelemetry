# Contributing

Use small changes with a clear behavior change and a focused regression test.
Keep Collector orchestration separate from application instrumentation SDKs.
Native is the supported deployment backend. Follow the existing package layout
and `///|` blocks. Automation scripts use MoonBit `.mbtx`.

Before submitting, run `moon check`, affected-package tests, `moon fmt` and
`moon info`; review generated API diffs. Protocol/queue/lifecycle changes should
also run `moon test -p tests/integration`. Avoid unnecessary full-suite runs.
Run `moon run tools/check_protocol_metadata.mbtx` after protocol/dependency changes.
Run `moon run tools/generate_metadata.mbtx` after changing the module version.

Do not hand-edit generated interfaces. Include reproducible commands, toolchain
versions and measured limitations in performance reports. Never put real customer
telemetry or credentials in fixtures. Report vulnerabilities through SECURITY.md.

Contributions are provided under the project's Apache-2.0 license. No separate
CLA or commercial service terms are required by this project.
