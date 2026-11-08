///|
test "future enum numbers survive both encodings and transforms" {
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
