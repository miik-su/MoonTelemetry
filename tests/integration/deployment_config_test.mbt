///|
async test "container profile requires tokens and budgets all three signal workspaces" {
  let source = @fs.read_file("examples/deployment/collector.json").text()
  assert_true(try { let _ = @config.parse(source); false } catch { _ => true })
  let cfg = @config.parse(source, env=name => Some(if name == "MOONTELEMETRY_INGEST_TOKEN" { "synthetic-ingest" } else { "synthetic-health" }))
  assert_eq(cfg.pipelines.length(), 3)
  assert_eq(cfg.receivers["otlp"].host, "0.0.0.0")
  assert_true(cfg.receivers["otlp"].auth_token != cfg.receivers["otlp"].health_token)
  let _ = @service.Runtime::new(cfg)
}
