///|
async fn main {
  let endpoint = @env.get_env_var("MOONTELEMETRY_EXTERNAL_OTLP_ENDPOINT").unwrap_or(
    "http://127.0.0.1:14318",
  )
  let cfg : Json = {
    "receivers": { "otlp": { "port": 24318 } },
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
  @async.with_task_group(async fn(group) {
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
  println("External Collector accepted three signals via both HTTP encodings")
  println(health.stringify())
}
