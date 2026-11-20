///|
fn metric_by_name(payload : Json, name : String) -> Json {
  guard payload is Object(root) &&
    root.get("resourceMetrics") is Some(Array([Object(resource)])) &&
    resource.get("scopeMetrics") is Some(Array([Object(scope)])) &&
    scope.get("metrics") is Some(Array(metrics)) else {
    abort("metric envelope shape")
  }
  for metric in metrics {
    if metric is Object(fields) &&
      fields.get("name") == Some(Json::string("moontelemetry." + name)) {
      return metric
    }
  }
  abort("missing metric: " + name)
}

///|
async test "self metrics send typed cumulative counters and gauges over both OTLP encodings" {
  for json in [true, false] {
    let sink = @http.Server(@socket.Addr::new(2130706433U, 0))
    defer sink.close()
    let reserve = @http.Server(@socket.Addr::new(2130706433U, 0))
    let port = reserve.addr.port()
    reserve.close()
    let sink_port = sink.addr.port()
    let encoding = if json {
      "application/json"
    } else {
      "application/x-protobuf"
    }
    let source =
      $|{"receivers":{"otlp":{"port":\{port}}},"processors":{},
      $| "exporters":{"debug":{},"otlp/self":{"endpoint":"http://127.0.0.1:\{sink_port}/test","json":\{json},"retries":0}},
      $| "service":{"pipelines":{"logs":{"receivers":["otlp"],"processors":[],"exporters":["debug"]}},
      $| "self_metrics":{"exporter":"otlp/self","instance_id":"test-collector","interval_ms":1000}}}
    let runtime = @service.Runtime::new(@config.parse(source))
    let captures = []
    @async.with_task_group(group => {
      let receiver = group.spawn(async fn() {
        sink.run_forever(async fn(request, reader, conn) {
          assert_eq(request.path, "/test/v1/metrics")
          let content_type = @http.CaseInsensitiveString("Content-Type")
          assert_eq(request.headers.get(content_type), Some(encoding))
          let decoded = @data.decode(Metrics, reader.read_all().binary(), json~)
          captures.push(decoded.to_json())
          if captures.length() == 1 {
            conn.send_response(400, "Bad Request")
          } else {
            conn.send_response(
              200,
              "OK",
              extra_headers=Map::from_array([(content_type, encoding)]),
            )
            conn.write(if json { b"{}" } else { b"" })
          }
          conn.end_response()
        })
      })
      defer receiver.cancel()
      let collector = group.spawn(async fn() { runtime.run() })
      defer collector.cancel()
      @async.with_timeout(3000, async fn() {
        while !runtime.health().stringify().contains("\"status\":\"ready\"") {
          @async.sleep(5)
        }
      })
      let logs = @data.from_json(Logs, {
        "resourceLogs": [
          {
            "scopeLogs": [
              {
                "logRecords": [
                  { "body": { "stringValue": "private-log-content" } },
                ],
              },
            ],
          },
        ],
      })
      assert_eq(runtime.submit("otlp", logs), 0)
      @async.with_timeout(6000, async fn() {
        while captures.length() < 2 ||
              !(runtime.health() is Object(health) &&
              health.get("selfMetrics") is Some(Object(metrics)) &&
              metrics.get("destination") is Some(Object(destination)) &&
              destination.get("successfulBatches") == Some(Json::string("1"))) {
          @async.sleep(5)
        }
      })
      collector.cancel()
      collector.wait()
    })
    assert_eq(captures.length(), 2)
    let times = []
    for sample in captures {
      let text = sample.stringify()
      assert_true(text.contains("test-collector"))
      assert_false(
        text.contains("private-log-content") || text.contains("127.0.0.1"),
      )
      guard metric_by_name(sample, "output.delivered") is Object(counter) &&
        counter.get("sum") is Some(Object(sum)) &&
        sum.get("dataPoints") is Some(Array([Object(point)])) &&
        point.get("startTimeUnixNano") is Some(String(start)) &&
        point.get("timeUnixNano") is Some(String(time)) else {
        abort("cumulative point")
      }
      assert_eq(sum.get("aggregationTemporality"), Some(Json::number(2)))
      assert_eq(sum.get("isMonotonic"), Some(Json::boolean(true)))
      assert_eq(point.get("asInt"), Some(Json::string("1")))
      assert_true(time > start)
      times.push((start, time))
      guard metric_by_name(sample, "memory.logical_used") is Object(memory) &&
        memory.get("gauge") is Some(Object(gauge)) &&
        gauge.get("dataPoints") is Some(Array([Object(value)])) else {
        abort("memory gauge")
      }
      assert_eq(memory.get("unit"), Some(Json::string("By")))
      assert_false(value.contains("startTimeUnixNano"))
    }
    assert_eq(times[0].0, times[1].0)
    assert_true(times[0].1 < times[1].1)
    guard runtime.health() is Object(health) &&
      health.get("selfMetrics") is Some(Object(metrics)) &&
      metrics.get("destination") is Some(Object(destination)) else {
      abort("self metrics health")
    }
    assert_eq(destination.get("failedBatches"), Some(Json::string("1")))
    assert_eq(destination.get("successfulBatches"), Some(Json::string("1")))
    assert_eq(metrics.get("snapshotFailures"), Some(Json::string("0")))
    assert_eq(health.get("logicalMemoryUsed"), Some(Json::string("0")))
  }
}
