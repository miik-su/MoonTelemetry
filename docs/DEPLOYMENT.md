# Deployment trust boundaries

The templates have a [Linux CI smoke check](https://github.com/miik-su/MoonTelemetry/actions/runs/45182228428).
It builds a local test image and checks Compose, a trusted synthetic TLS
certificate, method/body limits, authentication, redacted delivery and shutdown
flush. It extends the template's batch timeout to hold one synthetic record until
stop. The evidence uses a GitHub runner, separate from target host qualification.
Run
`nginx -t` and `docker compose config` with your real paths/environment before
using them, then test authentication, body limits and graceful stop on that host.

| Scenario | Starting point | Required boundary |
| --- | --- | --- |
| Local development | examples/collector.json | Loopback, synthetic data, control detailed debug output |
| Private service | examples/strict-security.json and TLS proxy | Separate ingress/health tokens, controlled reachability and trusted TLS termination |
| Container | examples/deployment/collector.json + compose.yaml | Verified digest, non-root user, read-only root filesystem, bounded resources and private data mount |

The container config listens on 0.0.0.0 inside its network namespace; Compose
publishes only host loopback. It masks log bodies and removes non-allowlisted
attributes before batching all three signals. Set two distinct tokens through
your trusted deployment environment; keep them out of tracked `.env` files,
shell transcripts, proxy logs and screenshots. The parser requires nonempty
tokens but does not guarantee the administrator chose distinct values.

Build your own Native executable from a reviewed source revision and fixed
toolchain. `MOONTELEMETRY_IMAGE` must identify an image containing that binary at
`/usr/local/bin/moontelemetry`, its runtime/system dependencies and applicable
licenses/notices. Prefer a digest-pinned image. No official project image or
automatic image build is implied by the template. Prepare `examples/deployment/data`
with ownership/permissions allowing UID/GID 65532 to write, while keeping other
users out. The configuration's file path is for Linux containers.

The Nginx example exposes only the three POST ingestion paths on TLS port 8443;
other paths, including health, return 404. Replace the invalid example hostname
and certificate paths. It forwards the client's Bearer header and does not
automatically replay failed requests. Proxy buffering can use temporary disk
files: configure private temp directories, disk limits and cleanup on the proxy.
Proxy limits do not replace Collector limits or constrain decompressed bytes.

Keep direct 4318 access restricted. Socket-peer allowlists see the proxy/bridge
address, not the original client; forwarded headers are not an authentication
or source-IP authority. Configure client-network controls on the trusted proxy.
Use a separate, restricted path to probe `/health/ready` with the health token;
reserve connection headroom because health shares the ingestion listener.

Logical budgets are not a process RSS ceiling. The example's 128 MiB logical
budget and 256 MiB container limit are starting values, not a sizing guarantee.
Observe RSS and overload counters, and tune for your record sizes. An OOM kill
or crash loses volatile queues; storage retention is not a filesystem quota.
The 15-second container stop allowance should exceed the configured five-second
drain deadline, but still verify supervisor behavior on the deployment host.

Directive references: [Nginx proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html),
[Nginx TLS](https://nginx.org/en/docs/http/ngx_http_ssl_module.html),
[Compose services](https://docs.docker.com/reference/compose-file/services/).
See [security](../SECURITY.md) and [operations](OPERATIONS.md) for retained limits.
