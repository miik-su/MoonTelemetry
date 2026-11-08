///|
test "endpoint parser validates authority and preserves base path" {
  let e = @config.endpoint("https://example.org:443/otlp/")
  assert_eq(e.origin, "https://example.org:443")
  assert_eq(e.base_path, "/otlp")
  let _ = @config.endpoint("http://[::1]:4318")
  for
    value in [
      "http://", "http://host:", "http://host:0", "http://host:65536", "http://user@host",
      "http://host/a?b", "http://999.1.1.1", "http://bad host", "http://host/../secret",
      "file:///tmp",
    ] {
    assert_true(
      try {
        let _ = @config.endpoint(value)
        false
      } catch {
        _ => true
      },
      msg=value,
    )
  }
}
