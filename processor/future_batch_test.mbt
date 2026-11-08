///|
test "batch preserves future enums in mixed input" {
  let batch = @processor.Batch::new(
    Logs,
    size=2,
    timeout_ms=1000,
    max_bytes=8192,
  )
  for severity in [9, 99] {
    let input = @data.from_json(Logs, {
      "resourceLogs": [
        {
          "scopeLogs": [
            {
              "logRecords": [
                { "severityNumber": Json::number(severity.to_double()) },
              ],
            },
          ],
        },
      ],
    })
    let output = batch.push(input, now=0L)
    if severity == 99 {
      assert_eq(output[0].count(), 2)
      assert_true(output[0].to_json().stringify().contains("99"))
    }
  }
}
