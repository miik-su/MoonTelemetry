///|
async fn post(
  url : String,
  path : String,
  body : Bytes,
  content_type : String,
) -> Int32 {
  let client = @http.Client(url)
  defer client.close()
  let headers = Map::from_array([
    (@http.CaseInsensitiveString("Content-Type"), content_type),
  ])
  let r = client.post(path, body, extra_headers=headers)
  let _ = client.read_all()
  r.code
}

///|
async test "SDK golden signals traverse HTTP processors file and OTLP fanout" {
  let dir = @fs.tmpdir(prefix="moontelemetry-e2e-")
  defer @fs.rmdir(dir, recursive=true)
  let file = dir + "/signals.jsonl"
  let target = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer target.close()
  let endpoint = "http://127.0.0.1:\{target.addr.port()}"
  let received : Map[String, Int32] = Map([])
  let expected : Map[String, Int32] = Map([])
  let cfg : Json = {
    "receivers": { "otlp": { "port": 24319 } },
    "processors": {
      "resource": {
        "actions": [
          { "key": "collector", "value": { "stringValue": "MoonTelemetry" } },
        ],
      },
      "batch": { "size": 512, "timeout_ms": 1000, "max_bytes": 8192 },
    },
    "exporters": {
      "file": { "path": Json::string(file) },
      "otlp": { "endpoint": Json::string(endpoint), "json": true },
    },
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": ["resource", "batch"],
          "exporters": ["file", "otlp"],
        },
        "metrics": {
          "receivers": ["otlp"],
          "processors": ["resource", "batch"],
          "exporters": ["file", "otlp"],
        },
        "traces": {
          "receivers": ["otlp"],
          "processors": ["resource", "batch"],
          "exporters": ["file", "otlp"],
        },
      },
    },
  }
  let runtime = @service.Runtime::new(@config.parse(cfg.stringify()))
  @async.with_task_group(async fn(group) {
    let downstream = group.spawn(async fn() {
      target.run_forever(async fn(req, reader, conn) {
        let signal = @otlp.route(req.path).unwrap()
        let bytes = @otlp.read_body(reader, 1048576)
        let e = @data.decode(signal, bytes, json=true)
        assert_true(e.to_json().stringify().contains("MoonTelemetry"))
        received[req.path] = received.get(req.path).unwrap_or(0) + e.count()
        conn.send_response(
          200,
          "OK",
          extra_headers=Map::from_array([
            (@http.CaseInsensitiveString("Content-Type"), "application/json"),
          ]),
        )
        conn.write(b"{}")
        conn.end_response()
      })
    })
    let collector = group.spawn(async fn() { runtime.run(stop_after_ms=400) })
    @async.sleep(60)
    for name in ["logs", "metrics", "traces"] {
      let signal = @data.signal_from_name(name).unwrap()
      let e = @data.decode(
        signal,
        @fs.read_file("tests/fixtures/" + name + ".json").binary(),
        json=true,
      )
      expected[signal.path()] = e.count() * 2
      for json in [true, false] {
        assert_eq(
          post(
            "http://127.0.0.1:24319",
            signal.path(),
            e.encode(json~),
            if json {
              "application/json"
            } else {
              "application/x-protobuf"
            },
          ),
          200,
        )
      }
    }
    collector.wait()
    downstream.cancel()
  })
  for path, count in expected {
    assert_eq(received.get(path), Some(count))
  }
  let text = @fs.read_file(file).text()
  assert_true(
    text.contains("resourceLogs") &&
    text.contains("resourceMetrics") &&
    text.contains("resourceSpans"),
  )
}

///|
async test "503 retries but successful partial export does not retry" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let calls : Array[Int32] = [0]
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      server.run_forever(async fn(_, reader, conn) {
        let _ = reader.read_all()
        calls[0] += 1
        conn.send_response(
          if calls[0] == 1 {
            503
          } else {
            200
          },
          "test",
          extra_headers=Map::from_array([
            (@http.CaseInsensitiveString("Content-Type"), "application/json"),
          ]),
        )
        if calls[0] > 1 {
          conn.write(@data.response(Logs, rejected=1, json=true))
        }
        conn.end_response()
      })
    })
    let d = @exporter.Destination::new(
      Otlp(
        endpoint="http://127.0.0.1:\{server.addr.port()}",
        json=true,
        timeout_ms=1000,
        retries=3,
      ),
    )
    let e = @data.decode(
      Logs,
      @fs.read_file("tests/fixtures/logs.json").binary(),
      json=true,
    )
    assert_eq(d.send(e), 1)
    assert_eq(calls[0], 2)
    task.cancel()
  })
}

///|
async test "gzip expansion is bounded and malformed streams fail" {
  let source = @io.MemoryReader(async fn(w) {
    let gzip = @gzip.Encoder(w)
    gzip.write("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    gzip.end()
  })
  defer source.close()
  let compressed = @otlp.read_body(source, 1024)
  assert_eq(
    @otlp.decompress(compressed, 64),
    b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  assert_true(
    try {
      let _ = @otlp.decompress(compressed, 8)
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      let _ = @otlp.decompress(b"not gzip", 64)
      false
    } catch {
      _ => true
    },
  )
}
