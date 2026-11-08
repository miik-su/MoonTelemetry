///|
test "three signals preserve protobuf and JSON round trips" {
  for name in ["logs", "metrics", "traces"] {
    let signal = @data.signal_from_name(name).unwrap()
    let e = @data.from_json(signal, {})
    assert_eq(e.count(), 0)
    let binary = e.encode(json=false)
    assert_eq(@data.decode(signal, binary, json=false).count(), 0)
    assert_eq(
      @data.decode(signal, e.encode(json=true), json=true).signal(),
      signal,
    )
  }
}

///|
test "OTLP hex IDs and nanosecond strings survive codec" {
  let input : Json = {
    "resourceSpans": [
      {
        "scopeSpans": [
          {
            "spans": [
              {
                "traceId": "0102030405060708090a0b0c0d0e0f10",
                "spanId": "0102030405060708",
                "name": "request",
                "startTimeUnixNano": "18446744073709551614",
                "endTimeUnixNano": "18446744073709551615",
              },
            ],
          },
        ],
      },
    ],
  }
  let e = @data.from_json(Traces, input)
  assert_eq(e.count(), 1)
  let decoded = @data.decode(Traces, e.encode(json=false), json=false)
  assert_eq(decoded.to_json(), e.to_json())
}

///|
test "invalid IDs and malformed protobuf fail without panic" {
  let result = try {
    let _ = @data.from_json(Traces, {
      "resourceSpans": [{ "scopeSpans": [{ "spans": [{ "traceId": "bad" }] }] }],
    })
    false
  } catch {
    _ => true
  }
  assert_true(result)
  let result = try {
    let _ = @data.decode(Logs, b"\x0a\xff", json=false)
    false
  } catch {
    _ => true
  }
  assert_true(result)
}
