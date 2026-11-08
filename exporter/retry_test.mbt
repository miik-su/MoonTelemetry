///|
test "OTLP retries only retryable statuses and delay is capped" {
  assert_eq(@exporter.retry_after("2"), 2000)
  assert_eq(@exporter.retry_after("999999999999999999999999999"), 3600000)
  assert_eq(@exporter.retry_after("bad"), 0)
  for code in [429, 502, 503, 504] {
    assert_true(@exporter.retryable(code))
  }
  for code in [200, 400, 401, 404, 500, 501] {
    assert_false(@exporter.retryable(code))
  }
  assert_eq(@exporter.retry_delay(100), 6400)
}

///|
test "partial success decodes equally for all signal encodings" {
  for name in ["logs", "metrics", "traces"] {
    let s = @data.signal_from_name(name).unwrap()
    for json in [true, false] {
      assert_eq(
        @data.rejected(
          s,
          @data.response(s, rejected=7, message="rejected", json~),
          json~,
        ),
        7L,
      )
    }
  }
}
