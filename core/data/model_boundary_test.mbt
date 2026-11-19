///|
test "nested AnyValue preserves types while configured depth rejects both encodings" {
  let mut value : Json = {
    "kvlistValue": {
      "values": [
        { "key": "integer", "value": { "intValue": "-9223372036854775808" } },
        { "key": "bytes", "value": { "bytesValue": "AP8=" } },
        { "key": "nonfinite", "value": { "doubleValue": "NaN" } },
      ],
    },
  }
  for _ in 0..<5 {
    value = { "arrayValue": { "values": [value] } }
  }
  let input = @data.from_json(Logs, {
    "resourceLogs": [{ "scopeLogs": [{ "logRecords": [{ "body": value }] }] }],
  })
  let limits : @data.Limits = {
    max_records_per_request: 100000,
    max_attributes_per_record: 256,
    max_total_fields_per_request: 1000000,
    max_nesting_depth: 4,
  }
  for json in [true, false] {
    let bytes = input.encode(json~)
    assert_eq(@data.decode(Logs, bytes, json~).to_json(), input.to_json())
    assert_true(
      try {
        let _ = @data.decode(Logs, bytes, json~, limits~)
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "traceState parent child links and scope metadata preserve exact modeled content" {
  let input = @data.from_json(Traces, {
    "resourceSpans": [
      {
        "scopeSpans": [
          {
            "scope": { "name": "synthetic", "version": "1" },
            "schemaUrl": "https://example.invalid/schema",
            "spans": [
              {
                "traceId": "11111111111111111111111111111111",
                "spanId": "2222222222222222",
                "traceState": "vendor=synthetic",
                "name": "parent",
              },
              {
                "traceId": "11111111111111111111111111111111",
                "spanId": "3333333333333333",
                "parentSpanId": "2222222222222222",
                "traceState": "vendor=synthetic,other=value",
                "name": "child",
                "links": [
                  {
                    "traceId": "44444444444444444444444444444444",
                    "spanId": "5555555555555555",
                    "traceState": "linked=synthetic",
                  },
                ],
                "events": [
                  {
                    "timeUnixNano": "18446744073709551615",
                    "name": "synthetic-event",
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
  })
  for json in [true, false] {
    let roundtrip = @data.decode(Traces, input.encode(json~), json~)
    assert_eq(roundtrip.count(), 2)
    assert_eq(roundtrip.to_json(), input.to_json())
  }
}
