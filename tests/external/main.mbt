///|
async fn main {
  let endpoint = @env.get_env_var("MOONTELEMETRY_EXTERNAL_OTLP_ENDPOINT").unwrap_or(
    "http://127.0.0.1:14318",
  )
  let cfg : Json = {
    "receivers": { "otlp": { "port": 24318, "max_body_bytes": 65536 } },
    "exporters": {
      "otlp/json": {
        "endpoint": Json::string(endpoint),
        "json": true,
        "retries": 0,
      },
      "otlp/protobuf": {
        "endpoint": Json::string(endpoint),
        "json": false,
        "retries": 0,
      },
    },
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": [],
          "exporters": ["otlp/json", "otlp/protobuf"],
        },
        "metrics": {
          "receivers": ["otlp"],
          "processors": [],
          "exporters": ["otlp/json", "otlp/protobuf"],
        },
        "traces": {
          "receivers": ["otlp"],
          "processors": [],
          "exporters": ["otlp/json", "otlp/protobuf"],
        },
      },
    },
  }
  let runtime = @service.Runtime::new(@config.parse(cfg.stringify()))
  let directory = @fs.tmpdir(prefix="moontelemetry-external-")
  defer @fs.rmdir(directory, recursive=true)
  let path = directory + "/returned.jsonl"
  let returned_cfg : Json = {
    "receivers": { "otlp": { "port": 34318, "max_body_bytes": 65536 } },
    "exporters": { "file": { "path": Json::string(path) } },
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": [],
          "exporters": ["file"],
        },
        "metrics": {
          "receivers": ["otlp"],
          "processors": [],
          "exporters": ["file"],
        },
        "traces": {
          "receivers": ["otlp"],
          "processors": [],
          "exporters": ["file"],
        },
      },
    },
  }
  let returned = @service.Runtime::new(@config.parse(returned_cfg.stringify()))
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() { returned.run(stop_after_ms=2500) })
    group.spawn_bg(async fn() { runtime.run(stop_after_ms=1500) })
    @async.sleep(50)
    for name in ["logs", "metrics", "traces"] {
      let signal = @data.signal_from_name(name).unwrap()
      let input = @data.decode(
        signal,
        @fs.read_file("tests/fixtures/" + name + ".json").binary(),
        json=true,
      )
      for json in [true, false] {
        let client = @http.Client("http://127.0.0.1:24318")
        defer client.close()
        let response = client.post(
          signal.path(),
          input.encode(json~),
          extra_headers=Map::from_array([
            (
              @http.CaseInsensitiveString("Content-Type"),
              if json {
                "application/json"
              } else {
                "application/x-protobuf"
              },
            ),
          ]),
        )
        assert_eq(response.code, 200)
        let _ = client.read_all()
      }
    }
  })
  let returned_health = returned.health()
  guard returned_health is Object(returned_root) &&
    returned_root.get("receivers") is Some(Object(receivers)) &&
    receivers.get("otlp") is Some(Object(receiver)) else {
    abort("missing return receiver status")
  }
  assert_eq(receiver.get("successfulRequests"), Some(Json::string("12")))
  assert_eq(receiver.get("rejectedRequests"), Some(Json::string("0")))
  assert_eq(returned_root.get("logicalMemoryUsed"), Some(Json::string("0")))
  let output = @fs.read_file(path).text()
  let lines = output.split("\n").filter(line => !line.is_empty()).collect()
  assert_eq(lines.length(), 12)
  let totals : Map[String, Int32] = Map([])
  let expected : Map[String, Json] = Map([])
  for name in ["logs", "metrics", "traces"] {
    expected[name] = @data.decode(
      @data.signal_from_name(name).unwrap(),
      @fs.read_file("tests/fixtures/" + name + ".json").binary(),
      json=true,
    ).to_json()
  }
  for line in lines {
    let parsed = @json.parse(line)
    for name in ["logs", "metrics", "traces"] {
      let signal = @data.signal_from_name(name).unwrap()
      let envelope = @data.from_json(signal, parsed)
      let count = envelope.count()
      if count > 0 {
        assert_eq(envelope.to_json(), expected[name])
      }
      totals[name] = totals.get(name).unwrap_or(0) + count
    }
  }
  assert_eq(totals.get("logs"), Some(4))
  assert_eq(totals.get("metrics"), Some(8))
  assert_eq(totals.get("traces"), Some(4))
  assert_true(output.contains("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
  assert_true(output.contains("cccccccccccccccccccccccccccccccc"))
  let health = runtime.health()
  guard health is Object(root) &&
    root.get("pipelines") is Some(Array(pipelines)) else {
    abort("missing pipeline status")
  }
  for p in pipelines {
    guard p is Object(m) && m.get("outputs") is Some(Array(outputs)) else {
      abort("missing exporter status")
    }
    for output in outputs {
      guard output is Object(q) && q.get("destination") is Some(Object(d)) else {
        abort("missing destination status")
      }
      assert_eq(d.get("failedBatches"), Some(Json::string("0")))
      // Each shared destination receives two requests for each of three signals.
      assert_eq(d.get("successfulBatches"), Some(Json::string("6")))
    }
  }
  println(
    "External Collector accepted both encodings and returned all three signals to MoonTelemetry JSONL",
  )
  println(health.stringify())
  println(returned_health.stringify())
  if @env.get_env_var("MOONTELEMETRY_EXTERNAL_RESULT_PATH") is Some(path) {
    let result : Json = {
      "schemaVersion": 1,
      "kind": "fixture_roundtrip",
      "recordedAtUnixMs": Json::string(@async.now().to_string()),
      "source": health,
      "returned": returned_health,
      "assertions": {
        "ingressRequests": 6,
        "returnedRequests": 12,
        "logs": 4,
        "metricPoints": 8,
        "spans": 4,
        "normalizedFixtureEquality": true,
      },
    }
    @fs.write_file(path, result.stringify() + "\n")
  }
}
