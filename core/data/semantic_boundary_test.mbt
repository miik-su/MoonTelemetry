///|
test "structural metric forwarding does not silently repair business semantics" {
  let input = @data.from_json(Metrics, {
    "resourceMetrics": [
      {
        "scopeMetrics": [
          {
            "metrics": [
              {
                "name": "inconsistent-but-structural",
                "histogram": {
                  "aggregationTemporality": 2,
                  "dataPoints": [
                    {
                      "count": "3",
                      "bucketCounts": ["2"],
                      "startTimeUnixNano": "100",
                      "timeUnixNano": "50",
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
  let text = input.to_json().stringify()
  assert_true(text.contains("\"count\":\"3\""))
  assert_true(text.contains("\"bucketCounts\":[\"2\"]"))
  assert_true(text.contains("\"timeUnixNano\":\"50\""))
  assert_eq(
    @data.decode(Metrics, input.encode(json=false), json=false).to_json(),
    input.to_json(),
  )
}
