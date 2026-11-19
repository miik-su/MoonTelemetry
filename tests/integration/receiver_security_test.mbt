///|
async test "source rejection preserves recognized OTLP response encoding before parsing body" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let cfg = @config.parse(
    "{\"receivers\":{\"otlp\":{\"allowed_ips\":[\"127.0.0.2\"]}},\"exporters\":{\"debug\":{}},\"service\":{\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"debug\"]}}}}",
  )
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @otlp.serve(server, cfg.receivers["otlp"], _ => {
        abort("source rejection must precede decode and admission")
      })
    })
    for content_type in ["application/json", "application/x-protobuf"] {
      let client = @http.Client("http://127.0.0.1:\{server.addr.port()}")
      defer client.close()
      let response = client.post(
        "/v1/logs",
        b"invalid-body",
        extra_headers=Map::from_array([
          (@http.CaseInsensitiveString("Content-Type"), content_type),
        ]),
      )
      assert_eq(response.code, 403)
      assert_eq(
        response.headers.get(@http.CaseInsensitiveString("Content-Type")),
        Some(content_type),
      )
      let _ = client.read_all()
    }
    let health_client = @http.Client("http://127.0.0.1:\{server.addr.port()}")
    defer health_client.close()
    let health_response = health_client.get(
      "/health",
      extra_headers=Map::from_array([
        (@http.CaseInsensitiveString("Content-Type"), "application/x-protobuf"),
      ]),
    )
    assert_eq(health_response.code, 403)
    assert_eq(
      health_response.headers.get(@http.CaseInsensitiveString("Content-Type")),
      Some("application/json"),
    )
    let _ = health_client.read_all()
    task.cancel()
  })
}

///|
async test "health and telemetry bearer policies and method encoding" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let config = @config.parse(
    "{\"receivers\":{\"otlp\":{\"health_token\":\"health-key\",\"auth_token\":\"ingest-key\",\"allowed_ips\":[\"127.0.0.1\"]}},\"exporters\":{\"debug\":{}},\"service\":{\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"debug\"]}}}}",
  )
  let url = "http://127.0.0.1:\{server.addr.port()}"
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @otlp.serve(server, config.receivers["otlp"], _ => 0)
    })
    for token in ["", "health-key"] {
      let client = @http.Client(url)
      defer client.close()
      let response = client.get(
        "/health",
        extra_headers=Map::from_array([
          (@http.CaseInsensitiveString("Authorization"), "Bearer " + token),
        ]),
      )
      assert_eq(response.code, if token.is_empty() { 401 } else { 200 })
      let _ = client.read_all()
    }
    assert_eq(post(url, "/v1/logs", b"{}", "application/json"), 401)
    let client = @http.Client(url)
    defer client.close()
    let headers = Map::from_array([
      (@http.CaseInsensitiveString("Content-Type"), "application/x-protobuf"),
    ])
    let response = client.get("/v1/logs", extra_headers=headers)
    assert_eq(response.code, 405)
    assert_eq(
      response.headers.get(@http.CaseInsensitiveString("Content-Type")),
      Some("application/x-protobuf"),
    )
    let _ = client.read_all()
    task.cancel()
  })
}

///|
async test "slow request body expires and releases its budgets" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let config = @config.parse(
    "{\"receivers\":{\"otlp\":{\"max_body_bytes\":128,\"body_idle_timeout_ms\":30}},\"exporters\":{\"debug\":{}},\"service\":{\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"debug\"]}}}}",
  )
  let budget = @component.MemoryBudget::new(1000L)
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @otlp.serve(server, config.receivers["otlp"], _ => 0, budget~)
    })
    let conn = @socket.Tcp::connect(server.addr)
    defer conn.close()
    conn.write(
      "POST /v1/logs HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: 50\r\n\r\n{",
    )
    @async.sleep(100)
    assert_eq(budget.used(), 0L)
    task.cancel()
  })
}
