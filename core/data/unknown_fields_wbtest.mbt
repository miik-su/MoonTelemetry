///|
fn has_bytes(haystack : Bytes, needle : Bytes) -> Bool {
  for start in 0..<(haystack.length() - needle.length() + 1).max(0) {
    let mut equal = true
    for i in 0..<needle.length() {
      if haystack[start + i] != needle[i] {
        equal = false
        break
      }
    }
    if equal {
      return true
    }
  }
  false
}

///|
fn tagged_message(tag : UInt32, payload : Bytes) -> Bytes raise {
  let out = @buffer.Buffer()
  @protobuf.write_uint32(out, tag)
  @protobuf.write_bytes(out, payload)
  out.to_bytes()
}

///|
test "ordinary protobuf relay loses unknown root and nested fields without processors" {
  let nested_marker = b"NOV13_UNKNOWN_LOG_FIELD"
  let root_marker = b"NOV13_UNKNOWN_ROOT_FIELD"
  let record = @buffer.Buffer()
  record.write_bytes(tagged_message(42U, tagged_message(10U, b"known body")))
  record.write_bytes(tagged_message(1018U, nested_marker))
  let payload = @buffer.Buffer()
  payload.write_bytes(
    tagged_message(
      10U,
      tagged_message(18U, tagged_message(18U, record.to_bytes())),
    ),
  )
  payload.write_bytes(tagged_message(1018U, root_marker))
  let input = payload.to_bytes()
  assert_true(has_bytes(input, nested_marker))
  assert_true(has_bytes(input, root_marker))
  let envelope = decode(Logs, input, json=false)
  assert_eq(envelope.count(), 1)
  let output = envelope.encode(json=false)
  assert_false(has_bytes(output, nested_marker))
  assert_false(has_bytes(output, root_marker))
  assert_eq(decode(Logs, output, json=false).to_json(), envelope.to_json())
  assert_true(envelope.to_json().stringify().contains("known body"))
}
