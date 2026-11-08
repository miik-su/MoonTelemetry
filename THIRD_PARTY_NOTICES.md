# Third-party notices

MoonTelemetry source is Apache-2.0 (LICENSE). It is an independent project, not an
official OpenTelemetry or CNCF product. Trademark rights are not granted by the
source-code license.

| Component | Pinned version/source | Declared license |
| --- | --- | --- |
| moonbit-community/opentelemetry | 0.1.8, https://github.com/moonbit-community/opentelemetry.mbt | Apache-2.0 |
| moonbitlang/async | 0.22.5, https://github.com/moonbitlang/async | Apache-2.0 |
| moonbitlang/protobuf | 0.1.3, https://github.com/moonbitlang/protoc-gen-mbt | Apache-2.0 WITH LLVM-exception |
| moonbitlang/core | Supplied by the selected MoonBit toolchain, https://github.com/moonbitlang/core | Apache-2.0 |

Copyright notices in the dependencies identify International Digital Economy
Academy and upstream contributors. Dependency source is resolved through
Mooncakes; it is not vendored into this repository. Preserve applicable license,
copyright and exception notices when distributing source or compiled products.
The protobuf runtime module declares the LLVM exception even though individual
source headers mention Apache-2.0. Its published package does not contain a root
LICENSE; the upstream repository's LICENSE includes the exception text below.

The SDK golden fixtures under tests/fixtures were copied from upstream 0.1.8
integration tests; see tests/fixtures/README.md. Architecture references to the
Go OpenTelemetry Collector are design references, not copied source.

The Native RSS shim is original project code. It calls platform system APIs;
Windows SDK, operating-system libraries and the MoonBit compiler/runtime have
their own distribution terms. On Linux, the async HTTPS backend uses system
OpenSSL; on Windows it uses SChannel. Binary distributors must also account for
their platform's linked libraries. CI actions are build dependencies and retain
their respective upstream licenses.

## LLVM exception from upstream protobuf LICENSE

As an exception, if, as a result of your compiling your source code, portions
of this Software are embedded into an Object form of such source code, you
may redistribute such embedded portions in such Object form without complying
with the conditions of Sections 4(a), 4(b) and 4(d) of the License.

In addition, if you combine or link compiled forms of this Software with
software that is licensed under the GPLv2 ("Combined Software") and if a
court of competent jurisdiction determines that the patent provision (Section
3), the indemnity provision (Section 9) or other Section of the License
conflicts with the conditions of the GPLv2, you may retroactively and
prospectively choose to deem waived or otherwise exclude such Section(s) of
the License, but only in their entirety and only with respect to the Combined
Software.
