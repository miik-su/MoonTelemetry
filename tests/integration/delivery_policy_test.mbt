///|
async test "reject_on_overload refuses new admission when attached output is already full" {
  let target = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer target.close()
  let directory = @fs.tmpdir(prefix="moontelemetry-policy-")
  defer @fs.rmdir(directory, recursive=true)
  let file = directory + "/records.jsonl"
  let cfg : Json = {
    "receivers": { "otlp": { "port": 24331 } },
    "exporters": {
      "file": { "path": Json::string(file) },
      "otlp/slow": {
        "endpoint": Json::string("http://127.0.0.1:\{target.addr.port()}"),
        "attempt_timeout_ms": 10000,
        "retries": 0,
      },
    },
    "service": {
      "delivery_policy": "reject_on_overload",
      "queue_capacity": 1,
      "shutdown_timeout_ms": 50,
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
  let seen = [false]
  @async.with_task_group(async fn(group) {
    let slow = group.spawn(async fn() {
      target.run_forever(async fn(_, reader, _) {
        let _ = reader.read_all()
        seen[0] = true
        @async.sleep(30000)
      })
    })
    let collector = group.spawn(async fn() { runtime.run() })
    @async.with_timeout(3000, async fn() {
      while !runtime.health().stringify().contains("\"status\":\"ready\"") {
        @async.sleep(5)
      }
    })
    @async.sleep(20)
    let body = @fs.read_file("tests/fixtures/logs.json").binary()
    assert_eq(
      post("http://127.0.0.1:24331", "/v1/logs", body, "application/json"),
      200,
    )
    @async.with_timeout(3000, async fn() {
      while !seen[0] ||
            !runtime
            .health()
            .stringify()
            .contains("\"successfulBatches\":\"1\"") {
        @async.sleep(5)
      }
    })
    assert_eq(
      post("http://127.0.0.1:24331", "/v1/logs", body, "application/json"),
      503,
    )
    assert_true(
      runtime.health().stringify().contains("\"overflowDropped\":\"0\""),
    )
    assert_eq(
      @fs.read_file(file)
      .text()
      .split("\n")
      .filter(line => !line.is_empty())
      .count(),
      1,
    )
    collector.cancel()
    collector.wait()
    slow.cancel()
  })
}

///|
async test "strict security example masks free-text bodies and enforces attribute allowlist" {
  let source = @fs.read_file("examples/strict-security.json").text()
  let cfg = @config.parse(source, env=_ => Some("synthetic-token"))
  let _ = @service.Runtime::new(cfg)
  let mut input = @data.from_json(Logs, {
    "resourceLogs": [
      {
        "scopeLogs": [
          {
            "logRecords": [
              {
                "body": { "stringValue": "User login failed. token=secret123" },
                "attributes": [
                  {
                    "key": "service.name",
                    "value": { "stringValue": "retained-service" },
                  },
                  {
                    "key": "email",
                    "value": { "stringValue": "private@example.invalid" },
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
  })
  for spec in cfg.pipelines[0].processors {
    if spec is Transform(t) {
      input = t.process(input)
    }
  }
  let output = input.to_json().stringify()
  assert_false(output.contains("secret123"))
  assert_false(output.contains("private@example.invalid"))
  assert_true(output.contains("[REDACTED]"))
  assert_true(output.contains("retained-service"))
}
