///|
test "batch threshold timeout and shutdown flush" {
  let b = @processor.Batch::new(Logs, size=2, timeout_ms=100, max_bytes=4096)
  let e = @data.from_json(Logs, {
    "resourceLogs": [
      { "scopeLogs": [{ "logRecords": [{ "body": { "stringValue": "a" } }] }] },
    ],
  })
  assert_eq(b.push(e, now=0).length(), 0)
  assert_true(b.tick(now=99) is None)
  assert_eq(b.push(e, now=99)[0].count(), 2)
  assert_eq(b.push(e, now=200).length(), 0)
  assert_eq(b.tick(now=300).unwrap().count(), 1)
  assert_true(b.flush() is None)
  assert_true(
    try {
      @processor.admit(e, 1)
      false
    } catch {
      _ => true
    },
  )
}
