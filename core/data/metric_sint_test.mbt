///|
test "metric protobuf nested lengths remain correct across zigzag boundaries" {
  for value in [-2147483648, -65, -64, -1, 0, 63, 64, 127, 2147483647] {
    let input = @data.from_json(Metrics, {
      "resourceMetrics": [
        {
          "scopeMetrics": [
            {
              "metrics": [
                {
                  "name": "zigzag",
                  "exponentialHistogram": {
                    "aggregationTemporality": 2,
                    "dataPoints": [
                      {
                        "count": "1",
                        "scale": Json::number(value.to_double()),
                        "positive": {
                          "offset": Json::number(value.to_double()),
                          "bucketCounts": ["1"],
                        },
                      },
                    ],
                  },
                },
              ],
            },
          ],
        },
      ],
    })
    let encoded = input.encode(json=false)
    assert_eq(
      @data.decode(Metrics, encoded, json=false).to_json(),
      input.to_json(),
    )
    assert_true(input.wire_size() >= encoded.length().to_int64())
  }
}
