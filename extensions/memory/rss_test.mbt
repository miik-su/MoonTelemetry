///|
test "RSS observations are positive when available" {
  if @memory.rss_bytes() is Some(bytes) {
    assert_true(bytes > 0L)
  }
}
