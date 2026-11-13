///|
priv struct Fixture {
  name : String
  signal : @data.Signal
  input : @data.Envelope
  canonical : Json
}

///|
async fn fixtures() -> Array[Fixture] {
  let result = []
  for suite in ["sdk", "expanded"] {
    for name in ["logs", "metrics", "traces"] {
      let signal = @data.signal_from_name(name).unwrap()
      let path = "tests/fixtures/" +
        (if suite == "sdk" { "" } else { "expanded/" }) +
        name +
        ".json"
      let input = @data.decode(signal, @fs.read_file(path).binary(), json=true)
      result.push(Fixture::{
        name: suite + "/" + name,
        signal,
        input,
        canonical: input.to_json(),
      })
    }
  }
  result
}

///|
fn integer(value : Json) -> Int64 {
  guard value is String(s) else { abort("expected decimal counter") }
  let mut n = 0L
  for c in s {
    guard c >= '0' && c <= '9' else { abort("invalid counter") }
    n = n * 10L + (c.to_int() - 48).to_int64()
  }
  n
}

///|
fn successes(health : Json, component : String) -> Int64 {
  if health is Object(root) && root.get("pipelines") is Some(Array(pipelines)) {
    for pipeline in pipelines {
      if pipeline is Object(p) && p.get("outputs") is Some(Array(outputs)) {
        for output in outputs {
          if output is Object(q) &&
            q.get("destination") is Some(Object(d)) &&
            d.get("componentId") == Some(Json::string(component)) {
            guard integer(d["failedBatches"]) == 0L else {
              abort("external destination failed: " + component)
            }
            return integer(d["successfulBatches"])
          }
        }
      }
    }
  }
  0L
}

///|
async fn wait_ready(url : String) -> Unit {
  @async.with_timeout(5000, async fn() {
    for ;; {
      let ready = try {
        let client = @http.Client(url)
        defer client.close()
        let response = client.get("/health/ready")
        let _ = client.read_all()
        response.code == 200
      } catch {
        _ => false
      }
      if ready {
        break
      }
      @async.sleep(10)
    }
  })
}

///|
async fn post(
  url : String,
  signal : @data.Signal,
  body : Bytes,
  json : Bool,
) -> Int32 {
  let client = @http.Client(url)
  defer client.close()
  let response = client.post(
    signal.path(),
    body,
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
  let _ = client.read_all()
  response.code
}

///|
fn wrap(tag : UInt32, body : Bytes) -> Bytes raise {
  let output = @buffer.Buffer()
  @protobuf.write_uint32(output, tag)
  @protobuf.write_bytes(output, body)
  output.to_bytes()
}

///|
async fn differential(reference : String) -> Json {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let cfg = @config.parse(
    "{\"receivers\":{\"otlp\":{\"max_body_bytes\":4096}},\"exporters\":{\"debug\":{}},\"service\":{\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"debug\"]}}}}",
  )
  let raw_point = b"\x21\x01\x00\x00\x00\x00\x00\x00\x00\x31\x01\x00\x00\x00\x00\x00\x00\x00"
  let histogram = @buffer.Buffer()
  histogram.write_bytes(wrap(10U, raw_point))
  histogram.write_bytes(b"\x10\x02")
  let unpacked = wrap(
    10U,
    wrap(18U, wrap(18U, wrap(74U, histogram.to_bytes()))),
  )
  let cases : Array[(String, @data.Signal, Bool, Bytes, Int32, Array[Int32])] = [
    (
      "unknown-json-field",
      Logs,
      true,
      b"{\"resourceLogs\":[],\"futureField\":{\"nested\":true}}",
      200,
      [200],
    ),
    (
      "future-enum",
      Logs,
      true,
      b"{\"resourceLogs\":[{\"scopeLogs\":[{\"logRecords\":[{\"severityNumber\":99}]}]}]}",
      200,
      [200],
    ),
    (
      "numeric-int64-max",
      Logs,
      true,
      b"{\"resourceLogs\":[{\"scopeLogs\":[{\"logRecords\":[{\"body\":{\"intValue\":9223372036854775807}}]}]}]}",
      200,
      [200],
    ),
    ("unpacked-histogram", Metrics, false, unpacked, 200, [200]),
    ("truncated-protobuf", Logs, false, b"\x0a\x05\x12", 400, [400]),
    ("malformed-json", Logs, true, b"{", 400, [400]),
    (
      "quoted-finite-double",
      Logs,
      true,
      b"{\"resourceLogs\":[{\"scopeLogs\":[{\"logRecords\":[{\"body\":{\"doubleValue\":\"1.5\"}}]}]}]}",
      200,
      [200],
    ),
    (
      "special-double-nan",
      Logs,
      true,
      b"{\"resourceLogs\":[{\"scopeLogs\":[{\"logRecords\":[{\"body\":{\"doubleValue\":\"NaN\"}}]}]}]}",
      200,
      [200],
    ),
    (
      "numeric-double-overflow",
      Logs,
      true,
      b"{\"resourceLogs\":[{\"scopeLogs\":[{\"logRecords\":[{\"body\":{\"doubleValue\":1e9999}}]}]}]}",
      400,
      [400],
    ),
    (
      "quoted-double-overflow",
      Logs,
      true,
      b"{\"resourceLogs\":[{\"scopeLogs\":[{\"logRecords\":[{\"body\":{\"doubleValue\":\"1e9999\"}}]}]}]}",
      400,
      [400],
    ),
    (
      "quoted-packed-double",
      Metrics,
      true,
      b"{\"resourceMetrics\":[{\"scopeMetrics\":[{\"metrics\":[{\"name\":\"quoted-bound\",\"histogram\":{\"dataPoints\":[{\"count\":\"2\",\"bucketCounts\":[\"1\",\"1\"],\"explicitBounds\":[\"1.5\"]}]}}]}]}]}",
      200,
      [200],
    ),
    (
      "body-over-limit",
      Logs,
      true,
      Bytes::from_array(Array::make(4097, b' ')),
      413,
      [400, 413],
    ),
    (
      "all-zero-required-trace-id",
      Traces,
      true,
      b"{\"resourceSpans\":[{\"scopeSpans\":[{\"spans\":[{\"traceId\":\"00000000000000000000000000000000\",\"spanId\":\"1111111111111111\"}]}]}]}",
      400,
      [200, 400],
    ),
    (
      "duplicate-json-protocol-key",
      Logs,
      true,
      b"{\"resourceLogs\":[],\"resourceLogs\":[]}",
      400,
      [200, 400],
    ),
  ]
  let results = []
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @otlp.serve(server, cfg.receivers["otlp"], _ => 0)
    })
    for (name, signal, json, body, expected, allowed) in cases {
      let moon = post(
        "http://127.0.0.1:\{server.addr.port()}",
        signal,
        body,
        json,
      )
      let go = post(reference, signal, body, json)
      println("Differential \{name}: MoonTelemetry=\{moon}, Go=\{go}")
      assert_eq(moon, expected)
      assert_true(allowed.contains(go), msg="unexpected Go response: " + name)
      results.push(
        (
          {
            "case": Json::string(name),
            "moonHttpStatus": Json::number(moon.to_double()),
            "goHttpStatus": Json::number(go.to_double()),
            "sameAcceptance": Json::boolean((moon == 200) == (go == 200)),
            "profile": Json::string(
              if name == "body-over-limit" {
                "both reject configured body limit; reference may use 400 rather than 413"
              } else if allowed.length() > 1 {
                "MoonTelemetry explicitly rejects semantically invalid IDs/duplicate keys; reference may be more permissive"
              } else {
                "required acceptance/rejection agreement"
              },
            ),
          } : Json),
      )
    }
    task.cancel()
  })
  Json::array(results)
}
