///|
test "unpacked histogram values normalize to packed equivalents" {
  let raw = @buffer.Buffer()
  @protobuf.write_uint32(raw, 49U)
  @protobuf.write_fixed64(raw, 7UL)
  @protobuf.write_uint32(raw, 49U)
  @protobuf.write_fixed64(raw, 9UL)
  let normalized = normalize_wire(raw.to_bytes(), "HistogramPoint", 0, [0])
  validate_message(normalized, 0, normalized.length(), "HistogramPoint", 0, [
    0, 0,
  ])
  let expected = @buffer.Buffer()
  @protobuf.write_uint32(expected, 50U)
  @protobuf.write_bytes(expected, b"\x07\x00\x00\x00\x00\x00\x00\x00")
  @protobuf.write_uint32(expected, 50U)
  @protobuf.write_bytes(expected, b"\x09\x00\x00\x00\x00\x00\x00\x00")
  assert_eq(normalized, expected.to_bytes())
}

///|
test "later empty singular protobuf IDs cannot bypass required span IDs" {
  for empty_tag in [10U, 18U] {
    let span = @buffer.Buffer()
    @protobuf.write_uint32(span, 10U)
    @protobuf.write_bytes(span, b"1111111111111111")
    @protobuf.write_uint32(span, 18U)
    @protobuf.write_bytes(span, b"22222222")
    @protobuf.write_uint32(span, empty_tag)
    @protobuf.write_bytes(span, b"")
    let mut body = span.to_bytes()
    for tag in [18U, 18U, 10U] {
      let parent = @buffer.Buffer()
      @protobuf.write_uint32(parent, tag)
      @protobuf.write_bytes(parent, body)
      body = parent.to_bytes()
    }
    assert_true(
      try {
        let _ = decode(Traces, body, json=false)
        false
      } catch {
        _ => true
      },
    )
  }
}
