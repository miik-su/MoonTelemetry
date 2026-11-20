///|
priv struct RouteCapture {
  records : Array[@data.Envelope]
}

///|
impl @component.Exporter for RouteCapture with fn send(self, input) {
  self.records.push(input)
  0
}

///|
impl @component.Exporter for RouteCapture with fn close(_self) {
  ()
}

///|
async test "routing deduplicates overlapping rules and uses fallback after privacy and batching" {
  let reserve = @http.Server(@socket.Addr::new(2130706433U, 0))
  let port = reserve.addr.port()
  reserve.close()
  let audit = RouteCapture::{ records: [], }
  let errors = RouteCapture::{ records: [], }
  let fallback = RouteCapture::{ records: [], }
  let factories = @component.Factories::new()
  factories.register_exporter("audit", _ => audit)
  factories.register_exporter("errors", _ => errors)
  factories.register_exporter("fallback", _ => fallback)
  let source =
    $|{"receivers":{"otlp":{"port":\{port}}},
    $| "processors":{"redaction":{"keys":["secret"],"mode":"remove","body":true},
    $| "batch":{"size":2,"timeout_ms":100,"max_bytes":65536}},
    $| "exporters":{"audit":{},"errors":{},"fallback":{}},
    $| "service":{"pipelines":{"logs":{"receivers":["otlp"],"processors":["redaction","batch"],
    $| "exporters":["audit","errors","fallback"],"routing":{
    $| "rules":[
    $| {"exporter":"audit","condition":{"resource_attribute":"tier","operator":"exists"}},
    $| {"exporter":"audit","condition":{"field":"severityNumber","operator":"gte","value":17}},
    $| {"exporter":"errors","condition":{"field":"severityNumber","operator":"gte","value":17}},
    $| {"exporter":"errors","condition":{"attribute":"secret","operator":"exists"}}],
    $| "default_exporters":["fallback"]}}}}}
  let config = @config.parse(source, factories~)
  let runtime = @service.Runtime::new(config)
  let payload =
    #|{"resourceLogs":[
    #| {"resource":{"attributes":[{"key":"tier","value":{"stringValue":"prod"}}]},
    #| "scopeLogs":[{"logRecords":[{"severityNumber":17,"body":{"stringValue":"private-body"}}]}]},
    #| {"scopeLogs":[{"logRecords":[{"severityNumber":9,"attributes":[{"key":"secret","value":{"stringValue":"private-key"}}]}]}]}]}
  let input = @data.from_json(Logs, @json.parse(payload))
  @async.with_task_group(group => {
    let collector = group.spawn(async fn() { runtime.run() })
    defer collector.cancel()
    @async.with_timeout(3000, async fn() {
      while !runtime.health().stringify().contains("\"status\":\"ready\"") {
        @async.sleep(5)
      }
    })
    assert_eq(runtime.submit("otlp", input), 0)
    @async.with_timeout(3000, async fn() {
      while audit.records.is_empty() ||
            errors.records.is_empty() ||
            fallback.records.is_empty() {
        @async.sleep(5)
      }
    })
    collector.cancel()
    collector.wait()
  })
  for output in [audit, errors, fallback] {
    assert_eq(output.records.length(), 1)
    assert_eq(output.records[0].count(), 1)
    let json = output.records[0].to_json().stringify()
    assert_false(json.contains("private-body") || json.contains("private-key"))
  }
  assert_true(audit.records[0].to_json().stringify().contains("prod"))
  assert_true(errors.records[0].to_json().stringify().contains("[REDACTED]"))
  assert_false(fallback.records[0].to_json().stringify().contains("prod"))
  guard runtime.health() is Object(health) &&
    health.get("pipelines") is Some(Array(pipelines)) &&
    pipelines[0] is Object(pipeline) &&
    pipeline.get("outputs") is Some(Array(outputs)) else {
    abort("health shape")
  }
  assert_eq(pipeline.get("routingFailedOutputs"), Some(Json::string("0")))
  assert_eq(pipeline.get("processedRecords"), Some(Json::string("2")))
  for output in outputs {
    guard output is Object(stats) else { abort("queue stats") }
    assert_eq(stats.get("accepted"), Some(Json::string("1")))
    assert_eq(stats.get("delivered"), Some(Json::string("1")))
  }
  assert_eq(health.get("logicalMemoryUsed"), Some(Json::string("0")))
}
