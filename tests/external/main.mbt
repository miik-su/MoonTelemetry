///|
fn config_for(
  port : Int32,
  exporters : Json,
  destinations : Array[String],
) -> Json {
  let pipelines : Map[String, Json] = Map([])
  for name in ["logs", "metrics", "traces"] {
    pipelines[name] = {
      "receivers": ["otlp"],
      "processors": [],
      "exporters": Json::array(destinations.map(Json::string)),
    }
  }
  {
    "receivers": {
      "otlp": {
        "port": Json::number(port.to_double()),
        "max_body_bytes": 65536,
      },
    },
    "exporters": exporters,
    "service": { "pipelines": Json::object(pipelines) },
  }
}

///|
fn signal_name(signal : @data.Signal) -> String {
  match signal {
    Logs => "logs"
    Metrics => "metrics"
    Traces => "traces"
  }
}

///|
async fn main {
  let endpoint = @env.get_env_var("MOONTELEMETRY_EXTERNAL_OTLP_ENDPOINT").unwrap_or(
    "http://127.0.0.1:14318",
  )
  let inputs = fixtures()
  let directory = @fs.tmpdir(prefix="moontelemetry-external-")
  defer @fs.rmdir(directory, recursive=true)
  let path = directory + "/returned.jsonl"
  let runtime = @service.Runtime::new(
    @config.parse(
      config_for(
        24318,
        {
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
        ["otlp/json", "otlp/protobuf"],
      ).stringify(),
    ),
  )
  let returned = @service.Runtime::new(
    @config.parse(
      config_for(34318, { "file": { "path": Json::string(path) } }, ["file"]).stringify(),
    ),
  )
  let expected_ingress = inputs.length() * 2
  let expected_returned = inputs.length() * 4
  @async.with_task_group(async fn(group) {
    let sink = group.spawn(async fn() { returned.run() })
    let source = group.spawn(async fn() { runtime.run() })
    wait_ready("http://127.0.0.1:34318")
    wait_ready("http://127.0.0.1:24318")
    for fixture in inputs {
      for json in [true, false] {
        println("Roundtrip fixture \{fixture.name}, JSON=\{json}")
        let encoded = fixture.input.encode(json~)
        let _ = @data.decode(fixture.signal, encoded, json~) catch {
          @data.Invalid(message) => {
            println(message)
            abort(message)
          }
          error => raise error
        }
        assert_eq(
          post("http://127.0.0.1:24318", fixture.signal, encoded, json),
          200,
        )
      }
    }
    @async.with_timeout(15000, async fn() {
      while successes(runtime.health(), "otlp/json") !=
            expected_ingress.to_int64() ||
            successes(runtime.health(), "otlp/protobuf") !=
            expected_ingress.to_int64() ||
            successes(returned.health(), "file") != expected_returned.to_int64() {
        @async.sleep(10)
      }
    })
    source.cancel()
    source.wait()
    sink.cancel()
    sink.wait()
  })
  let health = runtime.health()
  let returned_health = returned.health()
  for snapshot in [health, returned_health] {
    guard snapshot is Object(root) else { abort("missing health") }
    assert_eq(root.get("logicalMemoryUsed"), Some(Json::string("0")))
    assert_eq(root.get("requestMemoryUsed"), Some(Json::string("0")))
  }
  let lines = @fs.read_file(path)
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .collect()
  assert_eq(lines.length(), expected_returned)
  let seen : Map[String, Int32] = Map([])
  let totals : Map[String, Int32] = Map([])
  for line in lines {
    let parsed = @json.parse(line)
    let mut matched = false
    for fixture in inputs {
      let envelope = @data.from_json(fixture.signal, parsed)
      if envelope.count() > 0 && envelope.to_json() == fixture.canonical {
        seen[fixture.name] = seen.get(fixture.name).unwrap_or(0) + 1
        let name = signal_name(fixture.signal)
        totals[name] = totals.get(name).unwrap_or(0) + envelope.count()
        matched = true
        break
      }
    }
    if !matched {
      println(parsed.stringify())
      abort("returned batch differs from every expected fixture")
    }
  }
  for fixture in inputs {
    assert_eq(seen.get(fixture.name), Some(4), msg=fixture.name)
  }
  let comparison = differential(
    @env.get_env_var("MOONTELEMETRY_REFERENCE_OTLP_ENDPOINT").unwrap_or(
      "http://127.0.0.1:14319",
    ),
  )
  let result : Json = {
    "schemaVersion": 2,
    "kind": "fixture_roundtrip",
    "recordedAtUnixMs": Json::string(@async.now().to_string()),
    "sourceRevision": Json::string(
      @env.get_env_var("MOONTELEMETRY_EXTERNAL_REVISION").unwrap_or(
        @env.get_env_var("GITHUB_SHA").unwrap_or("working-tree"),
      ),
    ),
    "source": health,
    "returned": returned_health,
    "counterScope": "receiver health counts include readiness probes; assertions count telemetry requests only",
    "assertions": {
      "ingressRequests": Json::number(expected_ingress.to_double()),
      "returnedRequests": Json::number(expected_returned.to_double()),
      "logs": Json::number(totals.get("logs").unwrap_or(0).to_double()),
      "metricPoints": Json::number(
        totals.get("metrics").unwrap_or(0).to_double(),
      ),
      "spans": Json::number(totals.get("traces").unwrap_or(0).to_double()),
      "normalizedFixtureEquality": true,
    },
    "matrix": Json::array(
      inputs.map(f => {
        (
          {
            "fixture": Json::string(f.name),
            "signal": Json::string(signal_name(f.signal)),
            "recordsPerInput": Json::number(f.input.count().to_double()),
            "ingressEncodings": ["json", "protobuf"],
            "egressEncodings": ["json", "protobuf"],
            "copiesCompared": 4,
            "normalizedEquality": true,
          } : Json)
      }),
    ),
    "differential": comparison,
  }
  println("Expanded official Go Collector matrix passed")
  println(result.stringify())
  if @env.get_env_var("MOONTELEMETRY_EXTERNAL_RESULT_PATH") is Some(path) {
    @fs.write_file(path, result.stringify() + "\n")
  }
}
