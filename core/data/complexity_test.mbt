///|
test "attribute and record count limits reject before model construction" {
  let attrs : Array[Json] = Array::make(257, {
    "key": "k",
    "value": { "stringValue": "v" },
  })
  assert_true(
    try {
      let _ = @data.from_json(Logs, {
        "resourceLogs": [{ "resource": { "attributes": Json::array(attrs) } }],
      })
      false
    } catch {
      _ => true
    },
  )
  let records : Array[Json] = Array::make(100001, {})
  assert_true(
    try {
      let _ = @data.from_json(Logs, {
        "resourceLogs": [
          { "scopeLogs": [{ "logRecords": Json::array(records) }] },
        ],
      })
      false
    } catch {
      _ => true
    },
  )
}
