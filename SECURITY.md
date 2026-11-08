# Security policy

MoonTelemetry is experimental infrastructure. The current main branch and the
latest 0.1.x patch are the maintenance targets; older snapshots do not receive
separate backports. No response-time or production-security guarantee is made.

## Reporting

Use GitHub's **Report a vulnerability** for this repository when private reporting
is available. Otherwise open a minimal issue requesting a private contact
channel, without exploit instructions, payloads, credentials or affected user
data. Arrange private reproduction with the maintainer before sharing details.
Do not disclose an unpatched exploitable issue in a public issue or pull request.

Reports should include the revision/toolchain/platform, minimal synthetic input,
expected and actual behavior, resource impact and safe reproduction steps.
Maintainers will triage, reproduce, develop regression tests and coordinate a
patch/advisory. Publication timing and attribution should be agreed with the
reporter. This policy does not authorize testing other people's deployments.

## Trust boundaries

- Receiver bodies and HTTP peers are untrusted. Size, complexity, deadline and
  shared logical-resource limits apply before admission.
- Configurations, plugins, environment variables and output directories are
  trusted administrative inputs. Endpoints can reach private services: do not
  accept tenant-supplied configs. Endpoint syntax checking is not an SSRF sandbox.
- Non-loopback receivers require a Bearer token unless an administrator explicitly
  enables unauthenticated remote access. Plain HTTP exposes tokens and telemetry;
  terminate TLS at a trusted reverse proxy before remote deployment.
- Health is disabled by default outside loopback; remote health requires its own
  token. Source-IP allowlists use socket peers; forwarded headers are not trusted.
- Keep output directories private. Preflight rejects file/rotation collisions and
  existing symlink outputs, but cannot prevent a hostile local user replacing
  directories after validation. It is not a filesystem sandbox.
- Redaction must run before detailed debug/file/remote exporters. Masking selected
  keys does not guarantee arbitrary free-text bodies contain no secrets.
- Logical budgets are not RSS limits. Observe RSS and set deployment-level memory,
  CPU and disk limits. Memory queues are volatile and retries can duplicate data.

Supported protocol boundaries and operational safeguards are documented in
COMPATIBILITY.md and docs/OPERATIONS.md. Safety tests are regression evidence,
not an independent penetration test or certification.
