///|
fn filter_input() -> @data.Envelope raise {
  @data.from_json(Logs, {
    "resourceLogs": [
      {
        "resource": {
          "attributes": [
            { "key": "service.name", "value": { "stringValue": "prod-api" } },
          ],
        },
        "scopeLogs": [
          {
            "logRecords": [
              {
                "severityNumber": 17,
                "body": { "stringValue": "drop-prod" },
                "attributes": [
                  { "key": "secret", "value": { "stringValue": "synthetic" } },
                ],
              },
              { "severityNumber": 9, "body": { "stringValue": "keep-prod" } },
            ],
          },
        ],
      },
      {
        "resource": {
          "attributes": [
            { "key": "service.name", "value": { "stringValue": "dev-api" } },
          ],
        },
        "scopeLogs": [
          {
            "logRecords": [
              {
                "severityNumber": 1,
                "body": { "stringValue": "keep-dev" },
                "attributes": [
                  { "key": "attempt", "value": { "intValue": "7" } },
                ],
              },
            ],
          },
        ],
      },
    ],
  })
}

///|
test "bounded all filter inherits only its own resource and never mutates input" {
  let input = filter_input()
  let rule = @processor.Filter::parse({
    "all": [
      {
        "resource_attribute": "service.name",
        "operator": "prefix",
        "value": "prod-",
      },
      { "attribute": "secret", "operator": "exists" },
    ],
  })
  let result = rule.process(input)
  assert_eq(result.count(), 2)
  assert_eq(input.count(), 3)
  assert_false(result.to_json().stringify().contains("drop-prod"))
  assert_true(result.to_json().stringify().contains("keep-dev"))
}

///|
test "any not severity and canonical numeric AnyValue predicates" {
  let input = filter_input()
  let rule = @processor.Filter::parse({
    "any": [
      { "field": "severityNumber", "operator": "gte", "value": 13 },
      {
        "attribute": "attempt",
        "operator": "equals",
        "value": { "intValue": 7 },
      },
    ],
  })
  assert_eq(rule.process(input).count(), 1)
  let keep_secret = @processor.Filter::parse({
    "not": { "attribute": "secret", "operator": "exists" },
  })
  assert_eq(keep_secret.process(input).count(), 1)
  assert_eq(
    @processor.Filter::parse({
      "field": "severityNumber",
      "operator": "lte",
      "value": 1,
    })
    .process(input)
    .count(),
    2,
  )
}

///|
test "resource predicates apply to five metric branches and valid spans" {
  let metrics = @data.from_json(Metrics, {
    "resourceMetrics": [
      {
        "resource": {
          "attributes": [{ "key": "env", "value": { "stringValue": "test" } }],
        },
        "scopeMetrics": [
          {
            "metrics": [
              { "name": "g", "gauge": { "dataPoints": [{ "asInt": "1" }] } },
              { "name": "s", "sum": { "dataPoints": [{ "asDouble": 1 }] } },
              { "name": "h", "histogram": { "dataPoints": [{ "count": "0" }] } },
              {
                "name": "e",
                "exponentialHistogram": { "dataPoints": [{ "count": "0" }] },
              },
              { "name": "q", "summary": { "dataPoints": [{ "count": "0" }] } },
            ],
          },
        ],
      },
    ],
  })
  let traces = @data.from_json(Traces, {
    "resourceSpans": [
      {
        "resource": {
          "attributes": [{ "key": "env", "value": { "stringValue": "test" } }],
        },
        "scopeSpans": [
          {
            "spans": [
              {
                "traceId": "11111111111111111111111111111111",
                "spanId": "2222222222222222",
              },
            ],
          },
        ],
      },
    ],
  })
  let rule = @processor.Filter::parse({
    "resource_attribute": "env",
    "operator": "equals",
    "value": { "stringValue": "test" },
  })
  assert_eq(metrics.count(), 5)
  assert_eq(rule.process(metrics).count(), 0)
  assert_eq(rule.process(traces).count(), 0)
  for input in [metrics, traces] {
    let signal = input.signal()
    let json = input.to_json()
    assert_eq(@processor.select_records(signal, json, [rule]).to_json(), json)
    assert_eq(
      @processor.select_records(signal, json, [], fallback_unless=[rule]).to_json(),
      @data.from_json(signal, {}).to_json(),
    )
  }
}

///|
test "metric routing keeps only requested points and nonempty metric groups" {
  let point : Json = {
    "asInt": "1",
    "attributes": [{ "key": "route", "value": { "boolValue": true } }],
  }
  let data = @data.from_json(Metrics, {
    "resourceMetrics": [
      {
        "scopeMetrics": [
          {
            "metrics": [
              {
                "name": "mixed",
                "gauge": { "dataPoints": [point, { "asInt": "2" }] },
              },
              {
                "name": "unmatched",
                "gauge": { "dataPoints": [{ "asInt": "3" }] },
              },
            ],
          },
        ],
      },
    ],
  })
  let rule = @processor.Filter::parse({
    "attribute": "route",
    "operator": "exists",
  })
  let output = @processor.select_records(Metrics, data.to_json(), [rule])
  assert_eq(output.count(), 1)
  assert_false(output.to_json().stringify().contains("unmatched"))
  assert_eq(
    @data.decode(Metrics, output.encode(json=false), json=false).to_json(),
    output.to_json(),
  )
}

///|
test "invalid filter shapes and expression complexity reject before runtime" {
  for
    invalid in [
      ({ "all": [] } : Json),
      { "any": [] },
      { "not": {}, "attribute": "x" },
      { "attribute": "x", "operator": "exists", "value": true },
      { "attribute": "x", "resource_attribute": "y", "operator": "exists" },
      { "field": "body", "operator": "gte", "value": 1 },
      { "field": "severityNumber", "operator": "gte", "value": 25 },
      { "attribute": "x", "operator": "regex", "value": "*" },
      { "attribute": "x", "operator": "equals", "value": { "unexpected": 1 } },
      { "attribute": "x", "operator": "prefix", "value": "" },
      { "attribute": "x", "operator": "exists", "typo": true },
    ] {
    assert_true(
      try {
        let _ = @processor.Filter::parse(invalid)
        false
      } catch {
        _ => true
      },
    )
  }
  let leaf : Json = { "attribute": "x", "operator": "exists" }
  let mut deep = leaf
  for _ in 0..<8 {
    deep = { "not": deep }
  }
  assert_true(
    try {
      let _ = @processor.Filter::parse(deep)
      false
    } catch {
      _ => true
    },
  )
  let wide : Json = { "all": Json::array(Array::make(16, leaf)) }
  assert_true(
    try {
      let _ = @processor.Filter::parse({ "any": [wide, wide, wide, wide] })
      false
    } catch {
      _ => true
    },
  )
}
