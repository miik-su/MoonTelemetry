///|
async test "real HTTP logs reach JSONL after timed batch drain" {
  let directory = @fs.tmpdir(prefix="moontelemetry-test-")
  defer @fs.rmdir(directory, recursive=true)
  let path = directory + "/logs.jsonl"
  let config : Json = {
    "receivers": { "otlp": { "port": 24318 } },
    "processors": {
      "batch": { "size": 512, "timeout_ms": 5000, "max_bytes": 8192 },
    },
    "exporters": { "file": { "path": Json::string(path) } },
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": ["batch"],
          "exporters": ["file"],
        },
      },
    },
  }
  let runtime = @service.Runtime::new(@config.parse(config.stringify()))
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() { runtime.run(stop_after_ms=300) })
    @async.sleep(50)
    let client = @http.Client("http://127.0.0.1:24318")
    defer client.close()
    let headers = Map::from_array([
      (@http.CaseInsensitiveString("Content-Type"), "application/json"),
    ])
    let response = client.post(
      "/v1/logs",
      (
        {
          "resourceLogs": [
            {
              "scopeLogs": [
                { "logRecords": [{ "body": { "stringValue": "drain-me" } }] },
              ],
            },
          ],
        } : Json),
      extra_headers=headers,
    )
    assert_eq(response.code, 200)
    let _ = client.read_all()
  })
  let text = @fs.read_file(path).text()
  assert_true(text.contains("drain-me"))
  assert_true(
    runtime.health().stringify().contains("\"logicalMemoryUsed\":\"0\""),
  )
  assert_true(runtime.health().stringify().contains("\"delivered\":\"1\""))
}
