///|
fn gauge(value : Json) -> @data.Envelope raise {
  @data.from_json(Metrics, {
    "resourceMetrics": [
      {
        "scopeMetrics": [
          {
            "metrics": [
              {
                "name": "float-boundary",
                "gauge": { "dataPoints": [{ "asDouble": value }] },
              },
            ],
          },
        ],
      },
    ],
  })
}

///|
test "quoted repeated double bounds use the same numeric validation" {
  for (bound, valid) in [("1.5", true), ("1e9999", false)] {
    let input : Json = {
      "resourceMetrics": [
        {
          "scopeMetrics": [
            {
              "metrics": [
                {
                  "name": "quoted-bound",
                  "histogram": {
                    "dataPoints": [
                      {
                        "count": "2",
                        "bucketCounts": ["1", "1"],
                        "explicitBounds": [Json::string(bound)],
                      },
                    ],
                  },
                },
              ],
            },
          ],
        },
      ],
    }
    if valid {
      let value = @data.from_json(Metrics, input)
      assert_eq(
        @data.decode(Metrics, value.encode(json=false), json=false).to_json(),
        value.to_json(),
      )
    } else {
      assert_true(
        try {
          let _ = @data.from_json(Metrics, input)
          false
        } catch {
          _ => true
        },
      )
    }
  }
}

///|
test "quoted finite floating point input and special values survive metric protobuf output" {
  for
    (input, normalized) in [
      (Json::string("1.5"), Json::number(1.5)),
      (Json::string("1e2"), Json::number(100)),
      (Json::string("NaN"), Json::string("NaN")),
      (Json::string("Infinity"), Json::string("Infinity")),
      (Json::string("-Infinity"), Json::string("-Infinity")),
    ] {
    let value = gauge(input)
    assert_eq(value.to_json(), gauge(normalized).to_json())
    assert_eq(
      @data.decode(Metrics, value.encode(json=false), json=false).to_json(),
      value.to_json(),
    )
  }
}

///|
test "numeric overflow and malformed quoted floating point values are rejected" {
  for
    input in [
      Json::string("1e9999"),
      Json::string(" 1.5"),
      Json::string("1.5 "),
      Json::string(""),
      Json::string("nan"),
      Json::string("+1"),
      Json::string("null"),
      Json::string("01"),
      Json::string("true"),
      @json.parse("1e9999"),
    ] {
    assert_true(
      try {
        let _ = gauge(input)
        false
      } catch {
        _ => true
      },
    )
  }
}
