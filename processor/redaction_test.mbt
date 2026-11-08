///|
test "redaction covers resource scope log body and nested AnyValue" {
  let input = @data.from_json(Logs, {
    "resourceLogs": [
      {
        "resource": {
          "attributes": [
            { "key": "Password", "value": { "stringValue": "secret-value" } },
          ],
        },
        "scopeLogs": [
          {
            "scope": {
              "attributes": [
                { "key": "token", "value": { "intValue": "12345" } },
              ],
            },
            "logRecords": [{ "body": { "stringValue": "private body" } }],
          },
        ],
      },
    ],
  })
  let result = @processor.Transform::Redact(["password", "token"], body=true)
    .process(input)
    .to_json()
    .stringify()
  assert_false(result.contains("secret-value"))
  assert_false(result.contains("12345"))
  assert_false(result.contains("private body"))
  assert_true(input.to_json().stringify().contains("secret-value"))
}

///|
test "redaction allowlist and removal apply to nested attributes" {
  let input = @data.from_json(Logs, {
    "resourceLogs": [
      {
        "scopeLogs": [
          {
            "logRecords": [
              {
                "attributes": [
                  { "key": "ok", "value": { "stringValue": "retained" } },
                  { "key": "password", "value": { "stringValue": "secret" } },
                  { "key": "extra", "value": { "boolValue": true } },
                ],
              },
            ],
          },
        ],
      },
    ],
  })
  let result = @processor.Transform::Redaction(
      keys=["password"],
      allowlist=Some(["ok", "password"]),
      remove=true,
      body=false,
    )
    .process(input)
    .to_json()
    .stringify()
  assert_true(result.contains("retained"))
  assert_false(result.contains("password"))
  assert_false(result.contains("extra"))
}
