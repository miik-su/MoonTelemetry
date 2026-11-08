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
