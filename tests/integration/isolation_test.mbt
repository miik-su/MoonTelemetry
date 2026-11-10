///|
async test "stalled destination overflows independently while file delivery continues" {
  let dir = @fs.tmpdir(prefix="moontelemetry-isolation-")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/fast.jsonl"
  let stalled = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer stalled.close()
  let cfg : Json = {
    "receivers": { "otlp": { "port": 24320 } },
    "exporters": {
      "file": { "path": Json::string(path) },
      "otlp/slow": {
        "endpoint": Json::string("http://127.0.0.1:\{stalled.addr.port()}"),
        "timeout_ms": 10000,
        "retries": 1,
      },
    },
    "service": {
      "queue_capacity": 1,
      "shutdown_timeout_ms": 100,
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": [],
          "exporters": ["file", "otlp/slow"],
        },
      },
    },
  }
  let runtime = @service.Runtime::new(@config.parse(cfg.stringify()))
  @async.with_task_group(async fn(group) {
    let target = group.spawn(async fn() {
      stalled.run_forever(async fn(_, _, _) { @async.sleep(30000) })
    })
    let collector = group.spawn(async fn() { runtime.run() })
    @async.with_timeout(3000, async fn() {
      for ;; {
        let ready = try {
          let client = @http.Client("http://127.0.0.1:24320")
          defer client.close()
          let response = client.get("/health")
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
    let payload = @fs.read_file("tests/fixtures/logs.json").binary()
    for i in 0..<4 {
      assert_eq(
        post("http://127.0.0.1:24320", "/v1/logs", payload, "application/json"),
        200,
      )
      @async.with_timeout(3000, async fn() {
        for ;; {
          if runtime
            .health()
            .stringify()
            .contains("\"successfulBatches\":\"\{i + 1}\"") {
            break
          }
          @async.sleep(10)
        }
      })
    }
    // Check while the slow destination is still stuck in its first request.
    let lines = @fs.read_file(path)
      .text()
      .split("\n")
      .filter(s => !s.is_empty())
      .count()
    assert_eq(lines, 4)
    assert_true(
      runtime.health().stringify().contains("\"overflowDropped\":\"3\""),
    )
    collector.cancel()
    collector.wait()
    target.cancel()
  })
}
