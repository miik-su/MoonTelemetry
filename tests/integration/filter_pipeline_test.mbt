///|
priv struct FilterCapture {
  outputs : Array[Json]
}

///|
impl @component.Exporter for FilterCapture with fn send(self, input) {
  self.outputs.push(input.to_json())
  0
}

///|
impl @component.Exporter for FilterCapture with fn close(_self) {
  ()
}

///|
async test "predicate filtering preserves privacy order and per-stage accounting" {
  let reserve = @http.Server(@socket.Addr::new(2130706433U, 0))
  let port = reserve.addr.port()
  reserve.close()
  let capture = FilterCapture::{ outputs: [], }
  let factories = @component.Factories::new()
  factories.register_exporter("capture", _ => capture, api_version=1)
  let cfg = @config.parse(
    (
      {
        "receivers": { "otlp": { "port": Json::number(port.to_double()) } },
        "processors": {
          "redaction": { "keys": ["secret"], "mode": "remove", "body": true },
          "filter": {
            "all": [
              {
                "resource_attribute": "service.name",
                "operator": "prefix",
                "value": "prod-",
              },
              { "field": "severityNumber", "operator": "gte", "value": 13 },
            ],
          },
        },
        "exporters": { "capture": {} },
        "service": {
          "pipelines": {
            "logs": {
              "receivers": ["otlp"],
              "processors": ["redaction", "filter"],
              "exporters": ["capture"],
            },
          },
        },
      } : Json).stringify(),
    factories~,
  )
  let runtime = @service.Runtime::new(cfg)
  let input = @data.from_json(Logs, {
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
                "body": { "stringValue": "private-body" },
              },
              {
                "severityNumber": 9,
                "body": { "stringValue": "private-body" },
                "attributes": [
                  {
                    "key": "secret",
                    "value": { "stringValue": "private-value" },
                  },
                ],
              },
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
                "severityNumber": 17,
                "body": { "stringValue": "private-body" },
              },
            ],
          },
        ],
      },
    ],
  })
  @async.with_task_group(async fn(group) {
    let collector = group.spawn(async fn() { runtime.run() })
    defer collector.cancel()
    @async.with_timeout(2000, async fn() {
      while !runtime.health().stringify().contains("\"status\":\"ready\"") {
        @async.sleep(5)
      }
    })
    assert_eq(runtime.submit("otlp", input), 0)
    @async.with_timeout(2000, async fn() {
      while capture.outputs.is_empty() {
        @async.sleep(5)
      }
    })
    collector.cancel()
    collector.wait()
  })
  assert_eq(capture.outputs.length(), 1)
  assert_eq(@data.from_json(Logs, capture.outputs[0]).count(), 2)
  let text = capture.outputs[0].stringify()
  assert_false(text.contains("private-body") || text.contains("private-value"))
  assert_true(text.contains("[REDACTED]"))
  guard runtime.health() is Object(health) &&
    health.get("pipelines") is Some(Array(pipes)) &&
    pipes[0] is Object(pipeline) else {
    abort("health shape")
  }
  assert_eq(pipeline.get("filtered"), Some(Json::string("1")))
  assert_eq(pipeline.get("processedRecords"), Some(Json::string("2")))
  assert_eq(health.get("logicalMemoryUsed"), Some(Json::string("0")))
  assert_eq(health.get("requestMemoryUsed"), Some(Json::string("0")))
  assert_eq(
    health.get("logicalMemoryAvailable"),
    health.get("logicalMemoryLimit"),
  )
  assert_eq(
    health.get("requestMemoryAvailable"),
    health.get("requestMemoryLimit"),
  )
}
