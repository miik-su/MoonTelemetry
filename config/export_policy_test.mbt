///|
test "export deadlines and attempt timeout compatibility validate strictly" {
  let source = "{\"receivers\":{\"otlp\":{}},\"exporters\":{\"otlp\":{\"endpoint\":\"http://localhost:4318\",\"attempt_timeout_ms\":50,\"total_timeout_ms\":200,\"max_retry_delay_ms\":100}},\"service\":{\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"otlp\"]}}}}"
  let config = @config.parse(source)
  assert_eq(config.export_policies["otlp"].total_timeout_ms, 200)
  assert_true(config.exporters["otlp"] is Otlp(timeout_ms=50, ..))
  for
    invalid in [
      source.replace(
        old="\"attempt_timeout_ms\":50",
        new="\"attempt_timeout_ms\":50,\"timeout_ms\":50",
      ),
      source.replace(
        old="\"total_timeout_ms\":200",
        new="\"total_timeout_ms\":0",
      ),
    ] {
    assert_true(
      try {
        let _ = @config.parse(invalid)
        false
      } catch {
        _ => true
      },
    )
  }
}
