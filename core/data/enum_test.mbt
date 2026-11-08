///|
test "future enum numbers survive both encodings and transforms" {
  let negative = @data.from_json(Logs, {
    "resourceLogs": [
      { "scopeLogs": [{ "logRecords": [{ "severityNumber": -1 }] }] },
    ],
  })
  assert_true(negative.to_json().stringify().contains("\"severityNumber\":-1"))
  let e = @data.from_json(Logs, {
    "resourceLogs": [
      {
        "scopeLogs": [
          {
            "logRecords": [
              { "severityNumber": 99, "body": { "intValue": "42" } },
            ],
          },
        ],
      },
    ],
  })
  assert_eq(e.count(), 1)
  assert_true(e.to_json().stringify().contains("\"severityNumber\":99"))
  for json in [true, false] {
    let roundtrip = @data.decode(Logs, e.encode(json~), json~)
    assert_eq(roundtrip.to_json(), e.to_json())
  }
}

///|
test "future enum fallback honors last protobuf oneof member" {
  let e = @data.decode(
    Logs,
    b"\x0a\x0d\x12\x0b\x12\x09\x10\x63\x2a\x05\x0a\x01a\x10\x01",
    json=false,
  )
  let canonical = e.to_json().stringify()
  assert_true(canonical.contains("\"boolValue\":true"))
  assert_false(canonical.contains("stringValue"))
  let roundtrip = @data.decode(Logs, e.encode(json=true), json=true)
  assert_eq(roundtrip.to_json(), e.to_json())
}
