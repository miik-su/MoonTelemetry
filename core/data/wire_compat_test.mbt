///|
test "zero correlation IDs and missing span IDs are rejected" {
  for
    body in [
      "{\"resourceSpans\":[{\"scopeSpans\":[{\"spans\":[{}]}]}]}", "{\"resourceLogs\":[{\"scopeLogs\":[{\"logRecords\":[{\"traceId\":\"00000000000000000000000000000000\"}]}]}]}",
    ] {
    assert_true(
      try {
        let _ = @data.decode(
          if body.contains("resourceSpans") {
            Traces
          } else {
            Logs
          },
          @utf8.encode(body),
          json=true,
        )
        false
      } catch {
        _ => true
      },
    )
  }
}
