///|
test "AnyValue preserves typed oneofs instead of guessing from strings" {
  let values : Array[Json] = [
    { "intValue": "9223372036854775807" },
    { "bytesValue": "AQID" },
    {
      "arrayValue": { "values": [{ "intValue": "42" }, { "boolValue": true }] },
    },
    {
      "kvlistValue": {
        "values": [{ "key": "k", "value": { "stringValue": "v" } }],
      },
    },
  ]
  for value in values {
    let input : Json = {
      "resourceLogs": [{ "scopeLogs": [{ "logRecords": [{ "body": value }] }] }],
    }
    let e = @data.from_json(Logs, input)
    let canonical = e.to_json()
    assert_true(
      canonical.stringify().contains(value.stringify()),
      msg=value.stringify() + " -> " + canonical.stringify(),
    )
    assert_eq(
      @data.decode(Logs, e.encode(json=true), json=true).to_json(),
      canonical,
    )
  }
}

///|
test "metric oneofs preserve Sum Histogram ExponentialHistogram Summary and integers" {
  let variants : Array[Json] = [
    { "gauge": { "dataPoints": [{ "asInt": "42" }] } },
    {
      "sum": {
        "dataPoints": [{ "asInt": "42" }],
        "aggregationTemporality": 2,
        "isMonotonic": true,
      },
    },
    {
      "histogram": {
        "dataPoints": [
          { "count": "2", "bucketCounts": ["1", "1"], "explicitBounds": [1] },
        ],
      },
    },
    {
      "exponentialHistogram": {
        "dataPoints": [
          { "count": "2", "positive": { "offset": -1, "bucketCounts": ["2"] } },
        ],
      },
    },
    {
      "summary": {
        "dataPoints": [
          { "count": "2", "quantileValues": [{ "quantile": 0.5, "value": 3 }] },
        ],
      },
    },
  ]
  for data in variants {
    let e = @data.from_json(Metrics, {
      "resourceMetrics": [{ "scopeMetrics": [{ "metrics": [data] }] }],
    })
    assert_eq(e.count(), 1)
    assert_eq(
      @data.decode(Metrics, e.encode(json=true), json=true).to_json(),
      e.to_json(),
    )
    if data is Object(m) {
      for key, _ in m {
        assert_true(e.to_json().stringify().contains("\"" + key + "\""))
      }
    }
  }
}

///|
test "unknown JSON fields ignored and nested wire truncation rejected" {
  assert_eq(
    @data.from_json(Logs, { "futureField": { "anything": true } }).count(),
    0,
  )
  assert_true(
    try {
      let _ = @data.decode(Logs, b"\x0a\x02\x0a\xff", json=false)
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      let _ = @data.from_json(Logs, {
        "resourceLogs": [
          {
            "scopeLogs": [
              {
                "logRecords": [
                  { "body": { "intValue": "1", "stringValue": "a" } },
                ],
              },
            ],
          },
        ],
      })
      false
    } catch {
      _ => true
    },
  )
}
