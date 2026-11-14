///|
fn main raise {
  let envelope = @data.from_json(Logs, {
    "resourceLogs": [
      {
        "scopeLogs": [
          {
            "logRecords": [
              { "body": { "stringValue": "synthetic library example" } },
            ],
          },
        ],
      },
    ],
  })
  let wire = envelope.encode(json=false)
  let decoded = @data.decode(Logs, wire, json=false)
  assert_eq(decoded.to_json(), envelope.to_json())
  println("Verified \{decoded.count()} log record via OTLP protobuf roundtrip")
}
