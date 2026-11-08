///|
test "response decoding rejects truncated nested protobuf and accepts future JSON fields" {
  assert_true(
    try {
      let _ = @data.rejected(Logs, b"\x0a\x01\x08", json=false)
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    @data.rejected(
      Logs,
      b"{\"partialSuccess\":{\"rejectedLogRecords\":2,\"future\":true},\"future\":[]}",
      json=true,
    ),
    2L,
  )
}
