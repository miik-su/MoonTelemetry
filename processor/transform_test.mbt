///|
test "ordered transforms are isolated and resource is created" {
  let input = @data.from_json(Logs, {
    "resourceLogs": [
      {
        "scopeLogs": [
          { "logRecords": [{ "body": { "stringValue": "hello" } }] },
        ],
      },
    ],
  })
  let add = @processor.Transform::Attributes([
    Upsert("private", { "stringValue": "secret" }),
  ])
  let drop = @processor.Transform::DropAttribute("private", {
    "stringValue": "secret",
  })
  assert_eq(drop.process(add.process(input)).count(), 0)
  assert_eq(input.count(), 1)
  assert_eq(drop.process(input).count(), 1)
  let enriched = @processor.Transform::Resource([
    Upsert("service.name", { "stringValue": "demo" }),
  ]).process(input)
  assert_true(enriched.to_json().stringify().contains("service.name"))
  assert_false(input.to_json().stringify().contains("service.name"))
}
